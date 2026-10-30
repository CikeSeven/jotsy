// 服务的生命周期：启动、关闭、前后台与页面引用计数（lan_sync_service.dart
// 的一部分；公开入口与说明在主文件）。
part of 'lan_sync_service.dart';

extension _Lifecycle on LanSyncService {
  Future<void> _start() async {
    if (_started) return;
    _started = true;
    await stateDir.create(recursive: true);
    final load = await LanSyncIdentityStore(stateDir).loadOrCreate();
    _identity = load.identity;
    _store = await LanSyncStore.open(stateDir);
    _syncState = SyncLocalState(
      database: database,
      stateDir: stateDir,
      settings: settings,
      clock: _now,
    );
    _mediaIndex = SyncMediaIndex(stateDir: stateDir, dataRoot: dataRoot);
    _mediaLibrary = SyncMediaLibrary(
      dataRoot: dataRoot,
      index: _mediaIndex,
      clock: _now,
    );
    _applier = SyncApplier(
      database: database,
      dataRoot: dataRoot,
      state: _syncState,
      media: _mediaLibrary,
      settings: settings,
      registry: registry,
    );
    if (load.created) {
      await _store.clearPairing();
      await _syncState.resetAfterRestore();
    }
    await SyncMediaStaging.sweepStale(dataRoot, now: _now());
    _defaultName = await hooks.defaultDeviceName();
    _auto = _createScheduler();
    _store.data.addListener(_publish);
    // 配对、取消配对与“可被发现”都在店里：变了就按新的设备数重新判定网络。
    _store.data.addListener(_updateNetwork);
    _store.sessions.addListener(_publish);
    editing.changes?.addListener(_auto.editingChanged);
    _tableUpdates = database
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            database.diaries,
            database.tags,
            database.diaryTags,
            database.notebooks,
            database.diaryNotebooks,
            database.diaryComments,
            database.diaryTemplates,
            database.anniversaries,
            database.dayMoods,
          ]),
        )
        .listen(_onTablesChanged);
    DataArchiveService.replacedAllListeners.add(noteDataReplacedByRestore);
    await _refreshAddresses();
    _updateNetwork();
    await _networkOp;
    _publish();
  }

  Future<void> _dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (!_started) return;
    DataArchiveService.replacedAllListeners.remove(noteDataReplacedByRestore);
    _auto.pause();
    editing.changes?.removeListener(_auto.editingChanged);
    await _tableUpdates?.cancel();
    final active = _active;
    active?.cancel();
    await active?.finished;
    _pairing?.respond(false).ignore();
    _cancelQrTimer();
    _addressTimer?.cancel();
    await _networkOp;
    await _stopServer();
    await _discovery?.dispose();
    await _store.flush();
    _store.dispose();
    await _events.close();
  }

  void _setForeground(bool foreground) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    if (!_started || _disposed) return;
    if (foreground) {
      unawaited(_resume());
    } else {
      _auto.pause();
      _updateNetwork();
    }
  }

  Future<void> _resume() async {
    await _refreshAddresses();
    _updateNetwork();
    await _networkOp;
    _auto.resumed();
  }

  void _attachPage() {
    _attachments++;
    if (_attachments == 1 && _started && !_disposed) {
      unawaited(_refreshAddresses().then((_) => _publish()));
      _addressTimer = Timer.periodic(timings.addressRefresh, (_) {
        unawaited(_refreshAddresses().then((_) => _publish()));
      });
    }
    _updateNetwork();
    _publish();
  }

  void _detachPage() {
    if (_attachments == 0) return;
    _attachments--;
    if (_attachments == 0) {
      _addressTimer?.cancel();
      _addressTimer = null;
    }
    _updateNetwork();
    _publish();
  }
}
