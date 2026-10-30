import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';

import 'sync_planner_fixtures.dart';

/// prefs 记录（规格 §2.2、§4.1）：标签顺序按列表合并，数据类功能开关只同步
/// “开启”；两者都不计入“以哪边为准”。
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
}
