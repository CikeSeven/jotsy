import 'package:flutter/foundation.dart';

import 'diary_export_entry.dart';

/// 导出成书：把一本日记本导出为带扉页、目录与章节标题的一份文档。
///
/// 两层数据：
/// - [DiaryExportBook] 是入口（日记本）交来的“书的结构”：书名、简介、封面与
///   按成书顺序排好的章节（每章是日记 id 列表，最后一组是“未分章”）。它不知道
///   哪些日记会因未解封的胶囊被跳过，所以不带篇数与时间跨度；
/// - [DiaryExportBookLayout] 是导出控制器按实际导出的日记解析出的版式：空章节
///   已去掉，“未分章”只在还有别的章节时作为标题出现，扉页的统计行（时间跨度
///   与篇数）与导出日期按这次导出算好，写出器只读不改。
///
/// 纯数据，无 IO；封面只是来源路径，写出器经媒体库读取（内嵌或打包），导出
/// 文件里不出现设备路径。

/// 书里的一章：[title] 为 null 时是“未分章”那一组。
@immutable
class DiaryExportBookChapter {
  DiaryExportBookChapter({this.title, required Iterable<String> diaryIds})
    : diaryIds = List<String>.unmodifiable(diaryIds);

  final String? title;

  /// 本章日记的业务 id，按书中的先后。
  final List<String> diaryIds;
}

/// 一本待导出的书（见文件顶部注释）。
@immutable
class DiaryExportBook {
  DiaryExportBook({
    required this.title,
    String description = '',
    String? coverPath,
    required Iterable<DiaryExportBookChapter> chapters,
  }) : description = description.trim(),
       coverPath = coverPath == null || coverPath.trim().isEmpty
           ? null
           : coverPath.trim(),
       chapters = List<DiaryExportBookChapter>.unmodifiable(chapters);

  /// 书名（日记本名称），也是导出文件名与文档标题。
  final String title;

  /// 简介，可能为空字符串。
  final String description;

  /// 封面图片来源；没有封面为 null。
  final String? coverPath;

  /// 按成书顺序排好的章节，可能含空章节（解析版式时去掉）。
  final List<DiaryExportBookChapter> chapters;

  /// 全书日记 id，按书中的先后。
  List<String> get diaryIds => <String>[
    for (final chapter in chapters) ...chapter.diaryIds,
  ];

  /// 把 [items] 按书中的先后排好：书里没有的项（不应出现，防御）按原顺序
  /// 接在最后；同一个 id 只保留第一次出现的那项。
  List<T> arrange<T>(Iterable<T> items, String Function(T item) idOf) {
    final byId = <String, T>{};
    for (final item in items) {
      byId.putIfAbsent(idOf(item), () => item);
    }
    final placed = <String>{};
    final arranged = <T>[];
    for (final id in diaryIds) {
      final item = byId[id];
      if (item != null && placed.add(id)) {
        arranged.add(item);
      }
    }
    for (final item in items) {
      if (placed.add(idOf(item))) {
        arranged.add(item);
      }
    }
    return arranged;
  }
}

/// 成书用到的界面文案，由调用方按当前语言构造（见 `buildDiaryExportLabels`）。
@immutable
class DiaryExportBookLabels {
  const DiaryExportBookLabels({
    required this.contents,
    required this.unassignedChapter,
    required this.summary,
    required this.exportedOn,
  });

  /// 目录标题“目录”。
  final String contents;

  /// 没有章节的日记那一组的标题“未分章”。
  final String unassignedChapter;

  /// 扉页统计行：“2023年5月 – 2026年10月 · 23 篇”（本地时间）。
  final String Function(DateTime first, DateTime last, int count) summary;

  /// 扉页导出日期：“导出于 2026年10月19日”。
  final String Function(DateTime value) exportedOn;
}

/// 版式里的一章：[title] 为 null 时不写章节标题（全书没有章节时只有这一组）。
@immutable
class DiaryExportBookSection {
  DiaryExportBookSection({
    required this.title,
    required this.anchor,
    required Iterable<DiaryExportEntry> entries,
  }) : entries = List<DiaryExportEntry>.unmodifiable(entries);

  final String? title;

  /// 章节标题的锚点名（`chapter-1` 起），目录链接到这里。
  final String anchor;
  final List<DiaryExportEntry> entries;
}

/// 按实际导出的日记解析出的成书版式（见文件顶部注释）。
@immutable
class DiaryExportBookLayout {
  const DiaryExportBookLayout._({
    required this.title,
    required this.description,
    required this.coverPath,
    required this.sections,
    required this.contentsTitle,
    required this.summaryLine,
    required this.exportedLine,
    required this._anchors,
  });

  /// 解析版式。
  ///
  /// - [entries] 是实际导出的日记（未解封的胶囊已去掉），顺序以书为准；
  /// - 每章只留下 [entries] 里有的日记，整章都没有时去掉这一章（连同标题）；
  ///   书里没有的日记（防御）并入最后的“未分章”；
  /// - 去掉空章后还有带名称的章节时，每组都写章节标题，“未分章”那一组用
  ///   [DiaryExportBookLabels.unassignedChapter]；否则全书不写任何章节标题；
  /// - 锚点按出现顺序编号：章节 `chapter-n`、日记 `entry-n`（HTML 的 id、
  ///   Markdown 的锚点、PDF 的命名目标都用它；Word 书签名不能含连字符，由
  ///   Word 写出器换成下划线）。
  factory DiaryExportBookLayout.resolve(
    DiaryExportBook book,
    List<DiaryExportEntry> entries, {
    required DiaryExportBookLabels labels,
    required DateTime exportedAt,
  }) {
    final byId = <String, DiaryExportEntry>{
      for (final entry in entries) entry.diaryId: entry,
    };
    final placed = <String>{};
    final groups = <({String? title, List<DiaryExportEntry> entries})>[];
    for (final chapter in book.chapters) {
      final members = <DiaryExportEntry>[
        for (final id in chapter.diaryIds)
          if (byId[id] != null && placed.add(id)) byId[id]!,
      ];
      if (members.isNotEmpty) {
        groups.add((title: chapter.title, entries: members));
      }
    }
    final leftovers = <DiaryExportEntry>[
      for (final entry in entries)
        if (placed.add(entry.diaryId)) entry,
    ];
    if (leftovers.isNotEmpty) {
      if (groups.isNotEmpty && groups.last.title == null) {
        groups.last.entries.addAll(leftovers);
      } else {
        groups.add((title: null, entries: leftovers));
      }
    }

    final headings = groups.any((group) => group.title != null);
    final sections = <DiaryExportBookSection>[];
    if (headings) {
      for (var i = 0; i < groups.length; i++) {
        sections.add(
          DiaryExportBookSection(
            title: groups[i].title ?? labels.unassignedChapter,
            anchor: 'chapter-${i + 1}',
            entries: groups[i].entries,
          ),
        );
      }
    } else if (groups.isNotEmpty) {
      sections.add(
        DiaryExportBookSection(
          title: null,
          anchor: 'chapter-1',
          entries: <DiaryExportEntry>[
            for (final group in groups) ...group.entries,
          ],
        ),
      );
    }

    final anchors = <String, String>{};
    DateTime? first;
    DateTime? last;
    for (final section in sections) {
      for (final entry in section.entries) {
        anchors[entry.diaryId] = 'entry-${anchors.length + 1}';
        final created = entry.createdAt.toLocal();
        if (first == null || created.isBefore(first)) first = created;
        if (last == null || created.isAfter(last)) last = created;
      }
    }
    final description = book.description.trim();
    return DiaryExportBookLayout._(
      title: book.title.trim(),
      description: description.isEmpty ? null : description,
      coverPath: book.coverPath,
      sections: List<DiaryExportBookSection>.unmodifiable(sections),
      contentsTitle: labels.contents,
      summaryLine: first == null || last == null
          ? ''
          : labels.summary(first, last, anchors.length),
      exportedLine: labels.exportedOn(exportedAt.toLocal()),
      anchors: Map<String, String>.unmodifiable(anchors),
    );
  }

  /// 书名（扉页大标题）。
  final String title;

  /// 简介；没有为 null。
  final String? description;

  /// 封面图片来源；没有为 null。
  final String? coverPath;
  final List<DiaryExportBookSection> sections;
  final String contentsTitle;

  /// 扉页统计行（时间跨度 · 篇数）；没有日记时为空字符串。
  final String summaryLine;

  /// 扉页导出日期行。
  final String exportedLine;
  final Map<String, String> _anchors;

  /// 是否写章节标题（目录同样按章分组）。
  bool get hasChapterHeadings =>
      sections.any((DiaryExportBookSection s) => s.title != null);

  /// 全书日记，按书中的先后。
  List<DiaryExportEntry> get entries => <DiaryExportEntry>[
    for (final section in sections) ...section.entries,
  ];

  int get entryCount => _anchors.length;

  /// 这篇日记的锚点名（`entry-n`）。
  String anchorOf(DiaryExportEntry entry) => _anchors[entry.diaryId]!;
}
