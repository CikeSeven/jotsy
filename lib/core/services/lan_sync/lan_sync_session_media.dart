// 会话的媒体传输与写入：协商（`media.have` / `media.status`）、发送与接收
// 文件（`media.put` + 数据块）、进度与速度，以及两个角色共用的本机写入。
part of 'lan_sync_session.dart';

/// 媒体协商的结果（发起方）：要推给对方的、要从对方取的，以及两个方向的
/// 合计（进度条的分母）。
class _MediaPlan {
  const _MediaPlan(this.push, this.pull, this.files, this.bytes);

  final List<SyncMediaInfo> push;
  final List<String> pull;
  final int files;
  final int bytes;
}

final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

extension _Media on LanSyncSession {
  /// 两个方向的候选键（计划的 `mediaNeeded`）一起问对方的大小与 sha256，
  /// 再与本机的比较：接收方已有同样 sha256 的文件不传。
  Future<_MediaPlan> _negotiateMedia(SyncPlan plan) async {
    final push = plan.remote.mediaNeeded;
    final pull = plan.local.mediaNeeded;
    final union = <String>{...push, ...pull}.toList()..sort();
    if (union.isEmpty) return const _MediaPlan([], [], 0, 0);
    final remote = <String, ({int size, String sha256})>{};
    for (var i = 0; i < union.length; i += kLanSyncKeysPerRequest) {
      final chunk = union.sublist(
        i,
        min(i + kLanSyncKeysPerRequest, union.length),
      );
      await _send(LanSyncSessionMessages.mediaHave, {'keys': chunk});
      final reply = await _expect(const {LanSyncSessionMessages.mediaStatus});
      final files = reply.fields['files'];
      if (files is! Map) throw const FormatException('invalid media.status');
      for (final entry in files.entries) {
        final info = entry.value;
        if (info is! Map ||
            info['size'] is! int ||
            info['sha256'] is! String ||
            !_sha256Pattern.hasMatch(info['sha256'] as String)) {
          throw const FormatException('invalid media.status entry');
        }
        remote['${entry.key}'] = (
          size: info['size'] as int,
          sha256: info['sha256'] as String,
        );
      }
    }
    final local = await _keepAlive(() => _context.media.describe(union));
    final toPush = <SyncMediaInfo>[
      for (final key in push)
        if (local[key] case final info?)
          if (remote[key]?.sha256 != info.sha256) info,
    ];
    final toPull = <String>[
      for (final key in pull)
        if (remote[key] case final info?)
          if (local[key]?.sha256 != info.sha256) key,
    ];
    var bytes = 0;
    for (final info in toPush) {
      bytes += info.size;
    }
    for (final key in toPull) {
      bytes += remote[key]!.size;
    }
    return _MediaPlan(toPush, toPull, toPush.length + toPull.length, bytes);
  }

  /// 响应方应答 `media.have`：本机有的键的大小与 sha256。
  Future<void> _serveMediaHave(LanSyncMessage request) async {
    final keys = lanSyncParseStrings(request, 'keys');
    final described = await _keepAlive(() => _context.media.describe(keys));
    await _send(LanSyncSessionMessages.mediaStatus, {
      'files': {
        for (final info in described.values)
          info.key: {'size': info.size, 'sha256': info.sha256},
      },
    });
  }

  Future<void> _pushFiles(List<SyncMediaInfo> files) async {
    for (final info in files) {
      await _sendFile(info.key);
    }
  }

  /// 发一个本机文件；协商之后文件没了就跳过（对方的记录会引用一个缺失的
  /// 文件，与发送方本来就缺这个文件相同）。
  Future<void> _sendFile(String key) async {
    final outgoing = await _context.media.open(key);
    _checkpoint();
    if (outgoing == null) return;
    final id = _nextBlobId++;
    await _send(LanSyncSessionMessages.mediaPut, {
      'key': key,
      'size': outgoing.size,
      'sha256': outgoing.sha256,
      'blob': id,
    });
    await _write(
      () => _channel.sendBlob(id, _counted(outgoing.openRead()), outgoing.size),
    );
    _fileDone();
  }

  /// 发起方从对方取文件：`media.get` 之后对方逐个 `media.put`，以
  /// `media.end` 结束（对方没有的键直接略过）。
  Future<void> _pullFiles(List<String> keys) async {
    for (var i = 0; i < keys.length; i += kLanSyncKeysPerRequest) {
      final chunk = keys.sublist(
        i,
        min(i + kLanSyncKeysPerRequest, keys.length),
      );
      await _send(LanSyncSessionMessages.mediaGet, {'keys': chunk});
      final wanted = chunk.toSet();
      while (true) {
        final message = await _expect(const {
          LanSyncSessionMessages.mediaPut,
          LanSyncSessionMessages.mediaEnd,
        });
        if (message.type == LanSyncSessionMessages.mediaEnd) break;
        await _receiveFile(message, allowed: wanted);
      }
    }
  }

  /// 响应方应答 `media.get`。
  Future<void> _serveMediaGet(LanSyncMessage request) async {
    _setStage(LanSyncStage.transferring);
    for (final key in lanSyncParseStrings(request, 'keys')) {
      await _sendFile(key);
    }
    await _send(LanSyncSessionMessages.mediaEnd);
  }

  /// 收一个文件进本次会话的暂存区并校验大小与 sha256（不符抛
  /// [SyncMediaVerificationException]，会话以传输失败中止，不写入）。
  Future<void> _receiveFile(LanSyncMessage put, {Set<String>? allowed}) async {
    final key = put.requireString('key', maxLength: 1024);
    final size = put.fields['size'];
    final sha = put.requireString('sha256', maxLength: 64);
    final id = put.requireInt('blob', min: 1, max: 0xffffffff);
    if (size is! int ||
        size < 0 ||
        !_sha256Pattern.hasMatch(sha) ||
        (allowed != null && !allowed.contains(key)) ||
        syncMediaPathFor(_context.dataRoot.path, key) == null) {
      throw const FormatException('invalid media.put');
    }
    final staging = _staging ??= SyncMediaStaging(
      dataRoot: _context.dataRoot,
      sessionId: _newStagingId(),
      index: _context.mediaIndex,
      clock: _context.clock,
    );
    final blob = await _inbox.blob(id, _timeouts.silence);
    if (blob.length != size) {
      _discard(blob);
      throw const FormatException('media size');
    }
    try {
      await staging.receive(
        key,
        _counted(blob.data.timeout(_timeouts.silence)),
        size: size,
        sha256: sha,
      );
    } catch (_) {
      // receive 一开始就监听来流；在那之前失败（打开暂存文件出错）时这一块
      // 还没人读，取消它，免得信道停在这里。
      _discard(blob);
      rethrow;
    }
    _fileDone();
  }

  /// 两个角色共用的本机写入：计划为空时不调用写入层（不必等撤销窗口，
  /// 刷新检查点时已经记下了现状）。推迟（撤销提示一直开着）与写入失败各自
  /// 以对应原因中止。
  Future<({LanSyncChangeTally tally, List<SyncMediaRekey> rekeys})> _applyLocal(
    SyncSidePlan plan,
    SyncMediaStaging? staging,
  ) async {
    if (plan.isEmpty) {
      await staging?.dispose();
      return (tally: LanSyncChangeTally.zero, rekeys: const <SyncMediaRekey>[]);
    }
    final SyncApplyResult result;
    try {
      result = await _keepAlive(
        () => _context.applier.apply(
          plan,
          staging: staging,
          includeSettings: _settingsIncluded,
        ),
      );
    } on Object catch (error, stack) {
      debugPrint('LAN sync apply failed: $error\n$stack');
      throw const _SessionStop(LanSyncFailure.writeFailed);
    }
    if (result.isDeferred) throw const _SessionStop(LanSyncFailure.deferred);
    final diaries = result.diaries;
    return (
      tally: LanSyncChangeTally(
        added: diaries.added,
        updated: diaries.updated,
        deleted: diaries.deleted,
        others: <SyncEntity, int>{...result.summary}..remove(SyncEntity.diary),
        mediaFiles: result.mediaFiles,
        mediaBytes: result.mediaBytes,
      ),
      rekeys: result.rekeys,
    );
  }

  List<SyncMediaRekey> _parseRekeys(LanSyncMessage message) {
    final raw = message.fields['rekeys'];
    if (raw == null) return const <SyncMediaRekey>[];
    if (raw is! List) throw const FormatException('invalid rekeys');
    return [for (final item in raw) SyncMediaRekey.fromJson(item)];
  }

  /// 统计流过的字节，按 [LanSyncSessionTimeouts.progressInterval] 节流通知。
  /// `map` 保留源流的暂停与取消，背压不受影响。
  Stream<List<int>> _counted(Stream<List<int>> source) => source.map((chunk) {
    _progressBytes(chunk.length, force: false);
    return chunk;
  });

  void _fileDone() {
    _setProgress((p) => p.copyWith(filesDone: p.filesDone + 1));
    _progressBytes(0, force: true);
  }

  /// 字节数先累计在 [LanSyncSession._bytesDone]，到了通知间隔（或文件结束）
  /// 才发出新快照：每 64 KiB 一帧就通知一次，界面会被重建淹没。
  void _progressBytes(int added, {required bool force}) {
    _bytesDone += added;
    final now = _context.clock();
    final last = _lastProgressAt;
    if (!force &&
        last != null &&
        now.difference(last) < _timeouts.progressInterval) {
      return;
    }
    _lastProgressAt = now;
    _progress.value = _progress.value.copyWith(
      bytesDone: _bytesDone,
      bytesPerSecond: _speed.sample(now.millisecondsSinceEpoch, _bytesDone),
    );
  }
}

/// 最近约两秒的平均速度（按节流后的采样点算，样本数很少）。
class _SpeedMeter {
  final Queue<(int, int)> _samples = Queue<(int, int)>();

  double sample(int nowMillis, int totalBytes) {
    _samples.add((nowMillis, totalBytes));
    while (_samples.length > 2 && nowMillis - _samples.first.$1 > 2000) {
      _samples.removeFirst();
    }
    final (startMillis, startBytes) = _samples.first;
    final elapsed = nowMillis - startMillis;
    if (elapsed <= 0) return 0;
    return (totalBytes - startBytes) * 1000 / elapsed;
  }
}
