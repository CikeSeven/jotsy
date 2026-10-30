import 'dart:math';

import 'sync_planner_sim_apply.dart';
import 'sync_planner_sim_replica.dart';

/// 收敛模拟里用户在一台设备上的操作，带上应用自己的连带效果：删日记清理
/// 成员 / 留言 / 纪念日关联，删标签从日记上摘掉，删日记本把子本提到上一层、
/// 删掉成员关系，删章节让其中的日记回到“未分章”，移动日记本前校验层级。
class SimOps {
  SimOps(this.random, this.clock);

  final Random random;

  /// 全局时钟（毫秒，1000 的倍数）。
  final int Function() clock;
  int _serial = 0;

  static const List<String> tagPool = <String>[
    'work', 'life', 'idea', 'trip', 'book', 'food', 'note', 'misc', //
  ];
  static const List<String> chapterPool = <String>['c1', 'c2', 'c3'];

  /// 每次编辑写进正文的唯一标记（检查“不丢编辑”）。
  String token(SimReplica r) => '${r.name}#${++_serial}';

  T _pick<T>(Iterable<T> items) =>
      items.elementAt(random.nextInt(items.length));

  int _now(SimReplica r) => clock() + r.skew;

  /// 随机做一次操作；返回操作名（调试用）。
  String randomOp(SimReplica r) {
    final roll = random.nextInt(100);
    if (roll < 10 || r.diaries.isEmpty) return newDiary(r);
    if (roll < 26) return editDiary(r, _pick(r.diaries.keys));
    if (roll < 32) return toggleDiaryFlag(r);
    if (roll < 40) return changeDiaryTags(r);
    if (roll < 44) return deleteDiary(r);
    if (roll < 50) return tagOp(r);
    if (roll < 60) return notebookOp(r);
    if (roll < 72) return memberOp(r);
    if (roll < 84) return commentOp(r);
    if (roll < 92) return anniversaryOp(r);
    return reorderOp(r);
  }

  String newDiary(SimReplica r) {
    final id = '${r.name}-d${++_serial}';
    final diary = SimDiary(id, r.nextLocalId())
      ..title = token(r)
      ..createdAt = _now(r)
      ..updatedAt = _now(r);
    diary.body = <String, Object?>{'body': diary.title};
    if (r.tags.isNotEmpty && random.nextBool()) {
      diary.tagIds.add(_pick(r.tags.keys));
    }
    r.diaries[id] = diary;
    final manual = r.notebooks.values.where((n) => n.kind == 'manual');
    if (manual.isNotEmpty && random.nextInt(3) == 0) {
      _addMember(r, _pick(manual), id);
    }
    return 'newDiary $id';
  }

  String editDiary(SimReplica r, String id) {
    final diary = r.diaries[id]!;
    final text = token(r);
    diary
      ..title = text
      ..body = <String, Object?>{'body': text}
      ..updatedAt = _now(r);
    return 'edit $id';
  }

  String toggleDiaryFlag(SimReplica r) {
    final diary = r.diaries[_pick(r.diaries.keys)]!;
    switch (random.nextInt(3)) {
      case 0:
        diary.pinned = !diary.pinned;
      case 1:
        diary.archived = !diary.archived;
        diary.archivedAt = diary.archived ? _now(r) : null;
      default:
        diary.deleted = !diary.deleted;
        diary.deletedAt = diary.deleted ? _now(r) : null;
    }
    return 'flag ${diary.id}';
  }

  String changeDiaryTags(SimReplica r) {
    if (r.tags.isEmpty) return newTag(r);
    final diary = r.diaries[_pick(r.diaries.keys)]!;
    final tag = _pick(r.tags.keys);
    if (!diary.tagIds.remove(tag)) diary.tagIds.add(tag);
    return 'tags ${diary.id}';
  }

  String deleteDiary(SimReplica r) {
    final id = _pick(r.diaries.keys);
    simHardDeleteDiary(r, id);
    return 'delete $id';
  }

  String newTag(SimReplica r) {
    final name = _pick(tagPool);
    if (r.tagNamed(name) != null) return 'noop';
    final tag = SimTag(r.nextLocalId(), name, random.nextInt(4));
    r.tags[tag.localId] = tag;
    return 'newTag $name';
  }

  String tagOp(SimReplica r) {
    if (r.tags.isEmpty || random.nextInt(4) == 0) return newTag(r);
    final tag = r.tags[_pick(r.tags.keys)]!;
    switch (random.nextInt(3)) {
      case 0:
        final name = _pick(tagPool);
        if (r.tagNamed(name) != null) return 'noop';
        final old = tag.name;
        tag.name = name;
        return 'renameTag $old -> $name';
      case 1:
        tag.color = (tag.color + 1) % 4;
        return 'recolor ${tag.name}';
      default:
        r.tags.remove(tag.localId);
        for (final diary in r.diaries.values) {
          diary.tagIds.remove(tag.localId);
        }
        return 'deleteTag ${tag.name}';
    }
  }

  String notebookOp(SimReplica r) {
    final roll = random.nextInt(10);
    if (roll < 3 || r.notebooks.isEmpty) return newNotebook(r);
    final notebook = r.notebooks[_pick(r.notebooks.keys)]!;
    if (roll < 5) {
      notebook
        ..name = token(r)
        ..updatedAt = _now(r);
      return 'renameNotebook ${notebook.id}';
    }
    if (roll < 7 && notebook.kind == 'manual') {
      final chapter = _pick(chapterPool);
      if (notebook.chapters.remove(chapter)) {
        for (final entry in r.members.entries) {
          if (entry.key.startsWith('${notebook.id}|') &&
              entry.value.chapterId == chapter) {
            entry.value.chapterId = null;
          }
        }
      } else {
        notebook.chapters.add(chapter);
      }
      notebook.updatedAt = _now(r);
      return 'chapter ${notebook.id}';
    }
    if (roll < 9) return moveNotebook(r, notebook);
    return deleteNotebook(r, notebook);
  }

  String newNotebook(SimReplica r) {
    final id = '${r.name}-n${++_serial}';
    final notebook = SimNotebook(id, r.nextLocalId())
      ..name = token(r)
      ..kind = random.nextInt(5) == 0 ? 'smart' : 'manual'
      ..visibility = random.nextInt(4) == 0 ? 'hidden' : 'normal'
      ..createdAt = _now(r)
      ..updatedAt = _now(r)
      ..sortOrder = r.notebooks.length;
    if (notebook.kind == 'manual' && random.nextBool()) {
      notebook.chapters.add(_pick(chapterPool));
    }
    r.notebooks[id] = notebook;
    return 'newNotebook $id';
  }

  /// 应用的移动校验：上级是存在的手动本、不是自己或子孙、移过去不超过 3 层。
  String moveNotebook(SimReplica r, SimNotebook notebook) {
    final candidates = <String?>[
      null,
      for (final n in r.notebooks.values)
        if (n.kind == 'manual' && n.id != notebook.id) n.id,
    ];
    final target = _pick(candidates);
    if (target != null) {
      if (_isDescendant(r, target, notebook.id)) return 'noop';
      if (_depth(r, target) + _height(r, notebook.id) > 3) return 'noop';
    }
    notebook
      ..parentId = target
      ..updatedAt = _now(r);
    return 'move ${notebook.id} -> $target';
  }

  bool _isDescendant(SimReplica r, String id, String ancestor) {
    String? current = id;
    final seen = <String>{};
    while (current != null && seen.add(current)) {
      if (current == ancestor) return true;
      current = r.notebooks[current]?.parentId;
    }
    return false;
  }

  int _depth(SimReplica r, String id) {
    var depth = 1;
    var current = r.notebooks[id]?.parentId;
    while (current != null && depth < 10) {
      depth++;
      current = r.notebooks[current]?.parentId;
    }
    return depth;
  }

  int _height(SimReplica r, String id) {
    var height = 1;
    for (final child in r.notebooks.values.where((n) => n.parentId == id)) {
      height = max(height, _height(r, child.id) + 1);
    }
    return height;
  }

  /// 删除日记本：子本整棵提到上一层，成员关系删掉（日记不删）。
  String deleteNotebook(SimReplica r, SimNotebook notebook) {
    r.notebooks.remove(notebook.id);
    for (final child in r.notebooks.values) {
      if (child.parentId == notebook.id) {
        child
          ..parentId = notebook.parentId
          ..updatedAt = _now(r);
      }
    }
    r.members.removeWhere((key, _) => key.startsWith('${notebook.id}|'));
    return 'deleteNotebook ${notebook.id}';
  }

  void _addMember(SimReplica r, SimNotebook notebook, String diaryId) {
    final key = SimReplica.memberId(notebook.id, diaryId);
    if (r.members.containsKey(key)) return;
    final chapter = notebook.chapters.isNotEmpty && random.nextBool()
        ? _pick(notebook.chapters)
        : null;
    final last = r.members.entries
        .where((e) => e.key.startsWith('${notebook.id}|'))
        .fold<int>(-1, (m, e) => max(m, e.value.position));
    r.members[key] = SimMember(chapter, _now(r), last + 1);
  }

  String memberOp(SimReplica r) {
    final manual = r.notebooks.values.where((n) => n.kind == 'manual');
    if (manual.isEmpty) return newNotebook(r);
    final notebook = _pick(manual);
    final mine = r.members.keys
        .where((key) => key.startsWith('${notebook.id}|'))
        .toList();
    final roll = random.nextInt(3);
    if (roll == 0 || mine.isEmpty) {
      _addMember(r, notebook, _pick(r.diaries.keys));
      return 'addMember ${notebook.id}';
    }
    final key = _pick(mine);
    if (roll == 1) {
      r.members.remove(key);
      return 'removeMember $key';
    }
    r.members[key]!.chapterId = notebook.chapters.isEmpty
        ? null
        : _pick(<String?>[null, ...notebook.chapters]);
    return 'chapterMember $key';
  }

  String commentOp(SimReplica r) {
    final roll = random.nextInt(3);
    if (roll == 0 || r.comments.isEmpty) {
      final id = '${r.name}-c${++_serial}';
      r.comments[id] = SimComment(
        _pick(r.diaries.keys),
        token(r),
        _now(r),
        null,
      );
      return 'newComment $id';
    }
    final id = _pick(r.comments.keys);
    if (roll == 1) {
      r.comments[id]!
        ..content = token(r)
        ..editedAt = _now(r);
      return 'editComment $id';
    }
    r.comments.remove(id);
    return 'deleteComment $id';
  }

  String anniversaryOp(SimReplica r) {
    final roll = random.nextInt(4);
    if (roll == 0 || r.anniversaries.isEmpty) {
      final id = '${r.name}-a${++_serial}';
      r.anniversaries[id] = SimAnniversary(
        token(r),
        random.nextBool() ? _pick(r.diaries.keys) : null,
        _now(r),
      );
      return 'newAnniversary $id';
    }
    final id = _pick(r.anniversaries.keys);
    final anniversary = r.anniversaries[id]!;
    switch (roll) {
      case 1:
        anniversary.title = token(r);
      case 2:
        anniversary.linkedDiaryId = random.nextBool()
            ? _pick(r.diaries.keys)
            : null;
      default:
        r.anniversaries.remove(id);
        return 'deleteAnniversary $id';
    }
    anniversary.updatedAt = _now(r);
    return 'editAnniversary $id';
  }

  String reorderOp(SimReplica r) {
    if (random.nextBool() && r.notebooks.isNotEmpty) {
      final order = r.notebooks.values.toList()..shuffle(random);
      for (var i = 0; i < order.length; i++) {
        order[i].sortOrder = i;
      }
      return 'reorderShelf';
    }
    final manual = r.notebooks.values.where((n) => n.kind == 'manual');
    if (manual.isEmpty) return 'noop';
    final notebook = _pick(manual);
    final rows =
        r.members.entries
            .where((e) => e.key.startsWith('${notebook.id}|'))
            .map((e) => e.value)
            .toList()
          ..shuffle(random);
    for (var i = 0; i < rows.length; i++) {
      rows[i].position = i;
    }
    return 'reorderBook ${notebook.id}';
  }
}
