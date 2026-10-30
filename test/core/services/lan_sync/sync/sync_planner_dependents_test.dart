import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';

import 'sync_planner_fixtures.dart';

/// 从属与复活（规格 §4.3）：删除带走从属、复活带回从属、留言复活日记、
/// 悬空的成员 / 书序 / 留言 / 纪念日关联、智能本与章节。
void main() {
  /// 两侧共有：日记 d（标签 t）在手动本 n 的章节 c1 里，留言 c 与纪念日 a
  /// 指向 d。
  List<SyncRecord> base() => [
    diaryRecord('d', tags: ['t']),
    tagRecord('t'),
    notebookRecord('n', chapters: ['c1']),
    memberRecord('n', 'd', chapter: 'c1'),
    listRecord('book:n', ['d']),
    listRecord('shelf', ['n']),
    commentRecord('c', 'd'),
    anniversaryRecord('a', linkedDiaryId: 'd'),
  ];

  (PlanDevice, PlanDevice) both() {
    final a = PlanDevice('a')..putAll(base());
    final b = PlanDevice('b')..putAll(base());
    a.commit(1000);
    b.commit(1000);
    return (a, b);
  }

  /// 应用自己彻底删除日记 d 的连带效果。
  void hardDeleteD(PlanDevice device, int at) {
    device
      ..remove(diaryKey('d'))
      ..remove(memberKey('n', 'd'))
      ..remove(commentKey('c'))
      ..put(anniversaryRecord('a'))
      ..put(listRecord('book:n', []))
      ..commit(at);
  }

  void expectConverged(PlanDevice a, PlanDevice b, SyncPlan plan) {
    applyBoth(a, b, plan);
    expect(a.manifest.toJson(), b.manifest.toJson());
  }

  test('删除传播时一并删除成员、留言，清掉纪念日关联，书序去掉它', () {
    final (a, b) = both();
    hardDeleteD(b, 2000);
    final plan = planBetween(a, b).plan;
    final local = plan.local;
    expect(writeFor(plan, SyncSideRole.local, diaryKey('d'))!.isDelete, isTrue);
    expect(
      writeFor(plan, SyncSideRole.local, memberKey('n', 'd'))!.isDelete,
      isTrue,
    );
    expect(
      writeFor(plan, SyncSideRole.local, commentKey('c'))!.isDelete,
      isTrue,
    );
    expect(local.stats[SyncEntity.diary], const SyncEntityCounts(deleted: 1));
    expectConverged(a, b, plan);
    expect(
      (a.records[anniversaryKey('a')]!.facets[SyncFacet.main]!
          as Map)['linkedDiaryId'],
      isNull,
    );
    expect(a.records[listKey('book:n')]!.facets[SyncFacet.items], {
      'ids': <String>[],
    });
  });

  test('复活的日记带回保留一侧的成员、留言、纪念日关联与书序', () {
    final (a, b) = both();
    hardDeleteD(b, 2000);
    a
      ..put(diaryRecord('d', title: 'edited after delete', tags: ['t']))
      ..commit(3000);
    final plan = planBetween(a, b).plan;
    expect(
      writeFor(plan, SyncSideRole.remote, diaryKey('d'))!.isInsert,
      isTrue,
    );
    expect(
      writeFor(
        plan,
        SyncSideRole.remote,
        memberKey('n', 'd'),
      )!.record!.facets[SyncFacet.main],
      {'chapterId': 'c1', 'addedAt': 1000},
    );
    expect(
      writeFor(plan, SyncSideRole.remote, commentKey('c'))!.isInsert,
      isTrue,
    );
    expect(
      (writeFor(
            plan,
            SyncSideRole.remote,
            anniversaryKey('a'),
          )!.record!.facets[SyncFacet.main]!
          as Map)['linkedDiaryId'],
      'd',
    );
    expect(plan.local.writes, isEmpty);
    expectConverged(a, b, plan);
    expect(b.records[listKey('book:n')]!.facets[SyncFacet.items], {
      'ids': ['d'],
    });
  });

  test('给已被对方删除的日记改留言，算作修改日记：日记复活', () {
    final (a, b) = both();
    hardDeleteD(b, 2000);
    a
      ..put(commentRecord('c', 'd', content: 'second thoughts', editedAt: 3000))
      ..commit(3000);
    final plan = planBetween(a, b).plan;
    expect(
      writeFor(plan, SyncSideRole.remote, diaryKey('d'))!.isInsert,
      isTrue,
    );
    expect(
      writeFor(plan, SyncSideRole.remote, commentKey('c'))!.isInsert,
      isTrue,
    );
    expect(
      writeFor(plan, SyncSideRole.remote, memberKey('n', 'd'))!.isInsert,
      isTrue,
    );
    expectConverged(a, b, plan);
  });

  test('新增留言同样复活日记；成员关系的改动不复活', () {
    final (a, b) = both();
    hardDeleteD(b, 2000);
    a
      ..put(commentRecord('c2', 'd'))
      ..commit(3000);
    expect(
      writeFor(
        planBetween(a, b).plan,
        SyncSideRole.remote,
        diaryKey('d'),
      )!.isInsert,
      isTrue,
    );

    final (x, y) = both();
    hardDeleteD(y, 2000);
    x
      ..put(memberRecord('n', 'd', chapter: null))
      ..commit(3000);
    final plan = planBetween(x, y).plan;
    expect(writeFor(plan, SyncSideRole.local, diaryKey('d'))!.isDelete, isTrue);
    expect(
      writeFor(plan, SyncSideRole.local, memberKey('n', 'd'))!.isDelete,
      isTrue,
    );
  });

  test('复活的日记本带回成员、书序与子本的上级', () {
    final a = PlanDevice('a');
    final b = PlanDevice('b');
    final records = [
      diaryRecord('d'),
      notebookRecord('n'),
      notebookRecord('k', parentId: 'n'),
      memberRecord('n', 'd'),
      listRecord('book:n', ['d']),
      listRecord('book:k', []),
      listRecord('shelf', ['n', 'k']),
    ];
    a.putAll(records);
    b.putAll(records);
    a.commit(1000);
    b.commit(1000);
    // b 删除 n：子本 k 提到顶层，成员与书序随之删除。
    b
      ..remove(notebookKey('n'))
      ..remove(memberKey('n', 'd'))
      ..remove(listKey('book:n'))
      ..put(notebookRecord('k', updatedAt: 2000))
      ..put(listRecord('shelf', ['k']))
      ..commit(2000);
    a
      ..put(notebookRecord('n', name: 'renamed', updatedAt: 3000))
      ..commit(3000);
    final plan = planBetween(a, b).plan;
    expect(
      writeFor(plan, SyncSideRole.remote, notebookKey('n'))!.isInsert,
      isTrue,
    );
    expect(
      writeFor(plan, SyncSideRole.remote, memberKey('n', 'd'))!.isInsert,
      isTrue,
    );
    expect(
      writeFor(plan, SyncSideRole.remote, listKey('book:n'))!.isInsert,
      isTrue,
    );
    final child = writeFor(plan, SyncSideRole.remote, notebookKey('k'))!;
    expect(
      (child.record!.facets[SyncFacet.definition]! as Map)['parentId'],
      'n',
    );
    applyBoth(a, b, plan);
    expect(a.manifest.toJson(), b.manifest.toJson());
    expect(b.records[listKey('shelf')]!.facets[SyncFacet.items], {
      'ids': ['k', 'n'],
    });
  });

  test('改成智能本后，另一侧新加的成员与书序一并丢弃', () {
    final (a, b) = both();
    a
      ..put(
        notebookRecord('n', kind: 'smart', chapters: ['c1'], updatedAt: 3000),
      )
      ..remove(memberKey('n', 'd'))
      ..remove(listKey('book:n'))
      ..commit(3000);
    b
      ..put(diaryRecord('e'))
      ..put(memberRecord('n', 'e'))
      ..put(listRecord('book:n', ['d', 'e']))
      ..commit(2000);
    final plan = planBetween(a, b).plan;
    expect(
      writeFor(plan, SyncSideRole.remote, memberKey('n', 'd'))!.isDelete,
      isTrue,
    );
    expect(
      writeFor(plan, SyncSideRole.remote, memberKey('n', 'e'))!.isDelete,
      isTrue,
    );
    expect(
      writeFor(plan, SyncSideRole.remote, listKey('book:n'))!.isDelete,
      isTrue,
    );
    expect(writeFor(plan, SyncSideRole.local, memberKey('n', 'e')), isNull);
    expectConverged(a, b, plan);
  });

  test('章节不在日记本最终的章节里时写 null', () {
    final (a, b) = both();
    // a 删掉章节 c1（其中的日记回到“未分章”）；b 同时往 c1 里加了一篇。
    a
      ..put(notebookRecord('n', updatedAt: 3000))
      ..put(memberRecord('n', 'd'))
      ..commit(3000);
    b
      ..put(diaryRecord('e'))
      ..put(memberRecord('n', 'e', chapter: 'c1'))
      ..put(listRecord('book:n', ['d', 'e']))
      ..commit(2000);
    final plan = planBetween(a, b).plan;
    expect(
      writeFor(
        plan,
        SyncSideRole.local,
        memberKey('n', 'e'),
      )!.record!.facets[SyncFacet.main],
      {'chapterId': null, 'addedAt': 1000},
    );
    expect(
      writeFor(
        plan,
        SyncSideRole.remote,
        memberKey('n', 'e'),
      )!.record!.facets[SyncFacet.main],
      {'chapterId': null, 'addedAt': 1000},
    );
    expectConverged(a, b, plan);
  });

  test('两侧原样的成员关系在日记本改了章节时也被校正（读本机记录，不走网络）', () {
    final (a, b) = both();
    // a 只改了日记本（去掉章节），没动成员关系（坏数据）。
    a
      ..put(notebookRecord('n', updatedAt: 3000))
      ..commit(3000);
    final run = planBetween(a, b);
    expect(run.localRecords, contains(memberKey('n', 'd')));
    expect(run.remoteRecords, isNot(contains(memberKey('n', 'd'))));
    final local = writeFor(run.plan, SyncSideRole.local, memberKey('n', 'd'))!;
    expect((local.record!.facets[SyncFacet.main]! as Map)['chapterId'], isNull);
    expect(
      writeFor(run.plan, SyncSideRole.remote, memberKey('n', 'd')),
      isNotNull,
    );
  });

  test('留言所属日记最终不存在时丢弃，纪念日指向不存在的日记时置 null', () {
    final (a, b) = both();
    hardDeleteD(b, 2000);
    // a 在删除之前（b 不知道）给纪念日改了标题——不是改日记，不复活日记。
    a
      ..put(
        anniversaryRecord(
          'a',
          title: 'renamed',
          linkedDiaryId: 'd',
          updatedAt: 3000,
        ),
      )
      ..commit(3000);
    final plan = planBetween(a, b).plan;
    final main =
        writeFor(
              plan,
              SyncSideRole.local,
              anniversaryKey('a'),
            )!.record!.facets[SyncFacet.main]!
            as Map;
    expect(main['linkedDiaryId'], isNull);
    expect(main['title'], 'renamed');
    expectConverged(a, b, plan);
  });

  test('书架只含最终存在的日记本：新本追加，删掉的去掉', () {
    final (a, b) = both();
    a
      ..put(notebookRecord('m'))
      ..put(listRecord('book:m', []))
      ..put(listRecord('shelf', ['n', 'm']))
      ..commit(2000);
    final plan = planBetween(a, b).plan;
    expect(
      writeFor(
        plan,
        SyncSideRole.remote,
        listKey('shelf'),
      )!.record!.facets[SyncFacet.items],
      {
        'ids': ['n', 'm'],
      },
    );
    expectConverged(a, b, plan);
  });
}
