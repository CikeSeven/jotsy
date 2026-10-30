import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/data_archive_service.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_service.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_local_state.dart';
import 'package:path/path.dart' as p;

import 'lan_sync_e2e_harness.dart';
import 'lan_sync_fake_timers.dart';

/// 两个真实服务在回环上配对：核对码（双方确认 / 一方拒绝 / 超时 / 同步页
/// 没开）与扫码（有效令牌 / 用过的令牌），以及身份重建清空配对。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeTimers timers;
  final devices = <E2eDevice>[];

  Future<E2eDevice> device(
    String name, {
    Duration? sasTimeout,
    bool attach = true,
  }) async {
    final created = await E2eDevice.create(
      name,
      timers,
      attach: attach,
      sasTimeout: sasTimeout ?? const Duration(seconds: 5),
    );
    devices.add(created);
    return created;
  }

  setUp(() {
    EditingSessionRegistry.instance.debugReset();
    timers = FakeTimers();
  });

  tearDown(() async {
    for (final d in devices.reversed) {
      await d.dispose();
    }
    devices.clear();
  });

  test('核对码：双方确认后互存公钥，两边都在线、可以同步', () async {
    final a = await device('alpha');
    final b = await device('beta');
    await pairDevices(a, b);
    expect(
      a.peerState(b)!.device.matches(b.id, b.service.identity.publicKey),
      isTrue,
    );
    expect(b.peerState(a)!.device.name, 'alpha');
    expect(a.peerState(b)!.online, isTrue);
    expect(DataArchiveService.replacedAllListeners, hasLength(2));
    final result = await a.service.syncNow(b.id);
    expect(result!.failure, isNull);
  });

  test('核对码：一方拒绝——拒绝的一方取消、另一方被拒绝，什么都不存', () async {
    final a = await device('alpha');
    final b = await device('beta');
    a.see(b);
    final outgoing = a.service.pairWith(b.id)!;
    final incoming = (await b.event<LanSyncPairingStarted>()).pairing;
    await waitForPairing(outgoing, LanSyncPairingStatus.awaitingUser);
    await outgoing.respond(true);
    await incoming.respond(false);
    expect((await incoming.finished).failure, LanSyncFailure.cancelled);
    expect((await outgoing.finished).failure, LanSyncFailure.declined);
    expect(a.service.state.value.peers, isEmpty);
    expect(b.service.state.value.peers, isEmpty);
  });

  test('核对码：没人确认就超时，两边都失败', () async {
    final a = await device(
      'alpha',
      sasTimeout: const Duration(milliseconds: 400),
    );
    final b = await device(
      'beta',
      sasTimeout: const Duration(milliseconds: 400),
    );
    a.see(b);
    final outgoing = a.service.pairWith(b.id)!;
    final incoming = (await b.event<LanSyncPairingStarted>()).pairing;
    expect((await outgoing.finished).failure, LanSyncFailure.timedOut);
    expect((await incoming.finished).status, LanSyncPairingStatus.failed);
    expect(a.service.state.value.peers, isEmpty);
  });

  test('对方的同步页没打开：传入的配对直接被拒绝（没配对过时干脆连不上）', () async {
    final a = await device('alpha');
    final b = await device('beta');
    final c = await device('gamma');
    // B 已与 C 配对：关掉同步页后服务端与发现照常运行。
    await pairDevices(c, b);
    b.service.detachPage();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(b.port, isNotNull);
    a.see(b);
    final outgoing = a.service.pairWith(b.id)!;
    expect((await outgoing.finished).failure, LanSyncFailure.declined);
    expect(b.events.whereType<LanSyncPairingStarted>(), isEmpty);

    // C 没有别的配对：页面一关就不再监听，配对请求连不上。
    await b.service.forgetPeer(c.id);
    await c.service.forgetPeer(b.id);
    c.service.detachPage();
    await waitUntil(() => c.port == null);
    a.see(c);
    final unreachable = a.service.pairWith(c.id)!;
    expect((await unreachable.finished).failure, LanSyncFailure.unreachable);
  });

  test('扫码：有效令牌配对成功并换发新码；用过的码被拒绝', () async {
    final a = await device('alpha');
    final b = await device('beta');
    final ticket = b.service.issueQrTicket()!;
    expect(ticket.payload, startsWith('jotsy-lan:v1:'));
    expect(a.service.connectQr('https://example.com'), isFalse);
    expect(a.service.connectQr(ticket.payload), isTrue);
    final outgoing = (await a.event<LanSyncPairingStarted>()).pairing;
    expect((await outgoing.finished).status, LanSyncPairingStatus.succeeded);
    final incoming = (await b.event<LanSyncPairingStarted>()).pairing;
    expect(incoming.state.value.peerId, a.id);
    expect(b.peerState(a), isNotNull);
    expect(a.peerState(b), isNotNull);
    expect(b.service.qrTicket.value!.payload, isNot(ticket.payload));

    a.events.clear();
    expect(a.service.connectQr(ticket.payload), isTrue);
    final reused = (await a.event<LanSyncPairingStarted>()).pairing;
    expect((await reused.finished).failure, LanSyncFailure.ticketExpired);

    b.service.revokeQrTicket();
    expect(b.service.qrTicket.value, isNull);
  });

  test('扫码：二维码到期自动换发', () async {
    final b = await device('beta');
    final first = b.service.issueQrTicket()!;
    timers.advance(const Duration(minutes: 2));
    expect(b.service.qrTicket.value!.payload, isNot(first.payload));
  });

  test('没有已配对设备时不碰网络：只在同步页打开期间监听；配对后一直运行', () async {
    final a = await device('alpha', attach: false);
    final b = await device('beta', attach: false);
    expect(a.binds, 0);
    expect(a.port, isNull);
    expect(a.discovery.running, isFalse);

    a.service.attachPage();
    await waitUntil(() => a.port != null && a.discovery.running);
    final port = a.port!;
    a.service.detachPage();
    await waitUntil(() => a.port == null && !a.discovery.running);
    await expectLater(
      Socket.connect(InternetAddress.loopbackIPv4, port),
      throwsA(isA<SocketException>()),
    );

    a.service.attachPage();
    b.service.attachPage();
    await waitUntil(() => a.port != null && b.port != null);
    await pairDevices(a, b);
    a.service.detachPage();
    b.service.detachPage();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(a.port, isNotNull);
    expect(b.port, isNotNull);
    expect(a.discovery.running && b.discovery.running, isTrue);
    expect((await a.service.syncNow(b.id))!.failure, isNull);

    // 取消配对、又没有页面：再次全部停掉。
    await a.service.forgetPeer(b.id);
    await waitUntil(() => a.port == null && !a.discovery.running);
    // 后台一律停掉。
    b.service.setForeground(false);
    await waitUntil(() => b.port == null && !b.discovery.running);
    b.service.setForeground(true);
    await waitUntil(() => b.port != null && b.discovery.running);
  });

  test('身份损坏重建：已配对设备与同步状态清空，偏好保留', () async {
    final a = await device('alpha');
    final b = await device('beta');
    await pairDevices(a, b);
    await a.service.syncNow(b.id);
    await a.service.renameDevice('Renamed');
    final stateDir = a.data.stateDir;
    await a.service.dispose();
    expect(DataArchiveService.replacedAllListeners, hasLength(1));
    await File(p.join(stateDir.path, 'identity.json')).writeAsString('{}');
    expect(
      File(p.join(stateDir.path, SyncLocalState.checkpointFile)).existsSync(),
      isTrue,
    );

    final reborn = LanSyncService(
      database: a.data.db,
      dataRoot: a.data.dataRoot,
      stateDir: stateDir,
      conflictTitleSuffix: (_) => '',
      hooks: LanSyncServiceHooks(
        preferredPort: 0,
        discovery: FakeLanSyncDiscovery.new,
        localAddresses: () async => const [],
        defaultDeviceName: () async => 'x',
        platformId: () => 'linux',
      ),
    );
    await reborn.start();
    expect(reborn.identity.deviceId, isNot(a.id));
    expect(reborn.state.value.peers, isEmpty);
    expect(reborn.state.value.local.name, 'Renamed');
    expect(
      File(p.join(stateDir.path, SyncLocalState.checkpointFile)).existsSync(),
      isFalse,
    );
    await reborn.dispose();
  });
}
