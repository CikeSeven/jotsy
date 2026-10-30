import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';

import 'sync_planner_sim_apply.dart';
import 'sync_planner_sim_replica.dart';
import 'sync_planner_sim_world.dart';

/// 收敛模拟（规格 §4 的整体性质）：多台设备随机编辑、随机两两同步（含中断），
/// 最后一轮全量同步后：
/// (a) 所有设备的清单相同，且再同步一轮不产生任何写入；
/// (b) 没有冲突的编辑不丢（最后一阶段各设备改互不相交的日记、给同一篇日记
///     各加一个标签）；
/// (c) 冲突副本从不重复生成（含中断后重新规划）——[SimWorld.sync] 里断言；
/// (d) 删除沿 A → B → C 传播；
/// 以及每台设备的引用完整（成员指向存在的日记与手动本、章节有效、留言 /
/// 纪念日 / 日记标签不悬空、层级合法），写入层从不需要按名称补建标签。
///
/// 各设备时钟有 ±3 秒偏差；约 10% 的同步只有一侧写入（中断）；约 20% 的同步
/// 另与全知两侧的规划对拍；“丢失状态”一组随机清空某台设备的检查点、历史、
/// 墓碑与改名（覆盖恢复），之后与各设备的第一次同步走“以哪边为准”。
/// （开发时另以 200 个种子 × 3–5 台设备 × 600 步跑过，全部收敛。）
void main() {
  for (final (count, seeds, lose) in <(int, int, bool)>[
    (2, 3, false),
    (3, 6, false),
    (3, 3, true),
    (4, 2, true),
  ]) {
    for (var seed = 0; seed < seeds; seed++) {
      final label = lose ? '，含丢失状态' : '';
      test('$count 台设备随机编辑与同步后收敛（seed $seed$label）', () {
        final world = SimWorld(seed * 7919 + count + (lose ? 1 : 0), count)
          ..loseState = lose;
        for (var i = 0; i < 300; i++) {
          world.step();
        }
        world.converge();
        _expectStable(world);
        _finalPhase(world);
        for (final replica in world.replicas) {
          _expectIntegrity(replica);
        }
        // ignore: avoid_print
        print(
          'seed $seed × $count: ${world.syncs} 次同步（${world.interrupted} 次'
          '中断，${world.fullCompares} 次全知对拍），${world.fetchRounds} 轮取数，'
          '${world.listedCopies.length} 份冲突副本，${world.renameOps} 次原地'
          '改名，${world.lostStates} 次丢失状态，'
          '${world.replicas.first.diaries.length} 篇日记',
        );
      });
    }
  }
}

void _expectStable(SimWorld world) {
  final r = world.replicas;
  for (var i = 0; i < r.length; i++) {
    for (var j = i + 1; j < r.length; j++) {
      final plan = world.sync(r[i], r[j]);
      expect(plan.isEmpty, isTrue, reason: '收敛后再同步不应有写入');
    }
  }
}

/// 最后一阶段：每台设备改互不相交的一批日记、给同一篇共享日记各加一个
/// 新标签、第一台删一篇别人不碰的日记；先按链 A → B → C 同步，再全量同步。
void _finalPhase(SimWorld world) {
  final replicas = world.replicas;
  final ids = replicas.first.diaries.keys.toList()..sort();
  if (ids.length < replicas.length + 2) {
    for (final replica in replicas) {
      world.ops.newDiary(replica);
    }
    world.converge();
    ids
      ..clear()
      ..addAll(replicas.first.diaries.keys.toList()..sort());
  }
  final shared = ids.removeAt(0);
  final doomed = ids.removeAt(0);
  final expectedTitles = <String, String>{};
  final addedTags = <String>[];
  for (var i = 0; i < replicas.length; i++) {
    final replica = replicas[i];
    world.tick();
    for (var k = i; k < ids.length; k += replicas.length) {
      world.ops.editDiary(replica, ids[k]);
      expectedTitles[ids[k]] = replica.diaries[ids[k]]!.title;
    }
    final name = 'only-${replica.name}';
    final tag = SimTag(replica.nextLocalId(), name, 9);
    replica.tags[tag.localId] = tag;
    replica.diaries[shared]!.tagIds.add(tag.localId);
    addedTags.add(name);
  }
  simHardDeleteDiary(replicas.first, doomed);
  for (var i = 0; i + 1 < replicas.length; i++) {
    world.sync(replicas[i], replicas[i + 1]);
  }
  final last = replicas.last;
  expect(last.diaries.containsKey(doomed), isFalse, reason: '删除应沿链传播');
  world.converge();
  _expectStable(world);
  for (final replica in replicas) {
    for (final entry in expectedTitles.entries) {
      expect(
        replica.diaries[entry.key]?.title,
        entry.value,
        reason: '没有冲突的编辑不应丢失',
      );
    }
    final names = <String>{
      for (final id in replica.diaries[shared]!.tagIds) replica.tags[id]!.name,
    };
    expect(names, containsAll(addedTags), reason: '不同设备加的标签都应保留');
    expect(replica.diaries.containsKey(doomed), isFalse);
  }
}

void _expectIntegrity(SimReplica r) {
  expect(r.unexpectedTags, 0, reason: '写入层不应按名称补建计划里没有的标签');
  for (final diary in r.diaries.values) {
    for (final id in diary.tagIds) {
      expect(r.tags.containsKey(id), isTrue);
    }
  }
  for (final entry in r.members.entries) {
    final ids = parseSyncMembershipId(entry.key)!;
    final notebook = r.notebooks[ids.notebookId];
    expect(r.diaries.containsKey(ids.diaryId), isTrue, reason: entry.key);
    expect(notebook?.kind, 'manual', reason: entry.key);
    final chapter = entry.value.chapterId;
    if (chapter != null) {
      expect(notebook!.chapters, contains(chapter), reason: entry.key);
    }
  }
  for (final comment in r.comments.values) {
    expect(r.diaries.containsKey(comment.diaryId), isTrue);
  }
  for (final anniversary in r.anniversaries.values) {
    final linked = anniversary.linkedDiaryId;
    if (linked != null) expect(r.diaries.containsKey(linked), isTrue);
  }
  for (final notebook in r.notebooks.values) {
    var depth = 1;
    final seen = <String>{notebook.id};
    var parent = notebook.parentId;
    while (parent != null) {
      final row = r.notebooks[parent];
      expect(row?.kind, 'manual', reason: '上级须是存在的手动本');
      expect(seen.add(parent), isTrue, reason: '层级不能成环');
      depth++;
      parent = row!.parentId;
    }
    expect(depth, lessThanOrEqualTo(3));
  }
}
