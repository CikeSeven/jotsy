import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_canonical_settings.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_planner.dart';

import 'sync_planner_fixtures.dart';

/// 日记本层级（规格 §4.4）：在最终集合上按 `NotebookHierarchy` 口径校验，
/// 不合法的精确断开；与数据库层的实现对拍。
void main() {
  test('规划器里的常量与数据库 / 设置层一致', () {
    expect(kSyncNotebookMaxDepth, kNotebookMaxDepth);
    expect(kSyncBuiltInTemplatePrefix, builtInDiaryTemplateIdPrefix);
    expect(kSyncPlannerTagOrderFacet, kSyncTagOrderNamesFacet);
  });

  String? parentIn(SyncWrite? write) =>
      (write?.record?.facets[SyncFacet.definition] as Map?)?['parentId']
          as String?;

  (PlanDevice, PlanDevice) both(List<SyncRecord> base) {
    final a = PlanDevice('a')..putAll(base);
    final b = PlanDevice('b')..putAll(base);
    a.commit(1000);
    b.commit(1000);
    return (a, b);
  }

  test('两侧各自移动造成的环：环上的每一本都断开', () {
    final (a, b) = both([notebookRecord('x'), notebookRecord('y')]);
    a
      ..put(notebookRecord('x', parentId: 'y', updatedAt: 2000))
      ..commit(2000);
    b
      ..put(notebookRecord('y', parentId: 'x', updatedAt: 2000))
      ..commit(2000);
    final plan = planBetween(a, b).plan;
    applyBoth(a, b, plan);
    expect(a.manifest.toJson(), b.manifest.toJson());
    for (final id in ['x', 'y']) {
      final definition =
          a.records[notebookKey(id)]!.facets[SyncFacet.definition]! as Map;
      expect(definition['parentId'], isNull, reason: id);
    }
  });

  test('上级被另一侧改成智能本：断开', () {
    final (a, b) = both([notebookRecord('p'), notebookRecord('q')]);
    a
      ..put(notebookRecord('p', kind: 'smart', updatedAt: 2000))
      ..commit(2000);
    b
      ..put(notebookRecord('q', parentId: 'p', updatedAt: 2000))
      ..commit(2000);
    final plan = planBetween(a, b).plan;
    expect(
      parentIn(writeFor(plan, SyncSideRole.remote, notebookKey('q'))),
      isNull,
    );
    // 本机拿到 b 的定义（updatedAt 变了），上级同样断开。
    expect(
      parentIn(writeFor(plan, SyncSideRole.local, notebookKey('q'))),
      isNull,
    );
    applyBoth(a, b, plan);
    expect(a.manifest.toJson(), b.manifest.toJson());
  });

  test('上级被另一侧删除：断开（子本提到顶层）', () {
    final (a, b) = both([notebookRecord('p'), notebookRecord('q')]);
    a
      ..remove(notebookKey('p'))
      ..commit(2000);
    b
      ..put(notebookRecord('q', parentId: 'p', updatedAt: 2000))
      ..commit(2000);
    final plan = planBetween(a, b).plan;
    expect(
      writeFor(plan, SyncSideRole.remote, notebookKey('p'))!.isDelete,
      isTrue,
    );
    expect(
      parentIn(writeFor(plan, SyncSideRole.remote, notebookKey('q'))),
      isNull,
    );
  });

  test('超过三层：只断开放不下的那一层', () {
    final (a, b) = both([
      notebookRecord('n1'),
      notebookRecord('n2', parentId: 'n1'),
      notebookRecord('m1'),
      notebookRecord('m2', parentId: 'm1'),
    ]);
    // a 把 m1 挂到 n2 下（a 看来合法：m 树两层 + n2 在第 2 层 = 4 层？不，a
    // 这边 m1 还没有子本——模拟 b 同时给 m1 加了子本）。
    a
      ..remove(notebookKey('m2'))
      ..put(notebookRecord('m1', parentId: 'n2', updatedAt: 2000))
      ..commit(2000);
    b
      ..put(notebookRecord('m3', parentId: 'm2'))
      ..commit(2000);
    final plan = planBetween(a, b).plan;
    applyBoth(a, b, plan);
    expect(a.manifest.toJson(), b.manifest.toJson());
    String? parent(String id) =>
        (a.records[notebookKey(id)]!.facets[SyncFacet.definition]!
                as Map)['parentId']
            as String?;
    expect(parent('m1'), 'n2');
    // m2 被 a 删除、b 没改过：删除传播；m3 是新的，上级 m2 不在了 → 顶层。
    expect(a.records.containsKey(notebookKey('m2')), isFalse);
    expect(parent('m3'), isNull);
  });

  test('与 NotebookHierarchy.repairs 对拍（随机层级）', () {
    final random = Random(42);
    for (var round = 0; round < 300; round++) {
      final count = 2 + random.nextInt(7);
      final ids = [for (var i = 0; i < count; i++) 'n$i'];
      final rows = <NotebookRow>[];
      final a = PlanDevice('a');
      for (final id in ids) {
        final roll = random.nextInt(10);
        final parent = roll < 6
            ? ids[random.nextInt(count)]
            : (roll < 8 ? null : 'missing');
        final kind = random.nextInt(5) == 0 ? 'smart' : 'manual';
        a.put(notebookRecord(id, kind: kind, parentId: parent));
        rows.add(
          NotebookRow(
            id: rows.length + 1,
            notebookId: id,
            name: id,
            kind: kind,
            visibility: 'normal',
            payload: '{}',
            sortOrder: rows.length,
            isPinned: false,
            isClosed: false,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
            parentId: parent,
          ),
        );
      }
      a.commit(1000);
      final b = PlanDevice('b')..commit(1000);
      final plan = planBetween(a, b).plan;
      final repaired = <String>{
        for (final write in plan.local.writes)
          if (write.key.entity == SyncEntity.notebook) write.key.id,
      };
      expect(
        repaired,
        NotebookHierarchy(rows).repairs.keys.toSet(),
        reason:
            'round $round: ${rows.map((r) => '${r.notebookId}<${r.parentId}:${r.kind}').join(' ')}',
      );
      for (final id in repaired) {
        expect(
          parentIn(writeFor(plan, SyncSideRole.local, notebookKey(id))),
          isNull,
        );
      }
    }
  });
}
