import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_crypto.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_service.dart';

import 'lan_sync_e2e_harness.dart';
import 'lan_sync_fake_timers.dart';
import 'lan_sync_session_harness.dart';

/// 前台自动同步（真实服务 + 假时钟）：设备上线时 deviceId 较小的一方发起、
/// 60 秒节流、单向被拦时较大的一方 10 秒后自己发起、数据变化去抖、需要确认
/// 时标记并经“查看”转为手动同步。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeTimers timers;
  late E2eDevice small;
  late E2eDevice large;

  setUp(() async {
    EditingSessionRegistry.instance.debugReset();
    timers = FakeTimers();
    final a = await E2eDevice.create('alpha', timers);
    final b = await E2eDevice.create('beta', timers);
    await pairDevices(a, b);
    final aSmaller = a.id.compareTo(b.id) < 0;
    small = aSmaller ? a : b;
    large = aSmaller ? b : a;
    await small.service.setAutoSync(true);
    await large.service.setAutoSync(true);
  });

  tearDown(() async {
    await small.dispose();
    await large.dispose();
  });

  /// [device] 的在线表里 [other] 先下线再上线（触发“设备上线”）。
  void comesOnline(E2eDevice device, E2eDevice other) {
    device.discovery.lose(other.id);
    device.see(other);
  }

  Future<LanSyncSessionEnded> nthSession(E2eDevice device, int n) async {
    await waitUntil(() => device.endedSessions.length >= n);
    return device.endedSessions[n - 1];
  }

  test('对方上线：较小的一方发起；写入了变化有提示；60 秒内不再同步', () async {
    await seedDiary(large.data.db, 'from-large', title: 'hi');
    comesOnline(small, large);
    final first = await nthSession(small, 1);
    expect(first.result.automatic, isTrue);
    expect(first.result.role, LanSyncRole.initiator);
    expect(first.result.failure, isNull);
    final notice = await small.event<LanSyncAutoSyncApplied>();
    expect(notice.diaries, 1);
    expect(small.peerState(large)!.history.single.automatic, isTrue);
    await nthSession(large, 1);
    expect(large.events.whereType<LanSyncAutoSyncApplied>(), isEmpty);

    comesOnline(small, large);
    timers.advance(const Duration(seconds: 30));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(small.endedSessions, hasLength(1));
    timers.advance(const Duration(seconds: 30));
    final second = await nthSession(small, 2);
    expect(second.result.failure, isNull);
    expect(second.result.received.isEmpty, isTrue);
    expect(small.events.whereType<LanSyncAutoSyncApplied>(), hasLength(1));
  });

  test('不可被发现的一方只听不发：仍看到对方在线，10 秒后自己发起自动同步', () async {
    await large.service.setDiscoverable(false);
    await waitUntil(() => !large.discovery.advertise);
    expect(large.discovery.running, isTrue);
    // 较小的一方看不到它（没有信标），不会发起。
    comesOnline(small, large);
    expect(small.peerState(large)!.online, isFalse);
    // 它照样收到对方的信标：对方显示在线，“设备上线”照样触发。
    comesOnline(large, small);
    expect(large.peerState(small)!.online, isTrue);
    timers.advance(const Duration(seconds: 10));
    final auto = await nthSession(large, 1);
    expect(auto.result.role, LanSyncRole.initiator);
    expect(auto.result.automatic, isTrue);
    expect(auto.result.failure, isNull);
    expect(small.endedSessions.single.result.role, LanSyncRole.responder);
  });

  test('较小一方的方向被拦：较大的一方等 10 秒后自己发起', () async {
    small.blockOutgoing = true;
    comesOnline(large, small);
    comesOnline(small, large);
    final blocked = await nthSession(small, 1);
    expect(blocked.result.failure, LanSyncFailure.unreachable);
    expect(small.peerState(large)!.history, isEmpty, reason: '自动失败不记');
    expect(large.endedSessions, isEmpty);
    timers.advance(const Duration(seconds: 10));
    final retried = await nthSession(large, 1);
    expect(retried.result.role, LanSyncRole.initiator);
    expect(retried.result.automatic, isTrue);
    expect(retried.result.failure, isNull);
  });

  test('本机数据变化：去抖 20 秒后自动同步，对方收到提示', () async {
    await small.service.syncNow(large.id);
    await waitUntil(() => large.endedSessions.isNotEmpty);
    final before = timers.pendingCount;
    await seedDiary(small.data.db, 'new', title: 'new');
    await waitUntil(() => timers.pendingCount > before);
    timers.advance(const Duration(seconds: 19));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(small.endedSessions, hasLength(1));
    timers.advance(const Duration(seconds: 1));
    final auto = await nthSession(small, 2);
    expect(auto.result.automatic, isTrue);
    final notice = await large.event<LanSyncAutoSyncApplied>();
    expect(notice.diaries, 1);
    expect(await diaryIds(large.data), {'new'});
  });

  test('自动同步需要确认：两边标记“需要确认”，查看后转为手动同步', () async {
    await seedDiary(small.data.db, 'same', title: 'mine');
    await seedDiary(large.data.db, 'same', title: 'theirs');
    comesOnline(small, large);
    await small.event<LanSyncAttentionNeeded>();
    await large.event<LanSyncAttentionNeeded>();
    expect(small.peerState(large)!.needsAttention, isTrue);
    expect(large.peerState(small)!.needsAttention, isTrue);
    expect(await diaryIds(large.data), {'same'});

    small.answerWith();
    small.service.reviewPendingConfirmation(large.id);
    final manual = await small.event<LanSyncSessionEnded>(
      (e) => !e.result.automatic,
    );
    expect(manual.result.failure, isNull);
    expect(manual.result.conflictCopies, hasLength(1));
    expect(small.peerState(large)!.needsAttention, isFalse);
    await waitUntil(() => !large.peerState(small)!.needsAttention);
  });
}
