import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/pinyin/name_index.dart';
import '../../widgets/fast_scroller/fast_scroller.dart';

/// 首页快速滚动条的内容：整份列表每一篇的标签与轨道上的分段。
///
/// 输入：已加载的日记（列表前段，口径与卡片完全一致）、数据库给出的完整
/// 时间轴（列表还有没加载的部分时补上后段）、排序方式与成书顺序的章节名；
/// 输出：篇数 [length]、第 i 篇的气泡标签 [labelAt] 与分段 [sections]。
/// 纯数据，无副作用；标签按需生成，分段在构造时一次算好。
///
/// 按排序方式取标签：
/// - 按创建 / 更新时间：大字为月份、小字为年份；跨两年以上时分段为各年的
///   第一篇，都在同一年时为各月的第一篇；
/// - 按标题：首字母（汉字取拼音首字母，见 [NameIndexKey]），无标题的排在
///   最后、单独一段；
/// - 日记本成书顺序且有章节：大字为章节名（未分章的为“未分章”），小字为
///   这篇的年月，分段为各章；没有章节时按创建时间显示，不分段（书序不按
///   时间排列，年份刻度会来回跳）。
/// 置顶日记（成书顺序没有置顶）排在最前，气泡标为“置顶”，但不单独成段：
/// 它总在轨道最上端，刻度会挤掉紧挨着的第一个年份。
class DiaryTimelineIndex {
  DiaryTimelineIndex({
    required List<DiaryWithTags> loaded,
    required List<DiaryTimelineEntry>? timeline,
    required bool hasMore,
    required DiarySortMode sortMode,
    required bool bookOrder,
    required List<String> chapterTitles,
    required AppLocalizations l10n,
  }) : _loaded = loaded,
       // 还有没加载的部分时，后段取完整时间轴里同一位置之后的篇目（两者
       // 同一筛选与排序；归档、删除的乐观隐藏期间可能错开一两篇，只影响
       // 标签，不影响跳转）。
       _tail = hasMore && timeline != null && timeline.length > loaded.length
           ? timeline.sublist(loaded.length)
           : const <DiaryTimelineEntry>[],
       _chapterRanks = bookOrder && timeline != null
           ? <String, int?>{
               for (final entry in timeline) entry.diaryId: entry.chapterRank,
             }
           : const <String, int?>{},
       _mode = bookOrder
           ? (chapterTitles.isEmpty ? _Mode.bookDates : _Mode.chapters)
           : switch (sortMode.field) {
               DiarySortField.title => _Mode.title,
               DiarySortField.createdAt => _Mode.created,
               DiarySortField.updatedAt => _Mode.updated,
             },
       _chapterTitles = chapterTitles,
       _l10n = l10n,
       _month = DateFormat.MMM(l10n.localeName),
       _year = DateFormat.y(l10n.localeName),
       _yearMonth = DateFormat.yMMM(l10n.localeName) {
    _sections = _buildSections();
  }

  final List<DiaryWithTags> _loaded;
  final List<DiaryTimelineEntry> _tail;
  final Map<String, int?> _chapterRanks;
  final _Mode _mode;
  final List<String> _chapterTitles;
  final AppLocalizations _l10n;
  final DateFormat _month;
  final DateFormat _year;
  final DateFormat _yearMonth;
  late final List<FastScrollSection> _sections;

  int get length => _loaded.length + _tail.length;

  List<FastScrollSection> get sections => _sections;

  FastScrollLabel labelAt(int index) {
    final entry = _entryAt(index);
    if (entry.pinned && _mode != _Mode.chapters && _mode != _Mode.bookDates) {
      return FastScrollLabel(_l10n.diaryFastScrollPinned);
    }
    switch (_mode) {
      case _Mode.title:
        return FastScrollLabel(_titleKey(entry.title));
      case _Mode.chapters:
        final rank = entry.chapterRank;
        if (rank == null) {
          return _dateLabel(entry.created);
        }
        return FastScrollLabel(
          _chapterTitle(rank),
          caption: _yearMonth.format(entry.created),
        );
      case _Mode.created:
      case _Mode.bookDates:
        return _dateLabel(entry.created);
      case _Mode.updated:
        return _dateLabel(entry.updated);
    }
  }

  FastScrollLabel _dateLabel(DateTime date) =>
      FastScrollLabel(_month.format(date), caption: _year.format(date));

  String _chapterTitle(int rank) => rank < _chapterTitles.length
      ? _chapterTitles[rank]
      : _l10n.notebookChapterUnassigned;

  String _titleKey(String title) => title.trim().isEmpty
      ? _l10n.diaryFastScrollUntitled
      : NameIndexKey.of(title).letter;

  _Entry _entryAt(int index) {
    if (index < _loaded.length) {
      final diary = _loaded[index].diary;
      return _Entry(
        pinned: diary.isPinned,
        created: diary.createdAt.toLocal(),
        updated: diary.updatedAt.toLocal(),
        title: diary.title,
        chapterRank: _chapterRanks[diary.diaryId],
      );
    }
    final entry = _tail[index - _loaded.length];
    return _Entry(
      pinned: entry.isPinned,
      created: entry.createdAt.toLocal(),
      updated: entry.updatedAt.toLocal(),
      title: entry.title,
      chapterRank: entry.chapterRank,
    );
  }

  /// 分段：标签的“粗一级”变化处（年份、首字母、章节）各一段。
  List<FastScrollSection> _buildSections() {
    if (_mode == _Mode.bookDates) {
      return const <FastScrollSection>[];
    }
    final count = length;
    final entries = <_Entry>[for (var i = 0; i < count; i++) _entryAt(i)];
    final sections = <FastScrollSection>[];
    var start = 0;
    if (_mode != _Mode.chapters) {
      while (start < count && entries[start].pinned) {
        start++;
      }
    }
    // key 相同的相邻篇目属于同一段；key 为 null 的（章节还没查到）不分段。
    final String? Function(_Entry entry) keyOf;
    final String Function(_Entry entry) labelOf;
    switch (_mode) {
      case _Mode.title:
        keyOf = (entry) => _titleKey(entry.title);
        labelOf = (entry) => _titleKey(entry.title);
      case _Mode.chapters:
        keyOf = (entry) => entry.chapterRank == null
            ? null
            : _chapterTitle(entry.chapterRank!);
        labelOf = (entry) => keyOf(entry) ?? '';
      case _Mode.created:
      case _Mode.updated:
      case _Mode.bookDates:
        DateTime dateOf(_Entry entry) =>
            _mode == _Mode.updated ? entry.updated : entry.created;
        final years = <int>{
          for (var i = start; i < count; i++) dateOf(entries[i]).year,
        };
        if (years.length > 1) {
          keyOf = (entry) => '${dateOf(entry).year}';
          labelOf = (entry) => '${dateOf(entry).year}';
        } else {
          keyOf = (entry) => '${dateOf(entry).month}';
          labelOf = (entry) => _month.format(dateOf(entry));
        }
    }
    String? previous;
    for (var i = start; i < count; i++) {
      final key = keyOf(entries[i]);
      if (key == null || key == previous) {
        continue;
      }
      previous = key;
      sections.add(FastScrollSection(index: i, label: labelOf(entries[i])));
    }
    return sections;
  }
}

enum _Mode { created, updated, title, chapters, bookDates }

/// 一篇日记在时间轴上用到的字段（已加载的取自卡片数据，后段取自时间轴）。
class _Entry {
  const _Entry({
    required this.pinned,
    required this.created,
    required this.updated,
    required this.title,
    required this.chapterRank,
  });

  final bool pinned;
  final DateTime created;
  final DateTime updated;
  final String title;
  final int? chapterRank;
}
