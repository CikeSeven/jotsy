// 发起方的取数循环与规划（规格 §4.0），以及删除保护“保留并恢复”用的
// 规划视角 [_RestoringSide]。
part of 'lan_sync_session.dart';

extension _Planning on LanSyncSession {
  /// 取数循环 + `planSync`（规格 §4.0）。每一轮取回之后核对：要过的数据没有
  /// 全部到手（取数期间某一侧的数据变了）就中止，避免同一份请求无限重复。
  Future<SyncPlan> _plan(
    SyncLocalPlanSide local,
    SyncPlanSideData remote,
    SyncSideChoice choice,
    Set<SyncSideRole> restore,
  ) async {
    final options = SyncPlanOptions(
      nowMillis: _context.clock().millisecondsSinceEpoch,
      firstSyncWithPeer: peer.firstSync,
      localLoserTitleSuffix: _localLoserTitleSuffix,
      remoteLoserTitleSuffix: _remoteLoserTitleSuffix,
      sideChoice: choice,
    );
    final SyncPlanSide localSide = restore.contains(SyncSideRole.local)
        ? _RestoringSide(local)
        : local;
    final SyncPlanSide remoteSide = restore.contains(SyncSideRole.remote)
        ? _RestoringSide(remote)
        : remote;
    while (true) {
      final request = planSyncFetch(
        local: localSide,
        remote: remoteSide,
        options: options,
      );
      if (request.isEmpty) break;
      await _fetchRemote(remote, request);
      await _keepAlive(
        () => local.loadRecords(_context.state, request.localRecords),
      );
      _checkpoint();
      final missing =
          request.remoteRecords.any((key) => remote.recordOf(key) == null) ||
          request.remoteTombstones.any((k) => remote.tombstoneOf(k) == null) ||
          request.localRecords.any((key) => local.recordOf(key) == null);
      // 取数期间某一侧的数据变了（会话开始后有人改了库）：下次再同步。
      if (missing) throw const _SessionStop(LanSyncFailure.unknown);
    }
    return planSync(local: localSide, remote: remoteSide, options: options);
  }

  Future<void> _fetchRemote(
    SyncPlanSideData remote,
    SyncFetchRequest request,
  ) async {
    for (final chunk in _chunks(request.remoteHistory)) {
      await _send(LanSyncSessionMessages.historyGet, {
        'history': lanSyncKeyStrings(chunk),
      });
      final reply = await _expect(const {LanSyncSessionMessages.history});
      final history = syncDecodeHistory(reply.fields['history']);
      remote.addHistory({
        for (final key in chunk)
          key: history[key] ?? const <String, List<SyncHistoryEntry>>{},
      });
    }
    for (final chunk in _chunks(request.remoteTombstones)) {
      await _send(LanSyncSessionMessages.historyGet, {
        'tombstones': lanSyncKeyStrings(chunk),
      });
      final reply = await _expect(const {LanSyncSessionMessages.history});
      final wanted = chunk.toSet();
      final graves = syncDecodeTombstones(reply.fields['tombstones']);
      graves.removeWhere((key, _) => !wanted.contains(key));
      remote.addTombstones(graves);
    }
    for (final chunk in _chunks(request.remoteRecords)) {
      await _send(LanSyncSessionMessages.recordsGet, {
        'keys': lanSyncKeyStrings(chunk),
      });
      final wanted = chunk.toSet();
      while (true) {
        final part = await _expect(const {LanSyncSessionMessages.records});
        remote.addRecords(
          lanSyncParseRecords(part).where((r) => wanted.contains(r.key)),
        );
        if (part.fields['more'] != true) break;
      }
    }
  }

  static List<List<SyncKey>> _chunks(List<SyncKey> keys) => [
    for (var i = 0; i < keys.length; i += kLanSyncKeysPerRequest)
      keys.sublist(i, min(i + kLanSyncKeysPerRequest, keys.length)),
  ];
}

/// 删除保护选了“保留并恢复”时，导致删除的那一侧：它的日记墓碑一律当作
/// “删除之后又改过”（`known` 为空，任何哈希都不被覆盖）。规划器于是把在场
/// 一侧的日记判为复活——连同成员关系、留言、纪念日关联按复活的规则保留并
/// 复制回去（规格 §4.3），而不是删除。其余一切照原样委托。
class _RestoringSide implements SyncPlanSide {
  _RestoringSide(this._inner);

  final SyncPlanSide _inner;
  static final SyncTombstone _unknownDeletion = SyncTombstone(
    deletedAt: 0,
    known: const <String, List<String>>{},
  );

  @override
  String get deviceId => _inner.deviceId;
  @override
  SyncManifest get manifest => _inner.manifest;
  @override
  Set<SyncEntity> get entities => _inner.entities;
  @override
  bool get participatesInSettings => _inner.participatesInSettings;
  @override
  bool get restoredPending => _inner.restoredPending;
  @override
  SyncRecord? recordOf(SyncKey key) => _inner.recordOf(key);
  @override
  bool hasHistory(SyncKey key) => _inner.hasHistory(key);
  @override
  List<SyncHistoryEntry> historyOf(SyncKey key, String facet) =>
      _inner.historyOf(key, facet);
  @override
  bool hasTombstone(SyncKey key) => _inner.hasTombstone(key);
  @override
  SyncTombstone? tombstoneOf(SyncKey key) =>
      key.entity == SyncEntity.diary && _inner.hasTombstone(key)
      ? _unknownDeletion
      : _inner.tombstoneOf(key);
  @override
  SyncTagRename? renameOf(String oldName) => _inner.renameOf(oldName);
}
