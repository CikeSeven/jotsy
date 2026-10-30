import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_state_model.dart';

import 'sync_planner_fixtures.dart';

/// 多台设备之间的定向收敛场景（随机模拟见 `sync_planner_simulation_test`）。
void main() {
  /// 发起同步并让两侧按生产流程写入后折叠。[inherit] 为 false 时不做历史
  /// 时间继承（[SyncSidePlan.historySeenAt]），只用于展示没有它时的问题。
  void sync(PlanDevice l, PlanDevice r, int now, {bool inherit = true}) {
    final run = planBetween(l, r, options: SyncPlanOptions(nowMillis: now));
    if (inherit) {
      l.applyAndCommit(run.plan.local, now);
      r.applyAndCommit(run.plan.remote, now);
    } else {
      applyBoth(l, r, run.plan);
      l.commit(now);
      r.commit(now);
    }
  }

  group('来回改过的值（两个值都在彼此历史里）', () {
    // 最小复现（由收敛模拟 seed 160 化简）：四台设备，pin 分面在 true /
    // false 之间来回过；按固定顺序两两同步。
    List<PlanDevice> devices() {
      final key = diaryKey('x');
      final on = diaryRecord('x', pinned: true);
      final off = diaryRecord('x');
      PlanDevice device(String name, SyncRecord record, String other, int at) {
        final d = PlanDevice(name)..put(record);
        d.commit(1);
        d.state.history[key] = <String, List<SyncHistoryEntry>>{
          SyncFacet.pin: <SyncHistoryEntry>[
            SyncHistoryEntry(hash: other, seenAt: at),
          ],
        };
        return d;
      }

      final hOn = on.hashes[SyncFacet.pin]!;
      final hOff = off.hashes[SyncFacet.pin]!;
      return [
        device('a', on, hOff, 996),
        device('b', on, hOff, 1000),
        device('c', off, hOn, 994),
        device('d', off, hOn, 1005),
      ];
    }

    List<bool> run(List<PlanDevice> all, int rounds, {required bool inherit}) {
      final [a, b, c, d] = all;
      var now = 10000;
      for (var round = 0; round < rounds; round++) {
        for (final (l, r) in [(a, c), (a, d), (b, d), (c, d), (a, b), (b, c)]) {
          sync(l, r, now += 1000, inherit: inherit);
        }
      }
      return [
        for (final device in all)
          (device.records[diaryKey('x')]!.facets[SyncFacet.pin]!
                  as Map)['pinned']
              as bool,
      ];
    }

    test('没有历史时间继承时按采纳顺序无休止地翻转（说明继承的必要）', () {
      final all = devices();
      final first = run(all, 1, inherit: false);
      final second = run(all, 1, inherit: false);
      expect(first.toSet(), hasLength(2));
      expect(second.toSet(), hasLength(2));
      expect(second, isNot(first));
    });

    test('有历史时间继承时一轮内收敛并保持', () {
      final all = devices();
      final first = run(all, 1, inherit: true);
      expect(first.toSet(), hasLength(1));
      expect(run(all, 2, inherit: true), first);
    });

    test('两台设备之间改回旧值：后改的一侧胜出', () {
      final a = PlanDevice('a')..put(diaryRecord('x'));
      final b = PlanDevice('b')..put(diaryRecord('x'));
      a.commit(1000);
      b.commit(1000);
      a
        ..put(diaryRecord('x', pinned: true))
        ..commit(2000);
      sync(a, b, 3000);
      b
        ..put(diaryRecord('x'))
        ..commit(4000);
      sync(a, b, 5000);
      expect(
        (a.records[diaryKey('x')]!.facets[SyncFacet.pin]! as Map)['pinned'],
        false,
      );
    });
  });

  test('删除沿 A → B → C 传播', () {
    final devices = [
      for (final n in ['a', 'b', 'c']) PlanDevice(n),
    ];
    for (final d in devices) {
      d
        ..putAll([diaryRecord('d'), commentRecord('c', 'd')])
        ..commit(1000);
    }
    final [a, b, c] = devices;
    a
      ..remove(diaryKey('d'))
      ..remove(commentKey('c'))
      ..commit(2000);
    sync(a, b, 3000);
    expect(b.records.containsKey(diaryKey('d')), isFalse);
    sync(b, c, 4000);
    expect(c.records, isEmpty);
    expect(a.manifest.toJson(), c.manifest.toJson());
  });

  test('冲突副本经第三台设备传开后只有一份，且仍只在败方的私密日记本里', () {
    final base = [
      diaryRecord('d'),
      notebookRecord('h', visibility: 'locked'),
      memberRecord('h', 'd'),
      listRecord('book:h', ['d']),
      listRecord('shelf', ['h']),
    ];
    final devices = [
      for (final n in ['a', 'b', 'c']) PlanDevice(n),
    ];
    for (final d in devices) {
      d
        ..putAll(base)
        ..commit(1000);
    }
    final [a, b, c] = devices;
    a
      ..put(diaryRecord('d', title: 'a', updatedAt: 2000))
      ..commit(2000);
    b
      ..put(diaryRecord('d', title: 'b', updatedAt: 3000))
      ..commit(2000);
    // b 先把版本 b 给了 c；之后 a、c 冲突并生成副本，再与 b 同步。
    sync(b, c, 4000);
    sync(a, c, 5000);
    sync(a, b, 6000);
    sync(b, c, 7000);
    expect(a.manifest.toJson(), b.manifest.toJson());
    expect(b.manifest.toJson(), c.manifest.toJson());
    final diaries = a.records.keys
        .where((k) => k.entity == SyncEntity.diary)
        .toList();
    expect(diaries, hasLength(2));
    final copy = diaries.firstWhere((k) => k.id != 'd');
    expect(a.records.containsKey(memberKey('h', copy.id)), isTrue);
  });
}
