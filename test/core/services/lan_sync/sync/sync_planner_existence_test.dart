import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan_side.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_planner.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_state_model.dart';

import 'sync_planner_fixtures.dart';

/// 只有一侧有的记录（规格 §4.2）、设置参与、删除保护与“以哪边为准”（§4.5）。
void main() {
  /// 各实体的一条记录（及它改过之后的样子）。
  final samples = <String, (SyncRecord, SyncRecord)>{
    'diary': (diaryRecord('d'), diaryRecord('d', title: 'edited')),
    'tag': (tagRecord('t'), tagRecord('t', color: 5)),
    'notebook': (notebookRecord('n'), notebookRecord('n', name: 'renamed')),
    'comment': (
      commentRecord('c', 'host'),
      commentRecord('c', 'host', content: 'edited', editedAt: 9000),
    ),
    'anniversary': (
      anniversaryRecord('a'),
      anniversaryRecord('a', title: 'edited'),
    ),
  };

  // 留言所属的日记，两侧都有。
  final host = diaryRecord('host');
  for (final entry in samples.entries) {
    final (original, edited) = entry.value;
    group('只有一侧有的 ${entry.key}', () {
      test('缺失一侧没有墓碑：新记录，复制过去', () {
        final a = PlanDevice('a')..putAll([host, original]);
        final b = PlanDevice('b')..put(host);
        a.commit(1000);
        b.commit(1000);
        final run = planBetween(a, b);
        final write = writeFor(run.plan, SyncSideRole.remote, original.key)!;
        expect(write.isInsert, isTrue);
        expect(write.record!.hashes, original.hashes);
      });

      test('缺失一侧的墓碑覆盖它：删除传播到在场一侧', () {
        final a = PlanDevice('a')..putAll([host, original]);
        final b = PlanDevice('b')..putAll([host, original]);
        a.commit(1000);
        b.commit(1000);
        b
          ..remove(original.key)
          ..commit(2000);
        final run = planBetween(a, b);
        final write = writeFor(run.plan, SyncSideRole.local, original.key)!;
        expect(write.isDelete, isTrue);
        expect(write.expected, original.hashes);
        expect(
          run.plan.remote.writes.where((w) => w.key == original.key),
          isEmpty,
        );
      });

      test('在场一侧删除之后又改过：保留并复制（改过的赢）', () {
        final a = PlanDevice('a')..putAll([host, original]);
        final b = PlanDevice('b')..putAll([host, original]);
        a.commit(1000);
        b.commit(1000);
        b
          ..remove(original.key)
          ..commit(2000);
        a
          ..put(edited)
          ..commit(3000);
        final run = planBetween(a, b);
        final write = writeFor(run.plan, SyncSideRole.remote, original.key)!;
        expect(write.isInsert, isTrue);
        expect(write.record!.hashes, edited.hashes);
      });
    });
  }

  test('墓碑认得在场一侧的旧版本（删除之前对方已改过）时同样删除', () {
    final a = PlanDevice('a')..put(diaryRecord('d'));
    final b = PlanDevice('b')..put(diaryRecord('d'));
    a.commit(1000);
    b.commit(1000);
    b
      ..put(diaryRecord('d', title: 'v2'))
      ..commit(2000)
      ..remove(diaryKey('d'))
      ..commit(3000);
    final run = planBetween(a, b);
    expect(
      writeFor(run.plan, SyncSideRole.local, diaryKey('d'))!.isDelete,
      isTrue,
    );
  });

  group('不参与的实体与设置', () {
    test('一侧不提供设置时 settings 整条跳过，不当作删除', () {
      final a = PlanDevice('a', settings: true)..put(settingsRecord({'k': 1}));
      final b = PlanDevice('b');
      a.commit(1000);
      b.commit(1000);
      final run = planBetween(a, b);
      expect(run.plan.isEmpty, isTrue);
    });

    test('两侧都开启时 settings 参与', () {
      final a = PlanDevice('a', settings: true)..put(settingsRecord({'k': 1}));
      final b = PlanDevice('b', settings: true)..put(settingsRecord({'k': 1}));
      a.commit(1000);
      b.commit(1000);
      a
        ..put(settingsRecord({'k': 2}))
        ..commit(2000);
      final run = planBetween(a, b);
      expect(
        writeFor(
          run.plan,
          SyncSideRole.remote,
          settingsKey,
        )!.record!.facets['k'],
        {'value': 2},
      );
    });

    test('一侧清单不覆盖某类实体时，那类记录不当作删除', () {
      final a = PlanDevice('a')..put(diaryRecord('d'));
      a.commit(1000);
      final remote = SyncPlanSideData(
        deviceId: 'b',
        manifest: SyncManifest(const <SyncKey, Map<String, String>>{}),
        entities: <SyncEntity>{SyncEntity.tag},
        allHistoryKnown: true,
        tombstones: <SyncKey, SyncTombstone>{
          diaryKey('d'): SyncTombstone(
            deletedAt: 1,
            known: <String, List<String>>{
              for (final facet in diaryRecord('d').hashes.entries)
                facet.key: <String>[facet.value],
            },
          ),
        },
      );
      final plan = planSync(
        local: a.fullSide(),
        remote: remote,
        options: const SyncPlanOptions(nowMillis: 0),
      );
      expect(plan.isEmpty, isTrue);
    });
  });

  group('删除保护', () {
    PlanRun deleting(int total, int deleted) {
      final a = PlanDevice('a');
      final b = PlanDevice('b');
      for (var i = 0; i < total; i++) {
        a.put(diaryRecord('d$i'));
        b.put(diaryRecord('d$i'));
      }
      a.commit(1000);
      b.commit(1000);
      for (var i = 0; i < deleted; i++) {
        b.remove(diaryKey('d$i'));
      }
      b.commit(2000);
      return planBetween(a, b);
    }

    test('超过 max(20, 10%) 时报告', () {
      final guards = deleting(100, 21).plan.confirmations.deletionGuards;
      expect(guards, hasLength(1));
      expect(guards.single.side, SyncSideRole.local);
      expect(guards.single.count, 21);
      expect(guards.single.total, 100);
    });

    test('不超过 20 篇不报告', () {
      expect(deleting(50, 20).plan.confirmations.deletionGuards, isEmpty);
    });

    test('超过 20 篇但不到 10% 不报告', () {
      expect(deleting(300, 30).plan.confirmations.deletionGuards, isEmpty);
    });
  });

  group('以哪边为准', () {
    (PlanDevice, PlanDevice) unrelated() {
      final a = PlanDevice('a')
        ..put(diaryRecord('d', title: 'mine', updatedAt: 2000));
      final b = PlanDevice('b')
        ..put(diaryRecord('d', title: 'theirs', updatedAt: 3000));
      a.commit(1);
      b.commit(1);
      a
        ..put(diaryRecord('d', title: 'mine2', updatedAt: 4000))
        ..commit(2);
      b
        ..put(diaryRecord('d', title: 'theirs2', updatedAt: 5000))
        ..commit(3);
      return (a, b);
    }

    test('不是首次同步、没有覆盖恢复时不生效：照常生成冲突副本', () {
      final (a, b) = unrelated();
      final plan = planBetween(a, b).plan;
      expect(plan.confirmations.sideChoiceConflicts, 0);
      expect(plan.conflictCopies, hasLength(1));
    });

    test('首次同步且有没有共同祖先的冲突时报告数量', () {
      final (a, b) = unrelated();
      final plan = planBetween(
        a,
        b,
        options: const SyncPlanOptions(nowMillis: 0, firstSyncWithPeer: true),
      ).plan;
      expect(plan.confirmations.sideChoiceConflicts, 1);
      expect(plan.conflictCopies, hasLength(1));
    });

    test('任一侧刚覆盖恢复时同样生效', () {
      final (a, b) = unrelated();
      b.restoredPending = true;
      expect(planBetween(a, b).plan.confirmations.sideChoiceConflicts, 1);
    });

    for (final (choice, winner) in [
      (SyncSideChoice.preferLocal, 'mine2'),
      (SyncSideChoice.preferRemote, 'theirs2'),
    ]) {
      test('$choice：直接取一侧，不生成副本', () {
        final (a, b) = unrelated();
        final plan = planBetween(
          a,
          b,
          options: SyncPlanOptions(
            nowMillis: 0,
            firstSyncWithPeer: true,
            sideChoice: choice,
          ),
        ).plan;
        expect(plan.conflictCopies, isEmpty);
        applyBoth(a, b, plan);
        final content =
            a.records[diaryKey('d')]!.facets[SyncFacet.content]! as Map;
        expect(content['title'], winner);
        expect(a.manifest.toJson(), b.manifest.toJson());
        expect(a.records.length, 1);
      });
    }

    test('选了一侧也不删除只有另一侧有的记录', () {
      final (a, b) = unrelated();
      b
        ..put(diaryRecord('only-b'))
        ..commit(4);
      final plan = planBetween(
        a,
        b,
        options: const SyncPlanOptions(
          nowMillis: 0,
          firstSyncWithPeer: true,
          sideChoice: SyncSideChoice.preferLocal,
        ),
      ).plan;
      expect(
        writeFor(plan, SyncSideRole.local, diaryKey('only-b'))!.isInsert,
        isTrue,
      );
      expect(plan.remote.writes.where((w) => w.isDelete), isEmpty);
    });

    test('新设备首次同步：空书架与对方的书架不算冲突，书架取并集', () {
      final a = PlanDevice('a')
        ..putAll([
          notebookRecord('n1'),
          notebookRecord('n2'),
          listRecord(SyncOrderListId.shelf, ['n2', 'n1']),
          listRecord(SyncOrderListId.templates, ['t1']),
          SyncRecord(const SyncKey(SyncEntity.template, 't1'), {
            SyncFacet.main: {'name': 't1', 'updatedAt': 1000},
          }),
        ])
        ..commit(1);
      final b = PlanDevice('b')
        ..putAll([
          listRecord(SyncOrderListId.shelf, []),
          listRecord(SyncOrderListId.templates, []),
        ])
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
        expect(plan.remote.writes, isEmpty, reason: '$choice');
        final shelf =
            writeFor(
                  plan,
                  SyncSideRole.local,
                  listKey(SyncOrderListId.shelf),
                )!.record!.facets[SyncFacet.items]!
                as Map;
        expect(shelf['ids'], ['n2', 'n1'], reason: '$choice');
      }
    });

    test('覆盖恢复后的真实冲突仍需确认，只按日记计数', () {
      final (a, b) = unrelated();
      a
        ..putAll([
          notebookRecord('n1'),
          listRecord(SyncOrderListId.shelf, ['n1']),
        ])
        ..commit(4);
      b
        ..putAll([
          notebookRecord('n2'),
          listRecord(SyncOrderListId.shelf, ['n2']),
        ])
        ..commit(4);
      b.restoredPending = true;
      final confirmations = planBetween(a, b).plan.confirmations;
      expect(confirmations.sideChoiceCounts, {SyncEntity.diary: 1});
      expect(confirmations.sideChoiceConflicts, 1);
    });
  });
}
