import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_planner.dart';

import 'sync_planner_fixtures.dart';

/// 第一阶段取数（规格 §4）：只取判定真正用到的数据。`planBetween` 同时
/// 断言按需取数的计划与全知两侧的计划逐项相同。
void main() {
  test('本机独有的新记录：只构建本机这一条记录，一轮', () {
    final a = PlanDevice('a')..put(diaryRecord('d'));
    final b = PlanDevice('b');
    a.commit(1);
    b.commit(1);
    final run = planBetween(a, b);
    expect(run.fetches, hasLength(1));
    expect(run.localRecords, {diaryKey('d')});
    expect(run.remoteRecords, isEmpty);
    expect(run.remoteHistory, isEmpty);
  });

  test('对方独有的新记录：只取对方这一条记录', () {
    final a = PlanDevice('a');
    final b = PlanDevice('b')..put(diaryRecord('d'));
    a.commit(1);
    b.commit(1);
    final run = planBetween(a, b);
    expect(run.remoteRecords, {diaryKey('d')});
    expect(run.localRecords, isEmpty);
  });

  test('对方独有、本机墓碑覆盖：删除只要清单与墓碑，不取任何记录', () {
    final a = PlanDevice('a')..put(diaryRecord('d'));
    final b = PlanDevice('b')..put(diaryRecord('d'));
    a.commit(1);
    b.commit(1);
    a
      ..remove(diaryKey('d'))
      ..commit(2);
    final run = planBetween(a, b);
    expect(run.fetches, isEmpty);
    expect(
      writeFor(run.plan, SyncSideRole.remote, diaryKey('d'))!.isDelete,
      isTrue,
    );
  });

  test('本机独有、对方有墓碑：先取墓碑详情，覆盖则不再取记录', () {
    final a = PlanDevice('a')..put(diaryRecord('d'));
    final b = PlanDevice('b')..put(diaryRecord('d'));
    a.commit(1);
    b.commit(1);
    b
      ..remove(diaryKey('d'))
      ..commit(2);
    final run = planBetween(a, b);
    expect(run.fetches, hasLength(1));
    expect(run.fetches.single.remoteTombstones, [diaryKey('d')]);
    expect(run.localRecords, isEmpty);
  });

  test('本机独有、对方有墓碑但本机删除后改过：第二轮才构建本机记录', () {
    final a = PlanDevice('a')..put(diaryRecord('d'));
    final b = PlanDevice('b')..put(diaryRecord('d'));
    a.commit(1);
    b.commit(1);
    b
      ..remove(diaryKey('d'))
      ..commit(2);
    a
      ..put(diaryRecord('d', pinned: true))
      ..commit(3);
    final run = planBetween(a, b);
    expect(run.fetches, hasLength(2));
    expect(run.fetches.first.localRecords, isEmpty);
    expect(run.fetches.last.localRecords, [diaryKey('d')]);
  });

  test('两侧都有、只有本机改过（stamp 相同）：取对方历史，只构建本机记录', () {
    final a = PlanDevice('a')..put(diaryRecord('d'));
    final b = PlanDevice('b')..put(diaryRecord('d'));
    a.commit(1);
    b.commit(1);
    a
      ..put(diaryRecord('d', pinned: true))
      ..commit(2);
    final run = planBetween(a, b);
    expect(run.remoteHistory, {diaryKey('d')});
    expect(run.localRecords, {diaryKey('d')});
    expect(run.remoteRecords, isEmpty);
  });

  test('只是 stamp 不同：不取历史（stamp 取较大值），取两侧记录读值', () {
    final a = PlanDevice('a')..put(diaryRecord('d', updatedAt: 1000));
    final b = PlanDevice('b')..put(diaryRecord('d', updatedAt: 2000));
    a.commit(1);
    b.commit(1);
    final run = planBetween(a, b);
    expect(run.remoteHistory, isEmpty);
    expect(run.remoteRecords, {diaryKey('d')});
  });

  test('日记本有变化时，两侧原样的日记本只读本机记录（层级校验），不走网络', () {
    final base = [notebookRecord('p'), notebookRecord('q', parentId: 'p')];
    final a = PlanDevice('a')..putAll(base);
    final b = PlanDevice('b')..putAll(base);
    a.commit(1);
    b.commit(1);
    a
      ..put(notebookRecord('r', parentId: 'q'))
      ..commit(2);
    final run = planBetween(a, b);
    expect(run.localRecords, containsAll([notebookKey('p'), notebookKey('q')]));
    expect(run.remoteRecords, isEmpty);
  });

  test('没有按 planSyncFetch 取齐就调用 planSync：抛 StateError', () {
    final a = PlanDevice('a')..put(diaryRecord('d'));
    final b = PlanDevice('b');
    a.commit(1);
    b.commit(1);
    expect(
      () => planSync(
        local: a.lazySide(local: true),
        remote: b.lazySide(local: false),
        options: const SyncPlanOptions(nowMillis: 0),
      ),
      throwsStateError,
    );
  });
}
