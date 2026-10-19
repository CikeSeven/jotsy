import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// 章节与成书顺序的纯数据换算：章节胶囊的篇数、首页书序分隔行的归属、目录页
/// 的扁平列表与拖动落点。无副作用，便于单测。
///
/// “未分章”的口径与数据库层一致：`chapter_id` 为空，或指向已不在章节列表里
/// 的章节（章节刚被删、清理还没推送回来时）。

/// 目录与排序里一篇日记的位置：日记 id 与它（有效的）章节，null 为未分章。
typedef NotebookEntryPlacement = ({String diaryId, String? chapterId});

/// [chapterId] 仍是 [chapters] 之一时原样返回，否则为 null（未分章）。
String? validNotebookChapterId(
  List<NotebookChapter> chapters,
  String? chapterId,
) {
  if (chapterId == null) return null;
  for (final chapter in chapters) {
    if (chapter.id == chapterId) return chapterId;
  }
  return null;
}

/// 每章的篇数（首页列表口径，见 `watchNotebookEntryChapters`）。
@immutable
class NotebookChapterCounts {
  const NotebookChapterCounts._(this._byChapter, this.unassigned, this.total);

  factory NotebookChapterCounts.from(
    List<NotebookChapter> chapters,
    Map<String, String?> entryChapters,
  ) {
    final byChapter = <String, int>{};
    var unassigned = 0;
    for (final raw in entryChapters.values) {
      final chapterId = validNotebookChapterId(chapters, raw);
      if (chapterId == null) {
        unassigned++;
      } else {
        byChapter[chapterId] = (byChapter[chapterId] ?? 0) + 1;
      }
    }
    return NotebookChapterCounts._(byChapter, unassigned, entryChapters.length);
  }

  final Map<String, int> _byChapter;
  final int unassigned;
  final int total;

  int of(String chapterId) => _byChapter[chapterId] ?? 0;
}

/// 目录页的一项：章节标题行或日记行。
@immutable
sealed class NotebookContentsItem {
  const NotebookContentsItem();

  /// 列表项的稳定 key（拖动排序要求每项唯一）。
  String get key;
}

/// 章节标题行；[chapter] 为 null 时是“未分章”。
final class NotebookContentsHeader extends NotebookContentsItem {
  const NotebookContentsHeader({required this.chapter, required this.count});

  final NotebookChapter? chapter;
  final int count;

  @override
  String get key => 'chapter_${chapter?.id ?? '_unassigned'}';
}

/// 日记行；[chapterId] 为它（有效的）章节，null 为未分章。
final class NotebookContentsRow extends NotebookContentsItem {
  const NotebookContentsRow({required this.entry, required this.chapterId});

  final NotebookContentsEntry entry;
  final String? chapterId;

  @override
  String get key => 'entry_${entry.diaryId}';
}

/// 成书顺序下每篇日记的位置：各章按章节列表的先后、章内按成书位置
/// （[entries] 已按 position 排好），未分章的在最后。
List<NotebookEntryPlacement> notebookBookPlacements(
  List<NotebookChapter> chapters,
  List<NotebookContentsEntry> entries,
) {
  final byChapter = <String?, List<NotebookContentsEntry>>{};
  for (final entry in entries) {
    byChapter
        .putIfAbsent(
          validNotebookChapterId(chapters, entry.chapterId),
          () => <NotebookContentsEntry>[],
        )
        .add(entry);
  }
  return <NotebookEntryPlacement>[
    for (final chapter in chapters)
      for (final entry in byChapter[chapter.id] ?? const [])
        (diaryId: entry.diaryId, chapterId: chapter.id),
    for (final entry in byChapter[null] ?? const <NotebookContentsEntry>[])
      (diaryId: entry.diaryId, chapterId: null),
  ];
}

/// 目录页的扁平列表。
///
/// - 没有章节：只有日记行；
/// - 有章节：每章标题行（没有日记的章节也显示，好往里拖）后接它的日记，
///   最后总是“未分章”标题行（没有未分章日记时也在，作为拖出章节的落点）与
///   这些日记。
///
/// [pending] 是刚拖完、数据库还没推送回来的顺序：按它排列并改用其中的章节
/// （其中没有的日记——拖动途中别处新加入的——接在后面，保持原来的位置）。
List<NotebookContentsItem> buildNotebookContents(
  List<NotebookChapter> chapters,
  List<NotebookContentsEntry> entries, {
  List<NotebookEntryPlacement>? pending,
}) {
  final byId = <String, NotebookContentsEntry>{
    for (final entry in entries) entry.diaryId: entry,
  };
  final placements = <NotebookEntryPlacement>[];
  if (pending != null) {
    final placed = <String>{};
    for (final placement in pending) {
      if (byId.containsKey(placement.diaryId) &&
          placed.add(placement.diaryId)) {
        placements.add((
          diaryId: placement.diaryId,
          chapterId: validNotebookChapterId(chapters, placement.chapterId),
        ));
      }
    }
    for (final placement in notebookBookPlacements(chapters, entries)) {
      if (!placed.contains(placement.diaryId)) placements.add(placement);
    }
  } else {
    placements.addAll(notebookBookPlacements(chapters, entries));
  }

  NotebookContentsRow row(NotebookEntryPlacement placement) =>
      NotebookContentsRow(
        entry: byId[placement.diaryId]!,
        chapterId: placement.chapterId,
      );

  if (chapters.isEmpty) {
    return <NotebookContentsItem>[for (final p in placements) row(p)];
  }
  final grouped = <String?, List<NotebookEntryPlacement>>{};
  for (final placement in placements) {
    grouped
        .putIfAbsent(placement.chapterId, () => <NotebookEntryPlacement>[])
        .add(placement);
  }
  final unassigned = grouped[null] ?? const <NotebookEntryPlacement>[];
  return <NotebookContentsItem>[
    for (final chapter in chapters) ...<NotebookContentsItem>[
      NotebookContentsHeader(
        chapter: chapter,
        count: grouped[chapter.id]?.length ?? 0,
      ),
      for (final p in grouped[chapter.id] ?? const <NotebookEntryPlacement>[])
        row(p),
    ],
    // “未分章”标题始终在最后：它也是拖出章节的落点，空着时同样显示。
    NotebookContentsHeader(chapter: null, count: unassigned.length),
    for (final p in unassigned) row(p),
  ];
}

/// 把 [oldIndex] 的日记行拖到 [newIndex]（`onReorderItem` 语义：已按移除后的
/// 列表修正）后，全部日记的新顺序与章节。
///
/// 每篇日记归属它上方最近的标题行（落在列表末尾“未分章”标题之后即移出
/// 章节）；落在第一个标题行之上（只可能是拖到列表最顶端）时归第一章。标题行本身不能拖，[oldIndex] 不是日记行时原样返回。
List<NotebookEntryPlacement> resolveNotebookContentsDrop(
  List<NotebookContentsItem> items,
  int oldIndex,
  int newIndex,
) {
  final next = <NotebookContentsItem>[...items];
  if (next[oldIndex] is NotebookContentsRow) {
    next.insert(newIndex, next.removeAt(oldIndex));
  }
  NotebookChapter? firstChapter;
  for (final item in next) {
    if (item is NotebookContentsHeader) {
      firstChapter = item.chapter;
      break;
    }
  }
  var seenHeader = false;
  String? current;
  final result = <NotebookEntryPlacement>[];
  for (final item in next) {
    switch (item) {
      case NotebookContentsHeader(:final chapter):
        seenHeader = true;
        current = chapter?.id;
      case NotebookContentsRow(:final entry):
        result.add((
          diaryId: entry.diaryId,
          chapterId: seenHeader ? current : firstChapter?.id,
        ));
    }
  }
  return result;
}

/// 两组位置是否完全一致（判断数据库是否已推送拖动后的顺序）。
bool sameNotebookPlacements(
  List<NotebookEntryPlacement> a,
  List<NotebookEntryPlacement> b,
) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
