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
            database.todoLists,
            database.todos,
          ]),
        )
        .listen(_onTablesChanged);
    DataArchiveService.replacedAllListeners.add(noteDataReplacedByRestore);
    await _refreshAddresses();
    _updateNetwork();
    await _networkOp;
    _publish();
  }

  /// 关闭顺序（为什么要等后台任务）：会话在 `_active` 清空、`finished`
  /// 完成之后还有一步记账（`_finishSession`：上次同步时间写 store.json、同步
  /// 记录写 sessions.json），配对成功后要存对方公钥——只等 `_active` 会在
  /// 这些写入还没落盘时就返回。之后再写就是关掉之后的写入：测试删临时目录时
  /// 撞上 “Directory not empty”；真实应用里 provider 重建会让旧服务的迟到
  /// 写入盖掉新服务刚写的 store.json，还会碰已释放的 ValueNotifier。
  ///
  /// 所以：先置 `_disposed`（新的出站同步、配对、入站连接、传入的核对码一律
  /// 不再开始，见各入口的判断），取消会话与配对、断开还在握手的连接，让进行
  /// 中的任务尽快收尾；再等 [_tasks] 清空（含收尾里的记账），最后写完 store。
  ///
  /// 不会互相等待：被等的任务里能无限期挂起的只有等用户的两处——会话的确认
  /// 请求（`_active.cancel` 让它过期）与核对码（`respond(false)` 完成用户的
  /// 决定）；其余等待（连接、握手每一步、信道收尾的 linger、会话的静默）都有
  /// 自己的超时，而且套接字一断就提前结束。`respond(false)` 排在断开套接字
  /// 之前：它同步地把配对记为“本机已放弃”，握手随后因断开或拒绝失败时按
  /// 取消告知；两步在同一拍里完成，中间插不进别的事件。
  Future<void> _dispose() async {
    _disposed = true;
    if (!_started) return;
    DataArchiveService.replacedAllListeners.remove(noteDataReplacedByRestore);
    _auto.pause();
    editing.changes?.removeListener(_auto.editingChanged);
    await _tableUpdates?.cancel();
    _active?.cancel();
    for (final session in _rejecting.toList()) {
      session.cancel();
    }
    _pairing?.respond(false).ignore();
    for (final socket in _handshaking.toList()) {
      socket.destroy();
    }
    _cancelQrTimer();
    _addressTimer?.cancel();
    // 循环只是保险：`_disposed` 置位之后各入口（`_syncWith`、`_connectManual`、
    // `_startOutgoingPairing`、`_accept`、覆盖恢复）都不再登记新任务；万一
    // 等的期间仍有登记，也一并等完再写 store。
    while (_tasks.isNotEmpty) {
      await Future.wait(_tasks.toList());
    }
    await _networkOp;
    await _stopServer();
    await _discovery?.dispose();
    await _store.flush();
    _store.dispose();
    await _events.close();
  }

  /// 登记一个后台任务（见 `_tasks`），原样返回它。登记的是吞掉错误的副本：
  /// 任务自己的错误由它的调用方处理，[_dispose] 只关心它何时结束。
  Future<T> _track<T>(Future<T> work) {
    final Future<void> done = work.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _tasks.add(done);
    unawaited(done.whenComplete(() => _tasks.remove(done)));
    return work;
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
