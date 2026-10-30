// 发起方的流程：hello → 刷新 → 清单 → 取数循环与规划 → 确认 → 媒体 → 写入。
part of 'lan_sync_session.dart';

extension _Initiator on LanSyncSession {
  Future<void> _runInitiator() async {
    final mine = LanSyncSessionHello(
      formatVersion: kSyncFormatVersion,
      appVersion: _context.appVersion,
      entities: lanSyncEntityNames(),
      syncSettings: _syncSettings,
      restoredPending: peer.restoredPending,
      automatic: _automatic,
    );
    await _write(() => _channel.send(mine.toMessage()));
    final reply = await _expect(const {
      LanSyncSessionMessages.hello,
      LanSyncSessionMessages.reject,
    });
    if (reply.type == LanSyncSessionMessages.reject) {
      final reason = LanSyncRejectReason.tryParse(reply.fields['reason']);
      throw _HelloRejected(reason?.failure ?? LanSyncFailure.declined);
    }
    final theirs = LanSyncSessionHello.parse(reply);
    if (!mine.compatibleWith(theirs)) {
      throw const _SessionStop(LanSyncFailure.incompatibleVersion);
    }
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
    final entities = <SyncEntity>{
      for (final name in theirs.entities) ?SyncEntity.tryParse(name),
    };
    final local = SyncLocalPlanSide(
      deviceId: _context.deviceId,
      snapshot: snapshot,
      entities: entities,
      participatesInSettings: _settingsIncluded,
      restoredPending: peer.restoredPending,
    );
    final remote = await _fetchManifest(entities, theirs);
    final plan = await _planWithConfirmations(local, remote);

    _copies = [
      for (final copy in plan.conflictCopies)
        LanSyncCopyInfo(diaryId: copy.copyId, title: copy.title),
    ];
    final media = await _negotiateMedia(plan);
    await _send(LanSyncSessionMessages.plan, {
      'incoming': plan.remote.stats[SyncEntity.diary]?.total ?? 0,
      'outgoing': plan.local.stats[SyncEntity.diary]?.total ?? 0,
      'files': media.files,
      'bytes': media.bytes,
      'waitedMs': _waited.inMilliseconds,
    });
    _setProgress(
      (p) => p.copyWith(
        sentDiaries: plan.remote.stats[SyncEntity.diary]?.total ?? 0,
        receivedDiaries: plan.local.stats[SyncEntity.diary]?.total ?? 0,
        filesTotal: media.files,
        bytesTotal: media.bytes,
      ),
    );
    if (media.files > 0) _setStage(LanSyncStage.transferring);
    await _pushFiles(media.push);
    await _pullFiles(media.pull);
    await _applyBothSides(plan);
  }

  Future<SyncPlanSideData> _fetchManifest(
    Set<SyncEntity> entities,
    LanSyncSessionHello theirs,
  ) async {
    await _send(LanSyncSessionMessages.manifestGet);
    final announce = await _expect(const {LanSyncSessionMessages.manifest});
    final size = announce.requireInt('size', max: kLanSyncManifestMaxBytes);
    final blob = await _inbox.blob(
      announce.requireInt('blob', min: 1, max: 0xffffffff),
      _timeouts.silence,
    );
    if (blob.length != size) throw const FormatException('manifest size');
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in blob.data.timeout(_timeouts.silence)) {
      bytes.add(chunk);
    }
    final decoded = lanSyncDecodeManifest(bytes.takeBytes());
    return SyncPlanSideData(
      deviceId: peer.deviceId,
      manifest: decoded.manifest,
      entities: entities,
      participatesInSettings: theirs.syncSettings,
      restoredPending: theirs.restoredPending,
      tombstoneKeys: decoded.tombstoneKeys,
      renames: decoded.renames,
    );
  }

  /// 规划并处理需要确认的事项（规格 §4.5）：
  /// - 以哪边为准：自动同步中止；手动同步问用户，选了以某边为准就按它重新
  ///   规划（规划器照样报告数量，“已经选过”由这里记住）；
  /// - 删除保护：自动同步中止；手动同步逐项问用户，选“保留并恢复”的，把
  ///   导致删除的那一侧的日记墓碑当作“删除之后又改过”（[_RestoringSide]），
  ///   重新规划后这些日记连同从属复活、复制回去，而不是删除。
  /// 用户取消（null）即中止，告诉对方 `declined`，两边都不写。
  Future<SyncPlan> _planWithConfirmations(
    SyncLocalPlanSide local,
    SyncPlanSideData remote,
  ) async {
    var choice = SyncSideChoice.keepBoth;
    var plan = await _plan(local, remote, choice, const <SyncSideRole>{});
    if (plan.confirmations.sideChoiceNeeded) {
      final request = LanSyncSideChoiceRequest(
        peerId: peer.deviceId,
        counts: plan.confirmations.sideChoiceCounts,
      );
      choice = await _ask(request, request.answer);
      if (choice != SyncSideChoice.keepBoth) {
        plan = await _plan(local, remote, choice, const <SyncSideRole>{});
      }
    }
    final restore = <SyncSideRole>{};
    for (final guard in plan.confirmations.deletionGuards) {
      final request = LanSyncDeletionGuardRequest(
        peerId: peer.deviceId,
        count: guard.count,
        onLocalSide: guard.side == SyncSideRole.local,
      );
      final decision = await _ask(request, request.answer);
      if (decision == LanSyncDeletionDecision.keepAndRestore) {
        restore.add(
          guard.side == SyncSideRole.local
              ? SyncSideRole.remote
              : SyncSideRole.local,
        );
      }
    }
    if (restore.isNotEmpty) plan = await _plan(local, remote, choice, restore);
    return plan;
  }

  /// 交给调用方问用户，等应答（期间发 ping，受总上限约束）。自动同步不问，
  /// 直接以“需要确认”中止；应答为 null 即取消。
  Future<T> _ask<T extends Object>(
    LanSyncConfirmationRequest request,
    Future<T?> answer,
  ) async {
    if (_automatic) {
      throw const _SessionStop(LanSyncFailure.needsConfirmation);
    }
    _pendingConfirmation = request;
    final askedAt = _context.clock();
    try {
      _onConfirmation(request);
      final result = await _keepAlive(
        () => Future.any<T?>([
          answer,
          _inbox.whenStopped.then<T?>((_) {
            _inbox.throwIfStopped();
            return null;
          }),
        ]).timeout(_timeouts.confirmation),
      );
      _checkpoint();
      if (result == null) {
        throw const _SessionStop(LanSyncFailure.cancelled, wire: 'declined');
      }
      return result;
    } finally {
      _waited += _context.clock().difference(askedAt);
      _pendingConfirmation = null;
      request.expire();
    }
  }

  /// 响应方先写、发起方后写，再互相照做媒体改键（规格 §6 末段）。
  Future<void> _applyBothSides(SyncPlan plan) async {
    _setStage(LanSyncStage.merging);
    for (final part in lanSyncChunkBySize(
      plan.remote.writes.map(lanSyncWriteToJson),
    )) {
      await _send(LanSyncSessionMessages.applyPart, {'writes': part});
    }
    await _send(LanSyncSessionMessages.apply, {
      ...lanSyncPlanTailToJson(plan.remote),
      'copies': [
        for (final copy in _copies) {'id': copy.diaryId, 'title': copy.title},
      ],
    });
    final applied = await _expect(const {LanSyncSessionMessages.applied});
    _sent = LanSyncChangeTally.fromJson(applied.fields['counts']);
    final theirRekeys = _parseRekeys(applied);
    _setProgress((p) => p.copyWith(sentDiaries: _sent.diaries));

    final staging = _staging;
    _staging = null;
    final mine = await _applyLocal(plan.local, staging);
    _received = mine.tally;
    _setProgress((p) => p.copyWith(receivedDiaries: _received.diaries));
    if (theirRekeys.isNotEmpty) {
      await _keepAlive(
        () => _context.applier.adoptMediaRekeys(
          theirRekeys,
          includeSettings: _settingsIncluded,
        ),
      );
    }
    await _send(LanSyncSessionMessages.finish, {
      'rekeys': [for (final rekey in mine.rekeys) rekey.toJson()],
      'counts': _received.toJson(),
    });
    await _expect(const {LanSyncSessionMessages.done});
  }
}
