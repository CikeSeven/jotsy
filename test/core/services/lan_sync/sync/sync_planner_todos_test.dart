import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';

import 'sync_planner_fixtures.dart';

/// 待办与清单的从属（规格 §4.3）：日记关联的置 null 与复活后恢复、清单不在
/// 时移到收集箱、复活的清单带回被一并删除的待办。
void main() {
  /// 两侧共有：日记 d、清单 l，待办 t1 在 l 里并关联 d，待办 t2 在收集箱。
  List<SyncRecord> base() => [
    diaryRecord('d'),
    todoListRecord('l'),
    todoRecord('t1', listId: 'l', linkedDiaryId: 'd'),
    todoRecord('t2'),
  ];

  (PlanDevice, PlanDevice) both() {
    final a = PlanDevice('a')..putAll(base());
    final b = PlanDevice('b')..putAll(base());
    a.commit(1000);
    b.commit(1000);
    return (a, b);
  }

  /// 应用自己彻底删除日记 d：清掉待办的日记关联（`hardDeleteDiary`）。
  void hardDeleteD(PlanDevice device, int at) {
    device
      ..remove(diaryKey('d'))
      ..put(todoRecord('t1', listId: 'l'))
      ..commit(at);
  }

  /// 应用自己删除清单 l：连同其中的待办一起删。
  void deleteListL(PlanDevice device, int at) {
    device
      ..remove(todoListKey('l'))
      ..remove(todoKey('t1'))
      ..commit(at);
  }

  Map<Object?, Object?> mainOf(SyncRecord record) =>
      record.facets[SyncFacet.main]! as Map<Object?, Object?>;

  void expectConverged(PlanDevice a, PlanDevice b, SyncPlan plan) {
    applyBoth(a, b, plan);
    expect(a.manifest.toJson(), b.manifest.toJson());
  }

  test('日记删除传播时，另一侧改过的待办保留、日记关联置 null', () {
    final (a, b) = both();
    hardDeleteD(b, 2000);
    // a 在删除之前（b 不知道）改了待办——不是改日记，不复活日记。
    a
      ..put(todoRecord('t1', title: 'edited', listId: 'l', linkedDiaryId: 'd'))
      ..commit(3000);
    final plan = planBetween(a, b).plan;
    expect(writeFor(plan, SyncSideRole.local, diaryKey('d'))!.isDelete, isTrue);
    final todo = writeFor(plan, SyncSideRole.local, todoKey('t1'))!;
    expect(mainOf(todo.record!)['linkedDiaryId'], isNull);
    expect(mainOf(todo.record!)['title'], 'edited');
    expect(mainOf(todo.record!)['listId'], 'l');
    expectConverged(a, b, plan);
  });

  test('复活的日记恢复保留一侧待办的日记关联', () {
    final (a, b) = both();
    hardDeleteD(b, 2000);
    a
      ..put(diaryRecord('d', title: 'edited after delete'))
      ..commit(3000);
    final plan = planBetween(a, b).plan;
    expect(
      writeFor(plan, SyncSideRole.remote, diaryKey('d'))!.isInsert,
      isTrue,
    );
    final todo = writeFor(plan, SyncSideRole.remote, todoKey('t1'))!;
    expect(mainOf(todo.record!)['linkedDiaryId'], 'd');
    expect(plan.local.writes, isEmpty);
    expectConverged(a, b, plan);
  });

  test('清单删除传播，另一侧之后新加进清单的待办移到收集箱', () {
    final (a, b) = both();
    deleteListL(b, 2000);
    a
      ..put(todoRecord('t3', listId: 'l'))
      ..commit(3000);
    final plan = planBetween(a, b).plan;
    expect(
      writeFor(plan, SyncSideRole.local, todoListKey('l'))!.isDelete,
      isTrue,
    );
    expect(writeFor(plan, SyncSideRole.local, todoKey('t1'))!.isDelete, isTrue);
    final local = writeFor(plan, SyncSideRole.local, todoKey('t3'))!;
    expect(mainOf(local.record!)['listId'], isNull);
    final remote = writeFor(plan, SyncSideRole.remote, todoKey('t3'))!;
    expect(remote.isInsert, isTrue);
    expect(mainOf(remote.record!)['listId'], isNull);
    expect(writeFor(plan, SyncSideRole.local, todoKey('t2')), isNull);
    expectConverged(a, b, plan);
  });

  test('删除之后改过的待办保留（不复活清单），移到收集箱', () {
    final (a, b) = both();
    deleteListL(b, 2000);
    a
      ..put(
        todoRecord(
          't1',
          title: 'edited',
          listId: 'l',
          linkedDiaryId: 'd',
          completedAt: 3000,
        ),
      )
      ..commit(3000);
    final plan = planBetween(a, b).plan;
    expect(
      writeFor(plan, SyncSideRole.local, todoListKey('l'))!.isDelete,
      isTrue,
    );
    final remote = writeFor(plan, SyncSideRole.remote, todoKey('t1'))!;
    expect(remote.isInsert, isTrue);
    expect(mainOf(remote.record!)['listId'], isNull);
    expect(mainOf(remote.record!)['linkedDiaryId'], 'd');
    expect(mainOf(remote.record!)['completedAt'], 3000);
    expect(
      mainOf(writeFor(plan, SyncSideRole.local, todoKey('t1'))!.record!),
      mainOf(remote.record!),
    );
    expectConverged(a, b, plan);
  });

  test('复活的清单带回保留一侧被一并删除的待办', () {
    final (a, b) = both();
    deleteListL(b, 2000);
    a
      ..put(todoListRecord('l', name: 'renamed', updatedAt: 3000))
      ..commit(3000);
    final run = planBetween(a, b);
    final plan = run.plan;
    expect(
      writeFor(plan, SyncSideRole.remote, todoListKey('l'))!.isInsert,
      isTrue,
    );
    final todo = writeFor(plan, SyncSideRole.remote, todoKey('t1'))!;
    expect(todo.isInsert, isTrue);
    expect(mainOf(todo.record!)['listId'], 'l');
    expect(plan.local.writes, isEmpty);
    // 被一并删除的待办要读出所在清单才知道是不是复活清单里的（本机记录）。
    expect(run.localRecords, contains(todoKey('t1')));
    expectConverged(a, b, plan);
  });

  test('两侧原样的待办在别的清单删除时不读记录、不动', () {
    final (a, b) = both();
    a
      ..put(todoListRecord('m'))
      ..commit(2000);
    b
      ..put(todoListRecord('m'))
      ..commit(2000);
    a
      ..remove(todoListKey('m'))
      ..commit(3000);
    final run = planBetween(a, b);
    expect(
      writeFor(run.plan, SyncSideRole.remote, todoListKey('m'))!.isDelete,
      isTrue,
    );
    expect(run.localRecords, isNot(contains(todoKey('t1'))));
    expect(run.remoteRecords, isNot(contains(todoKey('t1'))));
    expect(writeFor(run.plan, SyncSideRole.remote, todoKey('t1')), isNull);
  });
}
