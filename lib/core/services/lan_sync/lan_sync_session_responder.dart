// 响应方的流程：hello（或拒绝）→ 刷新 → 按发起方的请求逐条应答，直到
// `sync.finish` 回 `sync.done`。
part of 'lan_sync_session.dart';

extension _Responder on LanSyncSession {
  Future<void> _runResponder() async {
    final theirs = LanSyncSessionHello.parse(
      await _expect(const {LanSyncSessionMessages.hello}),
    );
    _automatic = theirs.automatic;
    final mine = LanSyncSessionHello(
      formatVersion: kSyncFormatVersion,
      appVersion: _context.appVersion,
      entities: lanSyncEntityNames(),
      syncSettings: _syncSettings,
      restoredPending: peer.restoredPending,
    );
    // 版本先于忙碌：版本不同时对方需要升级，这比“稍后再试”更有用。
    final reject = !mine.compatibleWith(theirs)
        ? LanSyncRejectReason.version
        : _busy || _context.isEditing()
        ? LanSyncRejectReason.busy
        : theirs.automatic && !_acceptAutomatic
        ? LanSyncRejectReason.declined
        : null;
    if (reject != null) {
      await _channel.send(
        LanSyncMessage(LanSyncSessionMessages.reject, {'reason': reject.name}),
      );
      throw _HelloRejected(reject.failure);
    }
    await _write(() => _channel.send(mine.toMessage()));
    _helloDone = true;
    _settingsIncluded = _syncSettings && theirs.syncSettings;

    _setStage(LanSyncStage.comparing);
    final snapshot = await _keepAlive(() async {
      await _context.flushAll();
      return _context.state.refreshCheckpoint(
        includeSettings: _settingsIncluded,
      );
    });
    _checkpoint();
    await _serve(snapshot);
  }

  /// 应答循环。顺序由发起方驱动；只检查两条：`sync.apply` 只能一次，
  /// `sync.finish` 必须在它之后。
  Future<void> _serve(SyncLocalSnapshot snapshot) async {
    final writes = <SyncWrite>[];
    var applied = false;
    while (true) {
      final message = await _expect(const {
        LanSyncSessionMessages.manifestGet,
        LanSyncSessionMessages.historyGet,
        LanSyncSessionMessages.recordsGet,
        LanSyncSessionMessages.plan,
        LanSyncSessionMessages.mediaHave,
        LanSyncSessionMessages.mediaPut,
        LanSyncSessionMessages.mediaGet,
        LanSyncSessionMessages.applyPart,
        LanSyncSessionMessages.apply,
        LanSyncSessionMessages.finish,
      });
      switch (message.type) {
        case LanSyncSessionMessages.manifestGet:
          await _sendManifest(snapshot);
        case LanSyncSessionMessages.historyGet:
          await _serveHistory(snapshot, message);
        case LanSyncSessionMessages.recordsGet:
          await _serveRecords(message);
        case LanSyncSessionMessages.plan:
          _notePlan(message);
        case LanSyncSessionMessages.mediaHave:
          await _serveMediaHave(message);
        case LanSyncSessionMessages.mediaPut:
          _setStage(LanSyncStage.transferring);
          await _receiveFile(message);
        case LanSyncSessionMessages.mediaGet:
          await _serveMediaGet(message);
        case LanSyncSessionMessages.applyPart:
          final raw = message.fields['writes'];
          if (applied || raw is! List) {
            throw const FormatException('unexpected sync.apply.part');
          }
          writes.addAll(raw.map(lanSyncWriteFromJson));
        case LanSyncSessionMessages.apply:
          if (applied) throw const FormatException('sync.apply twice');
          applied = true;
          await _serveApply(writes, message);
          writes.clear();
        case LanSyncSessionMessages.finish:
          if (!applied) throw const FormatException('finish before apply');
          await _serveFinish(message);
          return;
      }
    }
  }

  Future<void> _sendManifest(SyncLocalSnapshot snapshot) async {
    final bytes = lanSyncEncodeManifest(
      snapshot.manifest,
      snapshot.tombstoneKeys,
      snapshot.renames,
    );
    if (bytes.length > kLanSyncManifestMaxBytes) {
      throw StateError('manifest too large: ${bytes.length} bytes');
    }
    final id = _nextBlobId++;
    await _send(LanSyncSessionMessages.manifest, {
      'blob': id,
      'size': bytes.length,
    });
    await _write(
      () => _channel.sendBlob(id, Stream<List<int>>.value(bytes), bytes.length),
    );
  }

  Future<void> _serveHistory(
    SyncLocalSnapshot snapshot,
    LanSyncMessage request,
  ) async {
    final historyKeys = lanSyncParseKeys(request, 'history');
    final graveKeys = lanSyncParseKeys(request, 'tombstones');
    await _send(
      LanSyncSessionMessages.history,
      lanSyncEncodeHistoryReply(
        {for (final key in historyKeys) key: snapshot.historyOf(key)},
        {
          for (final key in graveKeys)
            if (snapshot.tombstone(key) case final grave?) key: grave,
        },
      ),
    );
  }

  Future<void> _serveRecords(LanSyncMessage request) async {
    final keys = lanSyncParseKeys(request, 'keys');
    final records = await _keepAlive(() => _context.state.buildRecords(keys));
    final parts = lanSyncChunkBySize(records.map((r) => r.toJson()));
    if (parts.isEmpty) {
      await _send(LanSyncSessionMessages.records, {
        'records': const <Object?>[],
        'more': false,
      });
    }
    for (var i = 0; i < parts.length; i++) {
      await _send(LanSyncSessionMessages.records, {
        'records': parts[i],
        'more': i < parts.length - 1,
      });
    }
  }

  /// 发起方告知的计划概况：两边各要收到多少篇日记、要传多少媒体（只用于
  /// 进度显示），以及它等用户确认花了多久（用时里扣掉，两边口径一致）。
  void _notePlan(LanSyncMessage message) {
    int read(String key) {
      final value = message.fields[key];
      return value is int && value >= 0 ? value : 0;
    }

    _waited += Duration(milliseconds: read('waitedMs'));
    _setProgress(
      (p) => p.copyWith(
        receivedDiaries: read('incoming'),
        sentDiaries: read('outgoing'),
        filesTotal: read('files'),
        bytesTotal: read('bytes'),
      ),
    );
  }

  Future<void> _serveApply(List<SyncWrite> writes, LanSyncMessage tail) async {
    _setStage(LanSyncStage.merging);
    final plan = lanSyncPlanFromWire(writes, tail);
    final copies = tail.fields['copies'];
    if (copies is List) {
      _copies = [
        for (final item in copies)
          if (item is Map && item['id'] is String && item['title'] is String)
            LanSyncCopyInfo(
              diaryId: item['id'] as String,
              title: item['title'] as String,
            ),
      ];
    }
    final staging = _staging;
    _staging = null;
    final result = await _applyLocal(plan, staging);
    _received = result.tally;
    _setProgress((p) => p.copyWith(receivedDiaries: _received.diaries));
    await _send(LanSyncSessionMessages.applied, {
      'counts': _received.toJson(),
      'rekeys': [for (final rekey in result.rekeys) rekey.toJson()],
    });
  }

  Future<void> _serveFinish(LanSyncMessage message) async {
    _sent = LanSyncChangeTally.fromJson(message.fields['counts']);
    _setProgress((p) => p.copyWith(sentDiaries: _sent.diaries));
    final rekeys = _parseRekeys(message);
    if (rekeys.isNotEmpty) {
      await _keepAlive(
        () => _context.applier.adoptMediaRekeys(
          rekeys,
          includeSettings: _settingsIncluded,
        ),
      );
    }
    await _send(LanSyncSessionMessages.done);
  }
}
