import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_planner.dart';

import 'sync_planner_fixtures.dart';

/// 冲突副本（规格 §4.1 diary.content）：败方另存、继承败方的私密与状态、
/// id 稳定、不重复生成。
void main() {
  const options = SyncPlanOptions(nowMillis: 0, conflictTitleSuffix: '（冲突副本）');

  /// 共有：私密日记本 h（章节 c1）里的日记 d，带标签 t。之后 a、b 各改一次
  /// 正文（b 的 stamp 较新，a 是败方）；a 另外把 d 放进回收站、设成胶囊。
  (PlanDevice, PlanDevice) conflicted() {
    final base = [
      diaryRecord('d', title: 'base', tags: ['t']),
      tagRecord('t'),
      notebookRecord('h', visibility: 'hidden', chapters: ['c1']),
      memberRecord('h', 'd', chapter: 'c1'),
      listRecord('book:h', ['d']),
      listRecord('shelf', ['h']),
    ];
    final a = PlanDevice('a')..putAll(base);
    final b = PlanDevice('b')..putAll(base);
    a.commit(1000);
    b.commit(1000);
    a
      ..put(
        diaryRecord(
          'd',
          title: 'mine',
          tags: ['t'],
          updatedAt: 4000,
          deleted: true,
          unlockAt: 99999000,
        ),
      )
      ..commit(4000);
    b
      ..put(diaryRecord('d', title: 'theirs', tags: ['t'], updatedAt: 5000))
      ..commit(5000);
    return (a, b);
  }

  String loserHash(PlanDevice a) =>
      a.manifest[diaryKey('d')]![SyncFacet.content]!;

  test('stamp 较新者留在原 id，败方另存为副本，继承败方的分面与成员关系', () {
    final (a, b) = conflicted();
    final plan = planBetween(a, b, options: options).plan;
    final copyId = syncConflictCopyId('d', loserHash(a));
    expect(plan.conflictCopies.single.originalId, 'd');
    expect(plan.conflictCopies.single.copyId, copyId);
    expect(plan.conflictCopies.single.loser, SyncSideRole.local);
    expect(plan.conflictCopies.single.title, 'mine（冲突副本）');

    for (final role in SyncSideRole.values) {
      final copy = writeFor(plan, role, diaryKey(copyId))!;
      expect(copy.isInsert, isTrue);
      final facets = copy.record!.facets;
      final content = facets[SyncFacet.content]! as Map;
      expect(content['title'], 'mine（冲突副本）');
      expect(content['metadata'], {
        'sync': {'conflictOf': 'd'},
      });
      expect(facets[SyncFacet.trash], {'deleted': true, 'deletedAt': 4000});
      expect((facets[SyncFacet.capsule]! as Map)['unlockAt'], 99999000);
      expect(facets[SyncFacet.tags], {
        'names': ['t'],
      });
      expect(facets[SyncFacet.stamp], {'updatedAt': 4000});
      // 私密日记本里的内容不会因副本出现在“全部日记”。
      final member = writeFor(plan, role, memberKey('h', copyId))!;
      expect(member.isInsert, isTrue);
      expect(member.record!.facets[SyncFacet.main], {
        'chapterId': 'c1',
        'addedAt': 1000,
      });
      expect(
        writeFor(
          plan,
          role,
          listKey('book:h'),
        )!.record!.facets[SyncFacet.items],
        {
          'ids': ['d', copyId],
        },
      );
    }
    // 原 id 上是胜方正文；trash / capsule 照常逐分面判定（a 的改动是后代）。
    final original = writeFor(plan, SyncSideRole.local, diaryKey('d'))!;
    expect(
      (original.record!.facets[SyncFacet.content]! as Map)['title'],
      'theirs',
    );
    applyBoth(a, b, plan);
    expect(a.manifest.toJson(), b.manifest.toJson());
  });

  test('stamp 平手时 deviceId 较大的一侧胜出', () {
    final a = PlanDevice('b-device')..put(diaryRecord('d'));
    final b = PlanDevice('a-device')..put(diaryRecord('d'));
    a.commit(1000);
    b.commit(1000);
    a
      ..put(diaryRecord('d', title: 'x', updatedAt: 5000))
      ..commit(2000);
    b
      ..put(diaryRecord('d', title: 'y', updatedAt: 5000))
      ..commit(2000);
    final plan = planBetween(a, b).plan;
    expect(plan.conflictCopies.single.loser, SyncSideRole.remote);
    // 败方的正文换了而 stamp 相同：抬高 1 秒。
    final remote = writeFor(plan, SyncSideRole.remote, diaryKey('d'))!;
    expect(remote.record!.facets[SyncFacet.stamp], {
      'updatedAt': 5000 + kSyncStampBumpMillis,
    });
  });

  test('重新规划（换发起方）得到同一个副本 id', () {
    final (a, b) = conflicted();
    final first = planBetween(a, b, options: options).plan;
    final second = planBetween(b, a, options: options).plan;
    expect(
      second.conflictCopies.single.copyId,
      first.conflictCopies.single.copyId,
    );
    expect(second.conflictCopies.single.loser, SyncSideRole.remote);
  });

  for (final applied in SyncSideRole.values) {
    test('中断（只有 ${applied.name} 一侧写入）后重新同步不重复生成副本', () {
      final (a, b) = conflicted();
      final plan = planBetween(a, b, options: options).plan;
      final copyId = plan.conflictCopies.single.copyId;
      if (applied == SyncSideRole.local) {
        a.applyAndCommit(plan.local, 6000);
      } else {
        b.applyAndCommit(plan.remote, 6000);
      }
      final retry = planBetween(a, b, options: options).plan;
      expect(retry.conflictCopies, isEmpty);
      applyBoth(a, b, retry);
      expect(a.manifest.toJson(), b.manifest.toJson());
      final copies = a.records.keys.where(
        (key) => key.entity == SyncEntity.diary && key.id != 'd',
      );
      expect(copies.map((key) => key.id), [copyId]);
    });
  }

  test('用户删掉了副本（有墓碑）时，同一个冲突不再生成它', () {
    final (a, b) = conflicted();
    final plan = planBetween(a, b, options: options).plan;
    final copyId = plan.conflictCopies.single.copyId;
    a.applyAndCommit(plan.local, 6000);
    a
      ..remove(diaryKey(copyId))
      ..remove(memberKey('h', copyId))
      ..put(listRecord('book:h', ['d']))
      ..commit(7000);
    final retry = planBetween(a, b, options: options).plan;
    expect(retry.conflictCopies, isEmpty);
    expect(writeFor(retry, SyncSideRole.remote, diaryKey(copyId)), isNull);
  });

  test('副本标题截断到 200 个 UTF-16 码元，不切开代理对', () {
    String copyTitle(String title, String suffix) {
      final a = PlanDevice('a')..put(diaryRecord('d'));
      final b = PlanDevice('b')..put(diaryRecord('d'));
      a.commit(1000);
      b.commit(1000);
      a
        ..put(diaryRecord('d', title: title, updatedAt: 2000))
        ..commit(2000);
      b
        ..put(diaryRecord('d', title: 'short', updatedAt: 3000))
        ..commit(2000);
      return planBetween(
        a,
        b,
        options: SyncPlanOptions(nowMillis: 0, conflictTitleSuffix: suffix),
      ).plan.conflictCopies.single.title;
    }

    final full = '${'x' * 198}😀';
    expect(copyTitle(full, '!'), full);
    // 截断点落在后缀 emoji 的两个码元之间：整个 emoji 丢掉。
    expect(copyTitle('x' * 199, '😀'), 'x' * 199);
    expect(copyTitle('x' * 10, '（冲突副本）'), '${'x' * 10}（冲突副本）');
  });

  test('metadata 是坏数据原文时原样保留', () {
    final a = PlanDevice('a')..put(diaryRecord('d', metadata: 'not json'));
    final b = PlanDevice('b')..put(diaryRecord('d', metadata: 'not json'));
    a.commit(1000);
    b.commit(1000);
    a
      ..put(diaryRecord('d', title: 'x', metadata: 'not json', updatedAt: 2000))
      ..commit(2000);
    b
      ..put(diaryRecord('d', title: 'y', metadata: 'not json', updatedAt: 3000))
      ..commit(2000);
    final plan = planBetween(a, b).plan;
    final copy = writeFor(
      plan,
      SyncSideRole.local,
      diaryKey(plan.conflictCopies.single.copyId),
    )!;
    expect(
      (copy.record!.facets[SyncFacet.content]! as Map)['metadata'],
      'not json',
    );
  });
}
