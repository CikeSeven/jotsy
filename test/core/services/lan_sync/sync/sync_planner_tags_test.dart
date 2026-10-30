import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';

import 'sync_planner_fixtures.dart';

/// 标签（规格 §4.2）：被引用的不删、改名换掉日记上的旧名、原地改名、设置里
/// 的标签顺序。
void main() {
  (PlanDevice, PlanDevice) both(
    List<SyncRecord> base, {
    bool settings = false,
  }) {
    final a = PlanDevice('a', settings: settings)..putAll(base);
    final b = PlanDevice('b', settings: settings)..putAll(base);
    a.commit(1000);
    b.commit(1000);
    return (a, b);
  }

  Object? tagsOf(SyncWrite? write) => write?.record?.facets[SyncFacet.tags];

  test('删掉的标签若还被最终日记引用则保留（复制回删除一侧）', () {
    final (a, b) = both([
      diaryRecord('d'),
      diaryRecord('e'),
      tagRecord('t', color: 3),
    ]);
    b
      ..remove(tagKey('t'))
      ..commit(2000);
    a
      ..put(diaryRecord('e', tags: ['t']))
      ..commit(3000);
    final plan = planBetween(a, b).plan;
    final tag = writeFor(plan, SyncSideRole.remote, tagKey('t'))!;
    expect(tag.isInsert, isTrue);
    expect(tag.record!.facets[SyncFacet.color], {'color': 3});
    expect(writeFor(plan, SyncSideRole.local, tagKey('t')), isNull);
  });

  test('没有日记引用、墓碑覆盖时照常删除', () {
    final (a, b) = both([diaryRecord('d'), tagRecord('t')]);
    b
      ..remove(tagKey('t'))
      ..commit(2000);
    expect(
      writeFor(
        planBetween(a, b).plan,
        SyncSideRole.local,
        tagKey('t'),
      )!.isDelete,
      isTrue,
    );
  });

  group('改名', () {
    List<SyncRecord> base() => [
      diaryRecord('d', tags: ['work']),
      tagRecord('work', color: 2),
    ];

    /// a 把 work 改名为 job（日记 d 随之变成 job）。
    void renameOnA(PlanDevice a) {
      a
        ..renameTag('work', 'job')
        ..put(diaryRecord('d', tags: ['job']))
        ..commit(2000);
    }

    test('另一侧原地改名，并换掉它在改名之后打上旧名的日记', () {
      final (a, b) = both(base());
      renameOnA(a);
      b
        ..put(diaryRecord('e', tags: ['work']))
        ..commit(3000);
      final plan = planBetween(a, b).plan;
      final rename = plan.remote.renames.single;
      expect(rename.from, 'work');
      expect(rename.to, 'job');
      expect(rename.expected, b.manifest[tagKey('work')]);
      expect(rename.record.facets[SyncFacet.color], {'color': 2});
      // 改名占掉了“删 work + 建 job”。
      expect(writeFor(plan, SyncSideRole.remote, tagKey('work')), isNull);
      expect(writeFor(plan, SyncSideRole.remote, tagKey('job')), isNull);
      expect(
        plan.remote.stats[SyncEntity.tag],
        const SyncEntityCounts(updated: 1),
      );
      expect(tagsOf(writeFor(plan, SyncSideRole.local, diaryKey('e'))), {
        'names': ['job'],
      });
      expect(tagsOf(writeFor(plan, SyncSideRole.remote, diaryKey('d'))), {
        'names': ['job'],
      });
      applyBoth(a, b, plan);
      expect(a.manifest.toJson(), b.manifest.toJson());
    });

    test('另一侧已有新名时不原地改名：旧名照常删除，引用换成新名', () {
      final (a, b) = both(base());
      renameOnA(a);
      b
        ..put(tagRecord('job', color: 7))
        ..put(diaryRecord('e', tags: ['job', 'work']))
        ..commit(3000);
      final plan = planBetween(a, b).plan;
      expect(plan.remote.renames, isEmpty);
      expect(
        writeFor(plan, SyncSideRole.remote, tagKey('work'))!.isDelete,
        isTrue,
      );
      expect(tagsOf(writeFor(plan, SyncSideRole.remote, diaryKey('e'))), {
        'names': ['job'],
      });
    });

    test('另一侧在改名之后改过旧名的颜色：旧名保留，不原地改名', () {
      final (a, b) = both(base());
      renameOnA(a);
      b
        ..put(tagRecord('work', color: 9))
        ..commit(3000);
      final plan = planBetween(a, b).plan;
      expect(plan.remote.renames, isEmpty);
      expect(
        writeFor(plan, SyncSideRole.remote, tagKey('job'))!.isInsert,
        isTrue,
      );
      expect(
        writeFor(plan, SyncSideRole.local, tagKey('work'))!.isInsert,
        isTrue,
      );
      applyBoth(a, b, plan);
      expect(a.manifest.toJson(), b.manifest.toJson());
    });

    test('改名链沿两侧解析（a: x → y，b: y → z）', () {
      final (a, b) = both([
        diaryRecord('d', tags: ['x']),
        tagRecord('x'),
      ]);
      a
        ..renameTag('x', 'y')
        ..put(diaryRecord('d', tags: ['y']))
        ..commit(2000);
      final first = planBetween(a, b).plan;
      a.applyAndCommit(first.local, 3000);
      b.applyAndCommit(first.remote, 3000);
      // 现在两侧都是 y；c 还停在 x（由 a 的旧状态模拟）。
      b
        ..renameTag('y', 'z')
        ..put(diaryRecord('d', tags: ['z']))
        ..commit(4000);
      final plan = planBetween(a, b).plan;
      expect(plan.local.renames.single.from, 'y');
      expect(plan.local.renames.single.to, 'z');
    });
  });

  test('标签顺序按改名换名、去掉最终不存在的标签', () {
    final (a, b) = both([
      diaryRecord('d', tags: ['work']),
      tagRecord('work'),
      tagRecord('gone'),
      prefsRecord(tagOrder: ['gone', 'work']),
    ]);
    a
      ..renameTag('work', 'job')
      ..remove(tagKey('gone'))
      ..put(diaryRecord('d', tags: ['job']))
      ..put(prefsRecord(tagOrder: ['job']))
      ..commit(2000);
    final plan = planBetween(a, b).plan;
    final prefs = writeFor(plan, SyncSideRole.remote, prefsKey)!;
    expect(prefs.record!.facets[SyncPrefsFacet.tagOrder], {
      'value': ['job'],
    });
    applyBoth(a, b, plan);
    expect(a.manifest.toJson(), b.manifest.toJson());
  });

  test('标签顺序两侧原样、只有一侧删了标签时，按最终标签校正（读本机记录）', () {
    final (a, b) = both([
      tagRecord('keep'),
      tagRecord('gone'),
      prefsRecord(tagOrder: ['gone', 'keep']),
    ]);
    // b 删了标签，但标签顺序的规范值还没来得及变（坏数据）：规划仍校正两侧。
    b
      ..remove(tagKey('gone'))
      ..commit(2000);
    final run = planBetween(a, b);
    expect(run.localRecords, contains(prefsKey));
    for (final role in SyncSideRole.values) {
      expect(
        writeFor(
          run.plan,
          role,
          prefsKey,
        )!.record!.facets[SyncPrefsFacet.tagOrder],
        {
          'value': ['keep'],
        },
      );
    }
  });
}
