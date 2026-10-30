import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/data_archive_service.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_service.dart';
import 'package:node_diary/ui/lan_sync/controllers/engine_lan_sync_ui_controller.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_platform.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_session_view.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_ui_events.dart';
import 'package:node_diary/ui/lan_sync/models/lan_sync_view_state.dart';
import 'package:node_diary/ui/lan_sync/providers/lan_sync_engine_assembly.dart';

import '../../core/services/lan_sync/lan_sync_e2e_harness.dart';
import '../../core/services/lan_sync/lan_sync_fake_timers.dart';
import '../../core/services/lan_sync/lan_sync_session_harness.dart';

/// 两台真实引擎（回环 TCP、真实握手与写入，见 lan_sync_e2e_harness.dart）
/// 各包一个真正的界面控制器，只经界面接口驱动：发现 → 配对 → 同步 → 冲突
/// 副本 → 对方在编辑 / 本机在编辑 → 取消配对；另测启动窗口里的指令排队、
/// 启动失败与二维码。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeTimers timers;
  final devices = <E2eDevice>[];
  final controllers = <EngineLanSyncUiController>[];

  String zhSuffix(String name) =>
      lanSyncConflictTitleSuffix(const Locale('zh'), name);

  Future<E2eDevice> device(String name) async {
    final created = await E2eDevice.create(
      name,
      timers,
      attach: false,
      conflictTitleSuffix: zhSuffix,
    );
    devices.add(created);
    return created;
  }

  EngineLanSyncUiController wrap(Future<LanSyncService> Function() create) {
    final controller = EngineLanSyncUiController(
      createService: create,
      platform: LanSyncPlatform.linux,
    );
    controllers.add(controller);
    return controller;
  }

  setUp(() {
    EditingSessionRegistry.instance.debugReset();
    timers = FakeTimers();
  });

  tearDown(() async {
    for (final c in controllers.reversed) {
      await c.dispose();
    }
    controllers.clear();
    for (final d in devices.reversed) {
      await d.dispose();
    }
    devices.clear();
  });

  /// 等到事件列表里出现第一个满足条件的 [T]。
  Future<T> eventIn<T extends LanSyncUiEvent>(
    List<LanSyncUiEvent> events, [
    bool Function(T event)? where,
  ]) async {
    late T found;
    await waitUntil(() {
      for (final event in events) {
        if (event is T && (where == null || where(event))) {
          found = event;
          return true;
        }
      }
      return false;
    });
    return found;
  }

  LanSyncPeerView? peerIn(EngineLanSyncUiController c, String id) {
    for (final peer in c.state.value.peers) {
      if (peer.deviceId == id) return peer;
    }
    return null;
  }

  test('两台设备只经界面接口：发现、配对、同步、冲突副本、编辑中、取消配对', () async {
    final a = await device('alpha');
    final b = await device('beta');
    final ca = wrap(() async => a.service);
    final cb = wrap(() async => b.service);
    expect(await ca.ready, isTrue);
    expect(await cb.ready, isTrue);
    // 覆盖恢复的监听由引擎启动时自己登记，装配处不需要另接。
    expect(
      DataArchiveService.replacedAllListeners,
      contains(a.service.noteDataReplacedByRestore),
    );
    final eventsA = <LanSyncUiEvent>[];
    final eventsB = <LanSyncUiEvent>[];
    ca.events.listen(eventsA.add);
    cb.events.listen(eventsB.add);

    // 发现：两边都打开同步页，a 看到 b 出现在附近。
    ca.attachPage();
    cb.attachPage();
    await waitUntil(
      () =>
          ca.state.value.local.port != null &&
          cb.state.value.local.port != null &&
          a.discovery.running &&
          b.discovery.running,
    );
    expect(ca.state.value.local.name, 'alpha');
    expect(ca.state.value.searching, isTrue);
    a.see(b);
    await waitUntil(() => ca.state.value.nearby.any((n) => n.deviceId == b.id));

    // 配对：两边的配对事件都走到等用户确认、核对码相同，双方确认后成功。
    await ca.pairWith(b.id);
    final pa = await eventIn<LanSyncPairingEvent>(eventsA);
    final pb = await eventIn<LanSyncPairingEvent>(eventsB);
    expect(pa.direction, LanSyncPairingDirection.outgoing);
    expect(pb.direction, LanSyncPairingDirection.incoming);
    expect(pb.peerName, 'alpha');
    expect(pb.platform, LanSyncPlatform.linux);
    await waitUntil(
      () =>
          pa.phase.value is LanSyncPairingAwaitingUser &&
          pb.phase.value is LanSyncPairingAwaitingUser,
    );
    final code = (pa.phase.value as LanSyncPairingAwaitingUser).code;
    expect((pb.phase.value as LanSyncPairingAwaitingUser).code, code);
    var phaseNotifications = 0;
    pa.phase.addListener(() => phaseNotifications++);
    await pa.respond(true);
    expect(pa.phase.value, LanSyncPairingAwaitingPeer(code));
    await pb.respond(true);
    await waitUntil(
      () =>
          pa.phase.value is LanSyncPairingSucceeded &&
          pb.phase.value is LanSyncPairingSucceeded,
    );
    expect(phaseNotifications, greaterThanOrEqualTo(2));
    expect((pa.phase.value as LanSyncPairingSucceeded).peerId, b.id);
    expect((pb.phase.value as LanSyncPairingSucceeded).peerId, a.id);
    await waitUntil(() => peerIn(ca, b.id) != null && peerIn(cb, a.id) != null);
    expect(ca.state.value.nearby, isEmpty);
    expect(peerIn(ca, b.id)!.name, 'beta');
    b.see(a);

    // 同步：会话进度出现在设备上，结束后只有发起方收到完成摘要。
    await seedDiary(a.data.db, 'a1', title: 'A1');
    await seedDiary(b.data.db, 'b1', title: 'B1');
    final stages = <LanSyncSessionStage>[];
    void recordStage() {
      final session = peerIn(ca, b.id)?.session;
      if (session != null && (stages.isEmpty || stages.last != session.stage)) {
        stages.add(session.stage);
      }
    }

    ca.state.addListener(recordStage);
    await ca.syncNow(b.id);
    final finished = await eventIn<LanSyncSessionFinishedEvent>(eventsA);
    ca.state.removeListener(recordStage);
    expect(finished.peerId, b.id);
    expect(finished.summary.succeeded, isTrue);
    expect(finished.summary.peerName, 'beta');
    expect(finished.summary.sent.added, 1);
    expect(finished.summary.received.added, 1);
    expect(stages, isNotEmpty);
    expect(stages.first, LanSyncSessionStage.connecting);
    for (var i = 1; i < stages.length; i++) {
      expect(stages[i].index, greaterThan(stages[i - 1].index));
    }
    await waitUntil(() => peerIn(ca, b.id)!.session == null);
    final peer = peerIn(ca, b.id)!;
    expect(peer.lastSyncAt, isNotNull);
    expect(peer.history.single.succeeded, isTrue);
    expect(peer.history.single.firstSync, isTrue);
    await waitUntil(() => peerIn(cb, a.id)!.history.isNotEmpty);
    expect(eventsB.whereType<LanSyncSessionFinishedEvent>(), isEmpty);

    // 冲突：两边都改了同一篇，本机的较旧、成了副本，标题带本机的设备名。
    await setTitle(a.data.db, 'a1', 'A from alpha', updated: 1800000100);
    await setTitle(b.data.db, 'a1', 'A from beta', updated: 1800000200);
    eventsA.clear();
    await ca.syncNow(b.id);
    final conflict = await eventIn<LanSyncSessionFinishedEvent>(eventsA);
    expect(conflict.summary.succeeded, isTrue);
    expect(
      conflict.summary.conflictCopies.single.title,
      'A from alpha${zhSuffix('alpha')}',
    );
    expect(conflict.summary.conflictCopies.single.title, contains('alpha'));

    // 对方在编辑：以新加的界面原因 busy 结束，同步记录里同样。
    b.editing = true;
    eventsA.clear();
    await ca.syncNow(b.id);
    final busy = await eventIn<LanSyncSessionFinishedEvent>(eventsA);
    expect(busy.summary.failureReason, LanSyncFailureReason.busy);
    await waitUntil(
      () =>
          peerIn(ca, b.id)!.history.first.failureReason ==
          LanSyncFailureReason.busy,
    );
    b.editing = false;

    // 本机在编辑：手动同步不开始，以 localEditing 结束。
    a.editing = true;
    eventsA.clear();
    await ca.syncNow(b.id);
    final local = await eventIn<LanSyncSessionFinishedEvent>(eventsA);
    expect(local.summary.failureReason, LanSyncFailureReason.localEditing);
    a.editing = false;

    // 取消配对：设备从列表里消失。
    await ca.forgetPeer(b.id);
    await waitUntil(() => peerIn(ca, b.id) == null);
  });

  test('启动窗口：页面计数与指令排队到引擎就绪后执行', () async {
    final engine = Completer<LanSyncService>();
    final c = wrap(() => engine.future);
    expect(c.state.value.local.name, isEmpty);
    expect(c.state.value.peers, isEmpty);
    c.attachPage();
    expect(c.connectQr('https://example.com'), isFalse);
    final rename = c.renameDevice('Desk');
    final a = await device('alpha');
    engine.complete(a.service);
    await rename;
    expect(await c.ready, isTrue);
    await waitUntil(
      () => c.state.value.local.name == 'Desk' && c.state.value.searching,
    );
    expect(a.service.state.value.local.name, 'Desk');
  });

  test('引擎启动失败：保持初始状态，配对类指令以失败的配对告知', () async {
    final c = wrap(() async => throw StateError('no data directory'));
    final events = <LanSyncUiEvent>[];
    c.events.listen(events.add);
    expect(await c.ready, isFalse);
    await c.renameDevice('Desk');
    await c.setAutoSync(false);
    expect(c.state.value.local.name, isEmpty);
    await c.pairWith('nobody');
    await c.connectManual(' 192.168.1.20 ', 24562);
    await waitUntil(() => events.length == 2);
    final manual = events.last as LanSyncPairingEvent;
    expect(manual.peerName, '192.168.1.20');
    expect(
      manual.phase.value,
      const LanSyncPairingFailed(LanSyncFailureReason.unknown),
    );
    expect(c.issueQrTicket().isPending, isTrue);
  });

  test('附近设备已离开时配对立即以“连不上”失败', () async {
    final a = await device('alpha');
    final c = wrap(() async => a.service);
    final events = <LanSyncUiEvent>[];
    c.events.listen(events.add);
    expect(await c.ready, isTrue);
    await c.pairWith('gone');
    final event = await eventIn<LanSyncPairingEvent>(events);
    expect(
      event.phase.value,
      const LanSyncPairingFailed(LanSyncFailureReason.unreachable),
    );
  });

  test('二维码：服务端没起来时先给占位码，起来后换上真码；关闭面板即作废', () async {
    final a = await device('alpha');
    final c = wrap(() async => a.service);
    expect(await c.ready, isTrue);
    // 没有配对、同步页没打开：服务端不运行，只能先给占位码。
    final placeholder = c.issueQrTicket();
    expect(placeholder.isPending, isTrue);
    expect(placeholder.payload, isEmpty);
    expect(placeholder.lifetime, const Duration(minutes: 2));
    c.attachPage();
    await waitUntil(() => c.qrTicket.value != null);
    expect(c.qrTicket.value!.payload, startsWith('jotsy-lan:v1:'));
    final direct = c.issueQrTicket();
    expect(direct.payload, startsWith('jotsy-lan:v1:'));
    expect(direct.isPending, isFalse);
    expect(c.qrTicket.value, direct);
    c.revokeQrTicket();
    expect(c.qrTicket.value, isNull);
    expect(a.service.qrTicket.value, isNull);
  });
}
