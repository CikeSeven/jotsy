import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_planner.dart';

import 'sync_planner_fixtures.dart';

/// 不按“取一侧”判定的分面（规格 §4.1）：stamp 取较大值并在必要时抬高，
/// diary.tags 与 orderList.items 三方合并。
void main() {
  group('diary.stamp', () {
    test('取较大值，从不是冲突', () {
      final (a, b) = forkDevices(
        [diaryRecord('d', updatedAt: 1000)],
        [diaryRecord('d', title: 'x', updatedAt: 8000)],
        [],
      );
      final run = planBetween(a, b);
      final write = writeFor(run.plan, SyncSideRole.remote, diaryKey('d'))!;
      expect(facetOf(write, SyncFacet.stamp), {'updatedAt': 8000});
    });

    test('正文变了而 stamp 恰好等于写入方原值时 +1 秒', () {
      // b 的时钟偏快：b 只改了置顶，stamp 却比 a 改正文的还大。
      final (a, b) = forkDevices(
        [diaryRecord('d', updatedAt: 1000)],
        [diaryRecord('d', title: 'edited', updatedAt: 5000)],
        [diaryRecord('d', pinned: true, updatedAt: 9000)],
      );
      final run = planBetween(a, b);
      final local = writeFor(run.plan, SyncSideRole.local, diaryKey('d'))!;
      final remote = writeFor(run.plan, SyncSideRole.remote, diaryKey('d'))!;
      expect(facetOf(remote, SyncFacet.stamp), {
        'updatedAt': 9000 + kSyncStampBumpMillis,
      });
      expect(facetOf(local, SyncFacet.stamp), {
        'updatedAt': 9000 + kSyncStampBumpMillis,
      });
      expect((facetOf(remote, SyncFacet.content)! as Map)['title'], 'edited');
      expect(facetOf(remote, SyncFacet.pin), {'pinned': true});
    });

    test('只是 stamp 不同（正文相同）时不抬高', () {
      final a = PlanDevice('a')..put(diaryRecord('d', updatedAt: 3000));
      final b = PlanDevice('b')..put(diaryRecord('d', updatedAt: 7000));
      a.commit(1);
      b.commit(1);
      final run = planBetween(a, b);
      expect(
        facetOf(
          writeFor(run.plan, SyncSideRole.local, diaryKey('d')),
          SyncFacet.stamp,
        ),
        {'updatedAt': 7000},
      );
    });
  });

  group('diary.tags 三方合并', () {
    test('有共同祖先：祖先 ∪ 双方新增 − 任一方删除', () {
      final (a, b) = forkDevices(
        [
          diaryRecord('d', tags: ['keep', 'dropL', 'dropR']),
        ],
        [
          diaryRecord('d', tags: ['keep', 'dropR', 'addL']),
        ],
        [
          diaryRecord('d', tags: ['keep', 'dropL', 'addR']),
        ],
      );
      final run = planBetween(a, b);
      final write = writeFor(run.plan, SyncSideRole.local, diaryKey('d'))!;
      expect(facetOf(write, SyncFacet.tags), {
        'names': ['addL', 'addR', 'keep'],
      });
      expect(
        facetOf(
          writeFor(run.plan, SyncSideRole.remote, diaryKey('d')),
          SyncFacet.tags,
        ),
        facetOf(write, SyncFacet.tags),
      );
    });

    test('没有共同祖先：取并集', () {
      final a = PlanDevice('a')..put(diaryRecord('d', tags: ['x', 'y']));
      final b = PlanDevice('b')..put(diaryRecord('d', tags: ['y', 'z']));
      a.commit(1);
      b.commit(1);
      // 各自改过一次（历史里有值，但没有共同的）。
      a
        ..put(diaryRecord('d', tags: ['x', 'y', 'w']))
        ..commit(2);
      final run = planBetween(a, b);
      expect(
        facetOf(
          writeFor(run.plan, SyncSideRole.remote, diaryKey('d')),
          SyncFacet.tags,
        ),
        {
          'names': ['w', 'x', 'y', 'z'],
        },
      );
    });
  });

  group('orderList 三方合并', () {
    List<String>? ids(SyncWrite? write) =>
        ((write?.record?.facets[SyncFacet.items] as Map?)?['ids'] as List?)
            ?.cast<String>();

    test('只有一方调整了顺序时保留那次调整，另一方的新增按相对位置插入', () {
      final base = [
        notebookRecord('n1'),
        notebookRecord('n2'),
        notebookRecord('n3'),
        listRecord('shelf', ['n1', 'n2', 'n3']),
      ];
      final (a, b) = forkDevices(
        base,
        [
          listRecord('shelf', ['n3', 'n1', 'n2']),
        ],
        [
          notebookRecord('n4'),
          listRecord('shelf', ['n1', 'n4', 'n2', 'n3']),
        ],
      );
      final run = planBetween(a, b);
      expect(ids(writeFor(run.plan, SyncSideRole.local, listKey('shelf'))), [
        'n3',
        'n1',
        'n4',
        'n2',
      ]);
    });

    test('删除任一方删掉的项', () {
      final base = [
        for (final id in ['n1', 'n2', 'n3']) notebookRecord(id),
        listRecord('shelf', ['n1', 'n2', 'n3']),
      ];
      final a = PlanDevice('a');
      final b = PlanDevice('b');
      for (final device in [a, b]) {
        device.putAll(base);
        device.commit(1000);
      }
      a
        ..remove(notebookKey('n2'))
        ..put(listRecord('shelf', ['n1', 'n3']))
        ..commit(2000);
      b
        ..put(listRecord('shelf', ['n3', 'n2', 'n1']))
        ..commit(3000);
      final run = planBetween(a, b);
      expect(ids(writeFor(run.plan, SyncSideRole.remote, listKey('shelf'))), [
        'n3',
        'n1',
      ]);
    });
  });
}
