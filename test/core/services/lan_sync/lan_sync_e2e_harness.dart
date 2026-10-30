import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_discovery.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_service.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';
import 'package:node_diary/core/services/settings_service.dart';

import '../../../support/lan_sync_two_devices.dart';
import 'lan_sync_fake_timers.dart';

/// 端到端测试的一台“设备”：真实的 [LanSyncService]（回环 TCP、真实握手与
/// 信道、真实写入层），发现换成可控的 [FakeLanSyncDiscovery]，自动同步的
/// 时钟与计时器用共享的 [FakeTimers]。数据库、目录与比较工具来自
/// test/support/lan_sync_two_devices.dart 的 [LanSyncTestDevice]——只用它的
/// db / 目录 / `canonical()`，不碰它自带的 `state` / `applier`（服务有自己的一份，两份同时用会让缓存过期）。
class E2eDevice {
  E2eDevice._(this.data, this.service, this.discovery, this.editors);

  static Future<E2eDevice> create(
    String name,
    FakeTimers timers, {
    SettingsService? settings,
    bool autoSync = false,
    bool attach = true,
    String Function(String deviceName)? conflictTitleSuffix,
    Duration sasTimeout = const Duration(seconds: 5),
    LanSyncSessionTimeouts session = const LanSyncSessionTimeouts(
      silence: Duration(seconds: 5),
      keepAlive: Duration(milliseconds: 100),
      confirmation: Duration(seconds: 10),
    ),
  }) async {
    final data = await LanSyncTestDevice.create(
      name,
      clock: LanSyncTestClock(),
    );
    final discovery = FakeLanSyncDiscovery();
    final editors = ValueNotifier<int>(0);
    late final E2eDevice device;
    final service = LanSyncService(
      database: data.db,
      dataRoot: data.dataRoot,
      stateDir: data.stateDir,
      settings: settings,
      conflictTitleSuffix: conflictTitleSuffix ?? (peer) => ' (copy · $peer)',
      appVersion: 'test',
      editing: LanSyncEditingGate(
        isEditing: () => editors.value > 0,
        flushAll: () async {},
        changes: editors,
      ),
      hooks: LanSyncServiceHooks(
        clock: timers.now,
        preferredPort: 0,
        bindServer: (port) {
          device.binds++;
          return ServerSocket.bind(InternetAddress.loopbackIPv4, port);
        },
        connect: (host, port, timeout) async {
          if (device.blockOutgoing) {
            throw const SocketException('blocked by the test firewall');
          }
          final socket = await Socket.connect(host, port, timeout: timeout);
          device.lastSocket = socket;
          return socket;
        },
        discovery: () => discovery,
        localAddresses: () async => ['127.0.0.1'],
        defaultDeviceName: () async => name,
        platformId: () => 'linux',
        timer: timers.create,
      ),
      timings: LanSyncServiceTimings(
        connectTimeout: const Duration(seconds: 2),
        handshakeStep: const Duration(seconds: 5),
        sasTimeout: sasTimeout,
        handshakeLinger: const Duration(milliseconds: 200),
        session: session,
      ),
    );
    device = E2eDevice._(data, service, discovery, editors);
    service.events.listen(device.events.add);
    await service.start();
    // 默认关掉自动同步（测试自己决定何时同步），并保持“同步页打开”：没有
    // 配对时也有服务端与发现、接受传入的核对码配对。
    if (!autoSync) await service.setAutoSync(false);
    if (attach) {
      service.attachPage();
      await waitUntil(() => device.port != null && discovery.running);
    }
    return device;
  }

  final LanSyncTestDevice data;
  final LanSyncService service;
  final FakeLanSyncDiscovery discovery;
  final ValueNotifier<int> editors;
  final List<LanSyncEngineEvent> events = [];
  bool blockOutgoing = false;
  Socket? lastSocket;

  /// 服务端绑定过几次（证明没配对、没打开同步页时不碰网络）。
  int binds = 0;

  /// 服务端现在监听的端口；没在监听时为 null。
  int? get port => service.state.value.local.port;

  String get id => service.identity.deviceId;

  set editing(bool value) => editors.value = value ? 1 : 0;

  /// 让本机的发现“看到”[other]（它的信标指向它的回环端口）。[other] 只听
  /// 不发（不可被发现）时看不到它。
  void see(E2eDevice other) {
    if (!other.discovery.advertise) return;
    discovery.see(other.discovery.beacon!());
  }

  /// 等到第一个满足条件的 [T] 事件（含已经发生过的）。
  Future<T> event<T extends LanSyncEngineEvent>([
    bool Function(T event)? where,
  ]) async {
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(deadline)) {
      for (final event in events) {
        if (event is T && (where == null || where(event))) return event;
      }
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    throw TimeoutException('no ${T.toString()} event');
  }

  List<LanSyncSessionEnded> get endedSessions =>
      events.whereType<LanSyncSessionEnded>().toList();

  /// 自动应答确认请求。
  void answerWith({
    SyncSideChoice side = SyncSideChoice.keepBoth,
    LanSyncDeletionDecision deletion = LanSyncDeletionDecision.syncDeletion,
  }) {
    service.events.listen((event) {
      if (event is! LanSyncConfirmationRequested) return;
      switch (event.request) {
        case final LanSyncSideChoiceRequest request:
          request.respond(side);
        case final LanSyncDeletionGuardRequest request:
          request.respond(deletion);
      }
    });
  }

  LanSyncPeerState? peerState(E2eDevice other) =>
      service.state.value.peer(other.id);

  Future<void> dispose() async {
    await service.dispose();
    await data.dispose();
  }
}

/// 核对码配对 [a] → [b]（双方确认），返回之后两边互相在线。
Future<void> pairDevices(E2eDevice a, E2eDevice b) async {
  b.service.attachPage();
  a.see(b);
  final outgoing = a.service.pairWith(b.id)!;
  await waitForPairing(outgoing, LanSyncPairingStatus.awaitingUser);
  final incoming = (await b.event<LanSyncPairingStarted>(
    (e) => e.pairing.incoming,
  )).pairing;
  expect(incoming.state.value.code, outgoing.state.value.code);
  await outgoing.respond(true);
  await incoming.respond(true);
  expect((await outgoing.finished).status, LanSyncPairingStatus.succeeded);
  expect((await incoming.finished).status, LanSyncPairingStatus.succeeded);
  b.service.detachPage();
  b.see(a);
  b.events.clear();
  a.events.clear();
}

Future<void> waitForPairing(
  LanSyncPairing pairing,
  LanSyncPairingStatus status,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (pairing.state.value.status != status) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('pairing never reached $status');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// 等到条件成立（轮询，回环上的异步步骤都很快）。
Future<void> waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 15));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) throw TimeoutException('waitUntil');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// 只回应会话层用到的部分：信标函数、在线表、运行状态。
class FakeLanSyncDiscovery implements LanSyncDiscovery {
  final ValueNotifier<Map<String, LanSyncPresence>> _peers =
      ValueNotifier<Map<String, LanSyncPresence>>(const {});
  final ValueNotifier<LanSyncDiscoveryStatus> _status =
      ValueNotifier<LanSyncDiscoveryStatus>(LanSyncDiscoveryStatus.stopped);
  LanSyncBeacon Function()? beacon;
  Duration _interval = kLanSyncBeaconIntervalAuto;

  @override
  bool advertise = true;

  bool get running => _status.value.running;

  @override
  ValueListenable<Map<String, LanSyncPresence>> get peers => _peers;

  @override
  ValueListenable<LanSyncDiscoveryStatus> get status => _status;

  @override
  Duration get interval => _interval;

  @override
  Future<void> start({
    required LanSyncBeacon Function() beacon,
    required Duration interval,
  }) async {
    this.beacon = beacon;
    _interval = interval;
    _status.value = const LanSyncDiscoveryStatus(
      running: true,
      listening: true,
    );
  }

  @override
  void setInterval(Duration interval) => _interval = interval;

  @override
  Future<void> stop() async {
    _status.value = LanSyncDiscoveryStatus.stopped;
    _peers.value = const {};
  }

  @override
  Future<void> dispose() async {}

  /// 收到 [other] 的信标（发现没在运行时收不到）。
  void see(LanSyncBeacon other) {
    if (!running) return;
    _peers.value = {
      ..._peers.value,
      other.deviceId: LanSyncPresence(
        beacon: other,
        address: InternetAddress.loopbackIPv4,
        lastSeen: DateTime.now(),
      ),
    };
  }

  void lose(String deviceId) =>
      _peers.value = {..._peers.value}..remove(deviceId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
