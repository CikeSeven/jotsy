import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/core/services/lan_sync/lan_sync_service.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lan_sync_e2e_harness.dart';
import 'lan_sync_fake_timers.dart';
import 'lan_sync_session_harness.dart';

/// 两到三个真实服务在回环上同步（真实握手、信道、规划与写入）：首次同步与
/// 以哪边为准、分面合并与冲突副本、删除传播与删除保护、三台传递、只传缺的
/// 媒体、中途断线后重试、设置、编辑中、覆盖恢复。
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late FakeTimers timers;
  final devices = <E2eDevice>[];

  Future<E2eDevice> device(String name, {SettingsService? settings}) async {
    final created = await E2eDevice.create(name, timers, settings: settings);
    devices.add(created);
    return created;
  }

  Future<(E2eDevice, E2eDevice)> pairedPair() async {
    final a = await device('alpha');
    final b = await device('beta');
    await pairDevices(a, b);
    return (a, b);
  }

  Future<LanSyncSessionResult> sync(E2eDevice from, E2eDevice to) async {
    final result = await from.service.syncNow(to.id);
    expect(result, isNotNull);
    return result!;
  }

  Future<void> expectConverged(E2eDevice x, E2eDevice y) async {
    expect(await x.data.canonical(), await y.data.canonical());
    final again = await sync(x, y);
    expect(again.failure, isNull);
    expect(again.received.isEmpty && again.sent.isEmpty, isTrue);
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

  test('首次同步：以哪边为准（保留两份），记录首次同步', () async {
    final (a, b) = await pairedPair();
    await seedDiary(a.data.db, 'a1', title: 'A1');
    await seedDiary(b.data.db, 'b1', title: 'B1');
    await seedDiary(a.data.db, 'same', title: 'mine', updated: 1700000500);
    await seedDiary(b.data.db, 'same', title: 'theirs', updated: 1700000400);
    a.answerWith();
    final result = await sync(a, b);
    expect(result.failure, isNull);
    final asked = await a.event<LanSyncConfirmationRequested>();
    expect((asked.request as LanSyncSideChoiceRequest).conflicts, 1);
    expect(result.conflictCopies, hasLength(1));
    expect(result.conflictCopies.single.title, contains('(copy · beta)'));
    final ended = await a.event<LanSyncSessionEnded>();
    expect(ended.firstSync, isTrue);
    final history = a.peerState(b)!.history.single;
    expect(history.firstSync, isTrue);
    expect(history.conflictCopies, 1);
    expect(history.receivedDiaries, result.received.diaries);
    expect(b.peerState(a)!.history, hasLength(1));
    expect(b.peerState(a)!.device.lastSyncAt, isNotNull);
    await expectConverged(a, b);
    expect(a.peerState(b)!.history.first.firstSync, isFalse);
  });

  test('两边改了不同的分面合并；同一篇都改了正文得到一份冲突副本', () async {
    final (a, b) = await pairedPair();
    await seedDiary(a.data.db, 'x', title: 'X');
    await seedDiary(a.data.db, 'y', title: 'Y');
    await sync(a, b);
    await a.data.db.customStatement(
      "UPDATE diaries SET is_pinned = 1 WHERE diary_id = 'x'",
    );
    await setTitle(b.data.db, 'x', 'X by B', updated: 1800000000);
    await sync(b, a);
    final x = await (a.data.db.select(
      a.data.db.diaries,
    )..where((t) => t.diaryId.equals('x'))).getSingle();
    expect(x.isPinned, isTrue);
    expect(x.title, 'X by B');

    await setTitle(a.data.db, 'y', 'Y from A', updated: 1800000100);
    await setTitle(b.data.db, 'y', 'Y from B', updated: 1800000200);
    final result = await sync(a, b);
    expect(result.conflictCopies, hasLength(1));
    // 败方是发起方本机：后缀写本机的设备名。
    expect(result.conflictCopies.single.title, 'Y from A (copy · alpha)');
    expect(await diaryIds(a.data), hasLength(3));
    await expectConverged(a, b);
  });

  test('清空回收站：删除传播；超过阈值时删除保护先问', () async {
    final (a, b) = await pairedPair();
    for (var i = 0; i < 26; i++) {
      await seedDiary(a.data.db, 'bulk-$i', title: 'bulk $i');
    }
    await sync(a, b);
    await b.data.db.hardDeleteDiary('bulk-0');
    var result = await sync(a, b);
    expect(result.received.deleted, 1);
    expect(await diaryIds(a.data), hasLength(25));

    for (var i = 1; i < 26; i++) {
      await b.data.db.hardDeleteDiary('bulk-$i');
    }
    a.answerWith();
    result = await sync(a, b);
    final asked = await a.event<LanSyncConfirmationRequested>(
      (e) => e.request is LanSyncDeletionGuardRequest,
    );
    final guard = asked.request as LanSyncDeletionGuardRequest;
    expect(guard.count, 25);
    expect(guard.onLocalSide, isTrue);
    expect(result.received.deleted, 25);
    expect(await diaryIds(a.data), isEmpty);
    await expectConverged(a, b);
  });

  test('三台设备：A 的改动经 B 传到 C，C 的改动再经 B 回到 A', () async {
    final a = await device('alpha');
    final b = await device('beta');
    final c = await device('gamma');
    await pairDevices(a, b);
    await pairDevices(b, c);
    await seedDiary(a.data.db, 'from-a', title: 'hello');
    await sync(a, b);
    await sync(b, c);
    expect(await diaryIds(c.data), {'from-a'});
    await setTitle(c.data.db, 'from-a', 'edited on C', updated: 1800000000);
    await sync(c, b);
    await sync(a, b);
    expect(await a.data.canonical(), await c.data.canonical());
    final row = await a.data.db.select(a.data.db.diaries).getSingle();
    expect(row.title, 'edited on C');
  });

  test('媒体：接收方已有同样内容的不传，之后只传新增的', () async {
    final (a, b) = await pairedPair();
    final p1 = await a.data.writeMedia('diary_images/m/p1.jpg', [1, 1, 1]);
    final p2 = await a.data.writeMedia('diary_images/m/p2.jpg', [2, 2, 2]);
    await b.data.writeMedia('diary_images/m/p2.jpg', [2, 2, 2]);
    await seedDiary(a.data.db, 'd1', content: docWithImage('one', p1));
    await seedDiary(a.data.db, 'd2', content: docWithImage('two', p2));
    var result = await sync(a, b);
    expect(result.transferredFiles, 1);
    expect(result.sent.mediaFiles, 1);
    final p3 = await a.data.writeMedia('diary_images/m/p3.jpg', [3, 3, 3]);
    await seedDiary(a.data.db, 'd3', content: docWithImage('three', p3));
    result = await sync(a, b);
    expect(result.transferredFiles, 1);
    expect(
      await File(b.data.mediaPath('diary_images/m/p3.jpg')).readAsBytes(),
      [3, 3, 3],
    );
    await expectConverged(a, b);
  });

  test('对方离线：按上次连上的地址照样同步', () async {
    final (a, b) = await pairedPair();
    await seedDiary(b.data.db, 'b1', title: 'B1');
    a.discovery.lose(b.id);
    expect(a.peerState(b)!.online, isFalse);
    final result = await sync(a, b);
    expect(result.failure, isNull);
    expect(await diaryIds(a.data), {'b1'});
  });

  test('连接被接下后立刻断开、对方一个字节都没发：按“连不上”结束', () async {
    final (a, b) = await pairedPair();
    final sink = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(sink.close);
    sink.listen((socket) => socket.destroy());
    a.redirectOutgoing = (sink.address.address, sink.port);
    final result = await sync(a, b);
    expect(result.failure, LanSyncFailure.unreachable);
  });

  test('传媒体时断线：两边都不写，暂存区清空，重试收敛', () async {
    final (a, b) = await pairedPair();
    final big = await a.data.writeMedia(
      'diary_images/m/big.bin',
      List<int>.generate(512 * 1024, (i) => Random(1).nextInt(256)),
    );
    await seedDiary(a.data.db, 'big', content: docWithImage('big', big));
    void kill() {
      if (a.peerState(b)?.session?.stage == LanSyncStage.transferring) {
        a.lastSocket?.destroy();
      }
    }

    a.service.state.addListener(kill);
    final result = await sync(a, b);
    a.service.state.removeListener(kill);
    expect(result.failure, LanSyncFailure.connectionLost);
    await waitUntil(() => b.peerState(a)?.session == null);
    expect(await diaryIds(b.data), isEmpty);
    expect(leftoverStaging(b.data), isEmpty);
    final retry = await sync(a, b);
    expect(retry.failure, isNull);
    await expectConverged(a, b);
  });

  test('响应方写入时断线：只有响应方写了，重试收敛', () async {
    final (a, b) = await pairedPair();
    await seedDiary(a.data.db, 'a1', title: 'A1');
    await seedDiary(b.data.db, 'b1', title: 'B1');
    void kill() {
      if (b.peerState(a)?.session?.stage == LanSyncStage.merging) {
        a.lastSocket?.destroy();
      }
    }

    b.service.state.addListener(kill);
    final result = await sync(a, b);
    expect(result.failure, LanSyncFailure.connectionLost);
    await waitUntil(() => b.peerState(a)?.session == null);
    b.service.state.removeListener(kill);
    expect(await diaryIds(b.data), {'a1', 'b1'});
    expect(await diaryIds(a.data), {'a1'});
    expect(b.peerState(a)!.history.single.failure, isNotNull);
    await sync(a, b);
    await expectConverged(a, b);
  });

  test('设置：只有两边都开启“同步设置”才同步', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // 同一进程里两个 SettingsService 共用 SharedPreferences；themeMode 取自
    // 各自的通知器，可以在两边不同——用它验证设置是否参与。
    final settingsA = await SettingsService.create();
    final settingsB = await SettingsService.create();
    await settingsA.setThemeMode(ThemeMode.dark);
    expect(settingsB.themeModeNotifier.value, isNot(ThemeMode.dark));
    final a = await device('alpha', settings: settingsA);
    final b = await device('beta', settings: settingsB);
    await pairDevices(a, b);
    await a.service.setSyncSettings(true);
    var result = await sync(a, b);
    expect(result.settingsIncluded, isFalse);
    expect(
      settingsA.themeModeNotifier.value,
      isNot(settingsB.themeModeNotifier.value),
    );
    await b.service.setSyncSettings(true);
    result = await sync(a, b);
    expect(result.failure, isNull);
    expect(result.settingsIncluded, isTrue);
    expect(
      settingsA.themeModeNotifier.value,
      settingsB.themeModeNotifier.value,
    );
  });

  test('编辑中：响应方回 busy；本机编辑时手动同步不开始', () async {
    final (a, b) = await pairedPair();
    await seedDiary(a.data.db, 'a1', title: 'A1');
    b.editing = true;
    var result = await sync(a, b);
    expect(result.failure, LanSyncFailure.busy);
    expect(await diaryIds(b.data), isEmpty);
    expect(a.peerState(b)!.history.single.failure, LanSyncFailure.busy);
    b.editing = false;
    a.editing = true;
    result = await sync(a, b);
    expect(result.failure, LanSyncFailure.localEditing);
    expect(a.peerState(b)!.history, hasLength(1));
  });

  test('覆盖恢复之后：下一次同步走以哪边为准，成功后标记清除', () async {
    final (a, b) = await pairedPair();
    await seedDiary(a.data.db, 'x', title: 'X');
    await sync(a, b);
    await a.service.noteDataReplacedByRestore();
    expect(a.peerState(b)!.device.restoredPending, isTrue);
    await setTitle(a.data.db, 'x', 'restored', updated: 1800000000);
    await setTitle(b.data.db, 'x', 'edited on B', updated: 1800000100);
    a.answerWith(side: SyncSideChoice.preferLocal);
    final result = await sync(a, b);
    expect(result.failure, isNull);
    await a.event<LanSyncConfirmationRequested>(
      (e) => e.request is LanSyncSideChoiceRequest,
    );
    expect(result.conflictCopies, isEmpty);
    final row = await b.data.db.select(b.data.db.diaries).getSingle();
    expect(row.title, 'restored');
    expect(a.peerState(b)!.device.restoredPending, isFalse);
  });
}
