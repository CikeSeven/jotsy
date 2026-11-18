import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';

import 'sync_planner_fixtures.dart';

/// prefs 记录（规格 §2.2、§4.1）：标签顺序按列表合并，数据类功能开关只同步
/// “开启”，心情符号没有共同祖先时改过的一侧胜出；都不计入“以哪边为准”。
void main() {
  Object? orderOf(PlanDevice device) =>
      (device.records[prefsKey]!.facets[SyncPrefsFacet.tagOrder]!
          as Map)['value'];

  bool featureOf(PlanDevice device, String name) =>
      (device.records[prefsKey]!.facets[SyncPrefsFacet.feature(name)]!
              as Map)['on']!
          as bool;

  test('新设备首次同步：不问以哪边为准，标签顺序取并集，开着的功能两边都开', () {
    final a = PlanDevice('a')
      ..putAll([
        tagRecord('work'),
        tagRecord('life'),
        prefsRecord(
          tagOrder: ['life', 'work'],
          features: {'comments': true, 'notebooks': true},
        ),
      ])
      ..commit(1);
    final b = PlanDevice('b')
      ..put(prefsRecord(features: {'comments': false, 'notebooks': false}))
      ..commit(1);
    for (final choice in SyncSideChoice.values) {
      final plan = planBetween(
        b,
        a,
        options: SyncPlanOptions(
          nowMillis: 0,
          firstSyncWithPeer: true,
          sideChoice: choice,
        ),
      ).plan;
      expect(plan.confirmations.sideChoiceNeeded, isFalse, reason: '$choice');
      expect(writeFor(plan, SyncSideRole.remote, prefsKey), isNull);
    }
    final plan = planBetween(
      b,
      a,
      options: const SyncPlanOptions(nowMillis: 0, firstSyncWithPeer: true),
    ).plan;
    applyBoth(b, a, plan);
    expect(orderOf(b), ['life', 'work']);
    expect(featureOf(b, 'comments'), isTrue);
    expect(featureOf(b, 'notebooks'), isTrue);
    expect(b.manifest.toJson(), a.manifest.toJson());
  });

  group('只同步开启', () {
    (PlanDevice, PlanDevice) synced() {
      final a = PlanDevice('a')
        ..put(prefsRecord(features: {'comments': true}))
        ..commit(1000);
      final b = PlanDevice('b')
        ..put(prefsRecord(features: {'comments': true}))
        ..commit(1000);
      return (a, b);
    }

    test('一台关掉：另一台不跟着关，之后再同步也不反复写', () {
      final (a, b) = synced();
      a
        ..put(prefsRecord(features: {'comments': false}))
        ..commit(2000);
      for (final (local, remote) in [(a, b), (b, a)]) {
        final plan = planBetween(local, remote).plan;
        expect(plan.isEmpty, isTrue);
        applyBoth(local, remote, plan);
      }
      expect(featureOf(a, 'comments'), isFalse);
      expect(featureOf(b, 'comments'), isTrue);
      // 再来几轮仍然什么都不写。
      for (var round = 0; round < 3; round++) {
        expect(planBetween(a, b).plan.isEmpty, isTrue);
      }
    });

    test('关掉的那台之后又被别处重新打开：照常同步开启', () {
      final (a, b) = synced();
      a
        ..put(prefsRecord(features: {'comments': false}))
        ..commit(2000);
      applyBoth(a, b, planBetween(a, b).plan);
      // b 关掉再打开（确立时间更晚）。
      b
        ..put(prefsRecord(features: {'comments': false}))
        ..commit(3000)
        ..put(prefsRecord(features: {'comments': true}))
        ..commit(4000);
      final plan = planBetween(a, b).plan;
      final write = writeFor(plan, SyncSideRole.local, prefsKey)!;
      expect(write.record!.facets[SyncPrefsFacet.feature('comments')], {
        'on': true,
      });
      applyBoth(a, b, plan);
      expect(featureOf(a, 'comments'), isTrue);
    });

    test('一台打开、另一台没动：打开传过去', () {
      final a = PlanDevice('a')
        ..put(prefsRecord(features: {'anniversaries': false}))
        ..commit(1000);
      final b = PlanDevice('b')
        ..put(prefsRecord(features: {'anniversaries': false}))
        ..commit(1000);
      b
        ..put(prefsRecord(features: {'anniversaries': true}))
        ..commit(2000);
      final plan = planBetween(a, b).plan;
      applyBoth(a, b, plan);
      expect(featureOf(a, 'anniversaries'), isTrue);
      expect(a.manifest.toJson(), b.manifest.toJson());
    });

    test('待办：打开传过去；之后一台关掉，另一台不跟着关', () {
      final a = PlanDevice('a')
        ..put(prefsRecord(features: {'todos': false}))
        ..commit(1000);
      final b = PlanDevice('b')
        ..put(prefsRecord(features: {'todos': false}))
        ..commit(1000);
      b
        ..put(prefsRecord(features: {'todos': true}))
        ..commit(2000);
      final first = planBetween(a, b).plan;
      a.applyAndCommit(first.local, 2500);
      b.applyAndCommit(first.remote, 2500);
      expect(featureOf(a, 'todos'), isTrue);

      a
        ..put(prefsRecord(features: {'todos': false}))
        ..commit(3000);
      for (final (local, remote) in [(a, b), (b, a)]) {
        final plan = planBetween(local, remote).plan;
        expect(plan.isEmpty, isTrue);
        applyBoth(local, remote, plan);
      }
      expect(featureOf(a, 'todos'), isFalse);
      expect(featureOf(b, 'todos'), isTrue);
    });
  });

  test('标签顺序三方合并：一边拖动、一边新建标签，两者都保留', () {
    final base = [
      tagRecord('a1'),
      tagRecord('a2'),
      tagRecord('a3'),
      prefsRecord(tagOrder: ['a1', 'a2', 'a3']),
    ];
    final a = PlanDevice('a')
      ..putAll(base)
      ..commit(1000);
    final b = PlanDevice('b')
      ..putAll(base)
      ..commit(1000);
    a
      ..put(prefsRecord(tagOrder: ['a3', 'a1', 'a2']))
      ..commit(2000);
    b
      ..put(tagRecord('new'))
      ..put(prefsRecord(tagOrder: ['a1', 'new', 'a2', 'a3']))
      ..commit(2000);
    final plan = planBetween(a, b).plan;
    applyBoth(a, b, plan);
    expect(orderOf(a), ['a3', 'a1', 'new', 'a2']);
    expect(a.manifest.toJson(), b.manifest.toJson());
  });

  group('心情符号', () {
    const custom = ['😡', '😢', '😞', '😕', '😐', '🙂', '😊', '😄', '😀', '🥰'];
    const other = ['💀', '😢', '😞', '😕', '😐', '🙂', '😊', '😄', '😀', '🤩'];

    Object? moodOf(PlanDevice device) =>
        (device.records[prefsKey]!.facets[SyncPrefsFacet.moodOptions]!
            as Map)['value'];

    test('首次同步（含刚升级、两侧都没有历史）：改过的一侧胜出，与 deviceId 无关', () {
      // deviceId 平手时 b 胜：把改过的放在 a 和 b 上各验一次。
      for (final customOn in ['a', 'b']) {
        final a = PlanDevice('a')
          ..put(prefsRecord(moodOptions: customOn == 'a' ? custom : null))
          ..commit(1);
        final b = PlanDevice('b')
          ..put(prefsRecord(moodOptions: customOn == 'b' ? custom : null))
          ..commit(1);
        for (final choice in SyncSideChoice.values) {
          final plan = planBetween(
            a,
            b,
            options: SyncPlanOptions(
              nowMillis: 0,
              firstSyncWithPeer: true,
              sideChoice: choice,
            ),
          ).plan;
          expect(plan.confirmations.sideChoiceNeeded, isFalse);
        }
        final plan = planBetween(a, b).plan;
        applyBoth(a, b, plan);
        expect(moodOf(a), custom, reason: 'custom on $customOn');
        expect(moodOf(b), custom, reason: 'custom on $customOn');
      }
    });

    test('同步过之后一台恢复默认：默认传过去（谁发起都一样）', () {
      for (final resetFirst in [true, false]) {
        final a = PlanDevice('a')
          ..put(prefsRecord(moodOptions: custom))
          ..commit(1000);
        final b = PlanDevice('b')
          ..put(prefsRecord(moodOptions: custom))
          ..commit(1000);
        a
          ..put(prefsRecord(moodOptions: null))
          ..commit(2000);
        final (local, remote) = resetFirst ? (a, b) : (b, a);
        applyBoth(local, remote, planBetween(local, remote).plan);
        expect(moodOf(a), isNull);
        expect(moodOf(b), isNull);
      }
    });

    test('心情颜色同理：首次同步改过的一侧胜出，与 deviceId 无关', () {
      const colors = '{"1":"#FF112233"}';
      Object? colorsOf(PlanDevice device) =>
          (device.records[prefsKey]!.facets[SyncPrefsFacet.moodColors]!
              as Map)['value'];
      for (final customOn in ['a', 'b']) {
        final a = PlanDevice('a')
          ..put(prefsRecord(moodColors: customOn == 'a' ? colors : null))
          ..commit(1);
        final b = PlanDevice('b')
          ..put(prefsRecord(moodColors: customOn == 'b' ? colors : null))
          ..commit(1);
        final plan = planBetween(
          a,
          b,
          options: const SyncPlanOptions(nowMillis: 0, firstSyncWithPeer: true),
        ).plan;
        expect(plan.confirmations.sideChoiceNeeded, isFalse);
        applyBoth(a, b, plan);
        expect(colorsOf(a), colors, reason: 'custom on $customOn');
        expect(colorsOf(b), colors, reason: 'custom on $customOn');
      }
    });

    test('两侧都改过、没有共同祖先：按变化时间取一侧，两边收敛', () {
      final a = PlanDevice('a')
        ..put(prefsRecord(moodOptions: null))
        ..commit(1000)
        ..put(prefsRecord(moodOptions: custom))
        ..commit(3000);
      final b = PlanDevice('b')
        ..put(prefsRecord(moodOptions: other))
        ..commit(2000);
      final plan = planBetween(b, a).plan;
      applyBoth(b, a, plan);
      expect(moodOf(a), custom, reason: 'a 改得更晚');
      expect(a.manifest.toJson(), b.manifest.toJson());
    });
  });
}
