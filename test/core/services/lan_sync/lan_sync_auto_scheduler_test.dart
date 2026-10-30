import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_auto_scheduler.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_service_config.dart';

import 'lan_sync_fake_timers.dart';

/// 自动同步调度（假时钟）：谁发起、双向重试、节流、数据变化去抖、编辑中
/// 等待、忙时重试、后台取消。
void main() {
  late FakeTimers timers;
  late List<String> started;
  late Set<String> online;
  late bool editing;
  late bool busy;
  late Set<String> eligible;

  LanSyncAutoScheduler scheduler(String localId) => LanSyncAutoScheduler(
    localDeviceId: localId,
    canSync: (peer) => eligible.contains(peer) && !editing,
    isBusy: () => busy,
    isEditing: () => editing,
    onlinePeers: () => online,
    start: started.add,
    clock: timers.now,
    timer: timers.create,
  );

  setUp(() {
    timers = FakeTimers();
    started = [];
    online = {'peer-b'};
    editing = false;
    busy = false;
    eligible = {'peer-b'};
  });

  test('deviceId 较小的一方在对方上线时立即发起', () {
    scheduler('peer-a').peerOnline('peer-b');
    expect(started, ['peer-b']);
  });

  test('较大的一方等对方发起；等到了就不再发起', () {
    eligible = {'peer-a'};
    online = {'peer-a'};
    final auto = scheduler('peer-z')..peerOnline('peer-a');
    expect(started, isEmpty);
    timers.advance(const Duration(seconds: 5));
    auto.sessionArrived('peer-a');
    timers.advance(const Duration(seconds: 10));
    expect(started, isEmpty);
  });

  test('较大的一方没等到对方（对方方向被拦）：10 秒后自己发起', () {
    eligible = {'peer-a'};
    final auto = scheduler('peer-z')..peerOnline('peer-a');
    timers.advance(const Duration(seconds: 9));
    expect(started, isEmpty);
    timers.advance(const Duration(seconds: 1));
    expect(started, ['peer-a']);
    expect(auto, isNotNull);
  });

  test('节流：同一台 60 秒内只同步一次，之后补上', () {
    final auto = scheduler('peer-a')..peerOnline('peer-b');
    expect(started, ['peer-b']);
    timers.advance(const Duration(seconds: 10));
    auto.resumed();
    expect(started, ['peer-b']);
    timers.advance(const Duration(seconds: 49));
    expect(started, ['peer-b']);
    timers.advance(const Duration(seconds: 1));
    expect(started, ['peer-b', 'peer-b']);
  });

  test('对方发起的自动同步也计入节流', () {
    final auto = scheduler('peer-a')
      ..autoSessionRan('peer-b', timers.now())
      ..peerOnline('peer-b');
    expect(started, isEmpty);
    timers.advance(const Duration(seconds: 60));
    expect(started, ['peer-b']);
    expect(auto, isNotNull);
  });

  test('较大的一方被节流后到点仍先等对方发起，不与对方同时发起', () {
    eligible = {'peer-a'};
    online = {'peer-a'};
    final auto = scheduler('peer-z')
      ..autoSessionRan('peer-a', timers.now())
      ..peerOnline('peer-a');
    timers.advance(const Duration(seconds: 60));
    expect(started, isEmpty);
    auto.sessionArrived('peer-a');
    timers.advance(const Duration(seconds: 10));
    expect(started, isEmpty);
  });

  test('数据变化：去抖 20 秒，期间再变化重新计时', () {
    final auto = scheduler('peer-a')..localDataChanged();
    timers.advance(const Duration(seconds: 15));
    auto.localDataChanged();
    timers.advance(const Duration(seconds: 15));
    expect(started, isEmpty);
    timers.advance(const Duration(seconds: 5));
    expect(started, ['peer-b']);
  });

  test('编辑中不同步：编辑结束后再去抖 20 秒', () {
    editing = true;
    final auto = scheduler('peer-a')..localDataChanged();
    timers.advance(const Duration(seconds: 30));
    expect(started, isEmpty);
    editing = false;
    auto.editingChanged();
    timers.advance(const Duration(seconds: 19));
    expect(started, isEmpty);
    timers.advance(const Duration(seconds: 1));
    expect(started, ['peer-b']);
  });

  test('正忙：隔一会儿再试一次', () {
    busy = true;
    final auto = scheduler('peer-a')..peerOnline('peer-b');
    expect(started, isEmpty);
    busy = false;
    timers.advance(const LanSyncAutoTimings().busyRetry);
    expect(started, ['peer-b']);
    expect(auto, isNotNull);
  });

  test('切到后台：取消全部待定的同步', () {
    eligible = {'peer-a'};
    final auto = scheduler('peer-z')
      ..peerOnline('peer-a')
      ..localDataChanged()
      ..pause();
    expect(timers.pendingCount, 0);
    timers.advance(const Duration(minutes: 5));
    expect(started, isEmpty);
    expect(auto, isNotNull);
  });

  test('不能同步的设备（开关关了、离线）不触发', () {
    eligible = {};
    scheduler('peer-a')
      ..peerOnline('peer-b')
      ..resumed();
    timers.advance(const Duration(minutes: 5));
    expect(started, isEmpty);
  });
}
