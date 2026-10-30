import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_planner.dart';

import 'sync_planner_fixtures.dart';

/// 两侧都有的记录逐分面判定（规格 §4.1）。
void main() {
  /// 两台设备从同一份 [base] 出发（各自提交一次，之后历史里都有它），
  /// 再各自改成 [left] / [right] 并提交。

  group('祖先关系', () {
    test('两侧相同不产生任何写入，也不取任何数据', () {
      final (a, b) = forkDevices([diaryRecord('d')], [], []);
      final run = planBetween(a, b);
      expect(run.plan.isEmpty, isTrue);
      expect(run.fetches, isEmpty);
    });

    test('R ∈ H_L：保留本机，推给对方', () {
      final (a, b) = forkDevices(
        [diaryRecord('d')],
        [diaryRecord('d', pinned: true)],
        [],
      );
      final run = planBetween(a, b);
      expect(run.plan.local.writes, isEmpty);
      final write = writeFor(run.plan, SyncSideRole.remote, diaryKey('d'))!;
      expect(facetOf(write, SyncFacet.pin), {'pinned': true});
      expect(write.expected, b.manifest[diaryKey('d')]);
    });

    test('L ∈ H_R：取对方，写到本机', () {
      final (a, b) = forkDevices(
        [diaryRecord('d')],
        [],
        [diaryRecord('d', archived: true)],
      );
      final run = planBetween(a, b);
      expect(run.plan.remote.writes, isEmpty);
      expect(
        facetOf(
          writeFor(run.plan, SyncSideRole.local, diaryKey('d')),
          SyncFacet.archive,
        ),
        {'archived': true, 'archivedAt': 1000},
      );
    });

    test('改回旧值（两个值都在彼此历史里）：当前值确立得更晚的一侧胜出', () {
      final a = PlanDevice('a');
      final b = PlanDevice('b');
      for (final device in [a, b]) {
        device.put(diaryRecord('d'));
        device.commit(1000);
      }
      // a 置顶并同步给 b，之后 a 又取消置顶。
      a
        ..put(diaryRecord('d', pinned: true))
        ..commit(2000);
      final first = planBetween(a, b);
      a.applyAndCommit(first.plan.local, 3000);
      b.applyAndCommit(first.plan.remote, 3000);
      a
        ..put(diaryRecord('d'))
        ..commit(4000);
      final run = planBetween(b, a);
      expect(
        facetOf(
          writeFor(run.plan, SyncSideRole.local, diaryKey('d')),
          SyncFacet.pin,
        ),
        {'pinned': false},
      );
    });

    test('一侧缺少分面：有值的一侧胜出（从不删分面）', () {
      final a = PlanDevice('a', settings: true);
      final b = PlanDevice('b', settings: true);
      a.put(settingsRecord({'themeMode': 'dark', 'fontScale': 1.0}));
      b.put(settingsRecord({'themeMode': 'dark'}));
      a.commit(1000);
      b.commit(1000);
      final run = planBetween(a, b);
      expect(run.plan.local.writes, isEmpty);
      final write = writeFor(run.plan, SyncSideRole.remote, settingsKey)!;
      expect(write.record!.facets['fontScale'], {'value': 1.0});
    });
  });

  group('其余分面的真冲突', () {
    test('变化发现时间较新的一侧胜出', () {
      final (a, b) = forkDevices(
        [notebookRecord('n')],
        [notebookRecord('n', name: 'mine')],
        [notebookRecord('n', name: 'theirs')],
        leftAt: 9000,
        rightAt: 7000,
      );
      final run = planBetween(a, b);
      final write = writeFor(run.plan, SyncSideRole.remote, notebookKey('n'))!;
      expect(
        (write.record!.facets[SyncFacet.definition]! as Map)['name'],
        'mine',
      );
      expect(run.plan.local.writes, isEmpty);
    });

    test('都没有历史时按记录自身的时间字段', () {
      final a = PlanDevice('a')
        ..put(anniversaryRecord('x', title: 'old', updatedAt: 9000));
      final b = PlanDevice('b')
        ..put(anniversaryRecord('x', title: 'new', updatedAt: 12000));
      a.commit(1);
      b.commit(1);
      final run = planBetween(a, b);
      final write = writeFor(
        run.plan,
        SyncSideRole.local,
        anniversaryKey('x'),
      )!;
      expect((write.record!.facets[SyncFacet.main]! as Map)['title'], 'new');
    });

    test('平手按 deviceId 字典序较大者', () {
      final a = PlanDevice('zz')..put(tagRecord('t', color: 1));
      final b = PlanDevice('aa')..put(tagRecord('t', color: 2));
      a.commit(1);
      b.commit(1);
      final run = planBetween(a, b);
      expect(run.plan.local.writes, isEmpty);
      expect(
        writeFor(
          run.plan,
          SyncSideRole.remote,
          tagKey('t'),
        )!.record!.facets[SyncFacet.color],
        {'color': 1},
      );
    });
  });

  group('冲突副本 id', () {
    test('UUIDv5 与 RFC 4122 的已知向量一致', () {
      expect(
        syncUuidV5('6ba7b810-9dad-11d1-80b4-00c04fd430c8', 'www.example.com'),
        '2ed6657d-e927-568b-95e1-2665a8aea6a2',
      );
    });

    test('只由原 id 与败方正文哈希决定', () {
      final id = syncConflictCopyId('d', 'abc');
      expect(id, syncConflictCopyId('d', 'abc'));
      expect(id, isNot(syncConflictCopyId('d', 'abd')));
      expect(
        id,
        matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab]')),
      );
    });
  });

  test('媒体候选：只列写入记录里哈希有变化的分面引用的媒体键', () {
    const old = 'jotsy-media:diary_images/old.jpg';
    const fresh = 'jotsy-media:diary_images/new.jpg';
    final (a, b) = forkDevices(
      [
        diaryRecord('d', metadata: {'cover': old}),
      ],
      [
        diaryRecord('d', body: fresh, metadata: {'cover': old}),
      ],
      [],
    );
    a
      ..put(diaryRecord('e', body: 'jotsy-media:diary_images/e.jpg'))
      ..commit(7000);
    final plan = planBetween(a, b).plan;
    // d 的 content 分面整体变了，旧图仍在其中（写入层按 sha256 核对后只传缺的）。
    expect(plan.remote.mediaNeeded, [
      'diary_images/e.jpg',
      'diary_images/new.jpg',
      'diary_images/old.jpg',
    ]);
    expect(plan.local.mediaNeeded, isEmpty);
    expect(
      plan.remote.stats[SyncEntity.diary],
      const SyncEntityCounts(added: 1, updated: 1),
    );
  });

  test('采纳的分面继承来源一侧的确立时间，合并出的新值不继承', () {
    final (a, b) = forkDevices(
      [
        diaryRecord('d', tags: ['x']),
      ],
      [
        diaryRecord('d', pinned: true, tags: ['x', 'y']),
      ],
      [
        diaryRecord('d', tags: ['x', 'z']),
      ],
      leftAt: 4000,
      rightAt: 6000,
    );
    final run = planBetween(a, b);
    expect(run.plan.remote.historySeenAt[diaryKey('d')], {SyncFacet.pin: 4000});
    expect(run.plan.local.historySeenAt[diaryKey('d')], isNull);
  });
}
