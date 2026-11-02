import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_service.dart';
import 'package:path/path.dart' as p;

import 'lan_sync_e2e_harness.dart';
import 'lan_sync_fake_timers.dart';
import 'lan_sync_session_harness.dart';

/// 关闭服务时的收尾：会话在“正在进行”的标记清掉之后还有一步记账（上次同步
/// 时间写 store.json、同步记录写 sessions.json）。[LanSyncService.dispose]
/// 必须等这步落盘才返回，之后不再碰状态目录——否则测试删临时目录时撞上
/// “Directory not empty”，真实应用里 provider 重建时旧服务的迟到写入会盖掉
/// 新服务的 store.json。
///
/// 抓住竞争的办法：在状态快照里看到会话进度刚变回 null 的那一刻（会话位置
/// 已让出、记账还没开始）同步调用 dispose——这正是“只等会话位置”漏掉的
/// 窗口；并在 dispose 返回的 then 回调里同步拍下状态目录（中间不经事件
/// 循环，排在后面的文件写入插不进来），过一会儿再拍一次比较。
///
/// 另外三条确认等后台任务不会卡住关闭：被等的任务正在等用户（同步的确认、
/// 传入与发起的核对码）时，关闭替用户放弃，远早于各自的超时返回。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeTimers timers;
  final devices = <E2eDevice>[];

  Future<(E2eDevice, E2eDevice)> unpairedPair({
    Duration sasTimeout = const Duration(seconds: 5),
  }) async {
    final a = await E2eDevice.create('alpha', timers, sasTimeout: sasTimeout);
    final b = await E2eDevice.create('beta', timers, sasTimeout: sasTimeout);
    devices.addAll([a, b]);
    return (a, b);
  }

  Future<(E2eDevice, E2eDevice)> pairedPair() async {
    final (a, b) = await unpairedPair();
    await pairDevices(a, b);
    return (a, b);
  }

  /// [a] 向 [b] 发起核对码配对，等到两边都在等本机用户核对数字。
  Future<(LanSyncPairing, LanSyncPairing)> pairingAwaitingUser(
    E2eDevice a,
    E2eDevice b,
  ) async {
    a.see(b);
    final outgoing = a.service.pairWith(b.id)!;
    await waitForPairing(outgoing, LanSyncPairingStatus.awaitingUser);
    final incoming = (await b.event<LanSyncPairingStarted>(
      (e) => e.pairing.incoming,
    )).pairing;
    await waitForPairing(incoming, LanSyncPairingStatus.awaitingUser);
    return (outgoing, incoming);
  }

  /// 状态目录里的配对记录（重新从文件读）。
  Future<List<LanSyncPairedDevice>> savedPeers(E2eDevice device) async {
    final store = await LanSyncStore.open(device.data.stateDir);
    final peers = store.data.value.peers;
    store.dispose();
    return peers;
  }

  /// 状态目录里每个文件的内容（同步读取）。
  Map<String, List<int>> snapshot(Directory dir) => <String, List<int>>{
    for (final file in dir.listSync(recursive: true).whereType<File>())
      p.relative(file.path, from: dir.path): file.readAsBytesSync(),
  };

  /// [device] 与 [peer] 的会话进度从有变回没有时，立刻（在状态通知里同步地）
  /// 开始关闭 [device]；返回 dispose 返回那一刻拍下的状态目录。[callTwice]
  /// 时紧接着再调一次 dispose，拍的是第二次调用返回的那一刻。
  Future<Map<String, List<int>>> disposeWhenSessionEnds(
    E2eDevice device,
    E2eDevice peer, {
    bool callTwice = false,
  }) {
    final settled = Completer<Map<String, List<int>>>();
    var sawSession = false;
    var disposing = false;
    void listener() {
      if (disposing) return;
      if (device.peerState(peer)?.session != null) {
        sawSession = true;
        return;
      }
      if (!sawSession) return;
      disposing = true;
      final first = device.service.dispose();
      final returned = callTwice ? device.service.dispose() : first;
      settled.complete(returned.then((_) => snapshot(device.data.stateDir)));
    }

    device.service.state.addListener(listener);
    return settled.future;
  }

  /// dispose 返回那一刻拍下的状态目录：之后不再变化（没有迟到的写入），
  /// 而且已经包含这次同步的记录与上次同步时间（记账在返回前落盘了）。
  Future<void> expectSettled(
    E2eDevice device,
    E2eDevice peer,
    Map<String, List<int>> atReturn,
  ) async {
    // 真实时间：迟到的写入是文件 I/O，给它足够的机会出现。
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(snapshot(device.data.stateDir), atReturn);
    final store = await LanSyncStore.open(device.data.stateDir);
    expect(store.sessions.value, hasLength(1));
    expect(store.sessions.value.single.peerId, peer.id);
    expect(store.peer(peer.id)!.lastSyncAt, isNotNull);
    store.dispose();
  }

  setUp(() {
    EditingSessionRegistry.instance.debugReset();
    timers = FakeTimers();
  });

  tearDown(() async {
    for (final d in devices) {
      await d.dispose();
    }
    devices.clear();
  });

  test('响应方会话刚结束就关闭：dispose 等记账落盘后才返回，之后不再写状态目录', () async {
    final (a, b) = await pairedPair();
    await seedDiary(a.data.db, 'a1', title: 'A1');
    final settled = disposeWhenSessionEnds(b, a);
    final result = await a.service.syncNow(b.id);
    expect(result!.failure, isNull);
    await expectSettled(b, a, await settled);
  });

  test('发起方会话刚结束就关闭：dispose 等记账落盘后才返回，之后不再写状态目录', () async {
    final (a, b) = await pairedPair();
    await seedDiary(b.data.db, 'b1', title: 'B1');
    final settled = disposeWhenSessionEnds(a, b);
    final result = await a.service.syncNow(b.id);
    expect(result!.failure, isNull);
    await expectSettled(a, b, await settled);
  });

  test('关闭途中再调 dispose：第二个调用方同样等到真正关完', () async {
    final (a, b) = await pairedPair();
    await seedDiary(a.data.db, 'a1', title: 'A1');
    final settled = disposeWhenSessionEnds(b, a, callTwice: true);
    await a.service.syncNow(b.id);
    await expectSettled(b, a, await settled);
  });

  // 以下三条是“dispose 等后台任务”可能卡住的地方：被等的任务在等用户。
  // 关闭必须替用户放弃，而不是等到确认或核对码超时。

  test('手动同步正等用户确认时关闭：不等确认超时，会话按取消结束、记账落盘后才返回', () async {
    final (a, b) = await pairedPair();
    // 首次同步、同一篇两边都有且内容不同：以哪边为准要问用户（不应答）。
    await seedDiary(a.data.db, 'same', title: 'mine', updated: 1700000500);
    await seedDiary(b.data.db, 'same', title: 'theirs', updated: 1700000400);
    final pending = a.service.syncNow(b.id);
    await a.event<LanSyncConfirmationRequested>();
    // 确认的上限是 10 秒（E2eDevice 的会话计时）：关闭若在等用户，这里超时。
    final atReturn = await a.service
        .dispose()
        .then((_) => snapshot(a.data.stateDir))
        .timeout(const Duration(seconds: 5));
    final result = await pending;
    expect(result!.failure, LanSyncFailure.cancelled);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(snapshot(a.data.stateDir), atReturn);
    final store = await LanSyncStore.open(a.data.stateDir);
    expect(store.sessions.value.single.failure, LanSyncFailure.cancelled);
    expect(store.peer(b.id)!.lastSyncAt, isNull);
    store.dispose();
  });

  test('传入的核对码正等本机用户时关闭：不等核对码超时，配对按取消结束、不存对方', () async {
    // 核对码超时 30 秒，远大于下面等关闭的 5 秒。
    final (a, b) = await unpairedPair(sasTimeout: const Duration(seconds: 30));
    final (outgoing, incoming) = await pairingAwaitingUser(a, b);
    await b.service.dispose().timeout(const Duration(seconds: 5));
    // 握手的收尾也在关闭等的任务里：返回时配对已经有了结果。
    expect(incoming.state.value.status, LanSyncPairingStatus.failed);
    expect(incoming.state.value.failure, LanSyncFailure.cancelled);
    final theirs = await outgoing.finished.timeout(const Duration(seconds: 5));
    expect(theirs.status, LanSyncPairingStatus.failed);
    expect(await savedPeers(b), isEmpty);
  });

  test('发起的核对码正等本机用户时关闭：不等核对码超时，告诉对方拒绝、不存对方', () async {
    final (a, b) = await unpairedPair(sasTimeout: const Duration(seconds: 30));
    final (outgoing, incoming) = await pairingAwaitingUser(a, b);
    await a.service.dispose().timeout(const Duration(seconds: 5));
    expect(outgoing.state.value.status, LanSyncPairingStatus.failed);
    expect(outgoing.state.value.failure, LanSyncFailure.cancelled);
    final theirs = await incoming.finished.timeout(const Duration(seconds: 5));
    expect(theirs.status, LanSyncPairingStatus.failed);
    expect(theirs.failure, LanSyncFailure.declined);
    expect(await savedPeers(a), isEmpty);
  });
}
