import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/utils/pinyin/name_index.dart';

import '../models/tag_picker_sort.dart';

/// 标签子页里的一组：按字母排序时 [letter] 是分组字母（`A`–`Z` 或 `#`），
/// 默认排序时为 null（整份列表一组、不显示分组标题）。
class TagPickerSection {
  const TagPickerSection(this.letter, this.tags);

  final String? letter;
  final List<Tag> tags;
}

/// 发布面板标签子页的显示数据：按检索词筛选，再按排序方式排好、分组。
///
/// 输入是 `tagListProvider` 给出的标签（已是用户在标签管理里的顺序），
/// 默认排序原样保留该顺序；按字母时经 [NameIndexKey] 按拼音归入 A–Z，
/// 同键再按名称、id 兜底，顺序稳定。纯计算，每次输入或标签变化时重建。
class TagPickerView {
  const TagPickerView._({
    required this.query,
    required this.sections,
    required this.hasExactMatch,
  });

  factory TagPickerView.of(
    List<Tag> tags, {
    required TagPickerSort sort,
    required String query,
  }) {
    final trimmed = query.trim();
    final normalized = normalizeNameQuery(trimmed);
    final needsKeys = sort == TagPickerSort.alphabetical || !normalized.isEmpty;
    final keyed = <(Tag, NameIndexKey?)>[
      for (final tag in tags)
        (tag, needsKeys ? NameIndexKey.of(tag.name) : null),
    ].where((entry) => entry.$2?.matches(normalized) ?? true).toList();

    final folded = foldNameForIndex(trimmed);
    final hasExactMatch =
        trimmed.isNotEmpty &&
        tags.any((tag) => foldNameForIndex(tag.name.trim()) == folded);

    final List<TagPickerSection> sections;
    if (keyed.isEmpty) {
      sections = const <TagPickerSection>[];
    } else if (sort == TagPickerSort.custom) {
      sections = <TagPickerSection>[
        TagPickerSection(null, [for (final (tag, _) in keyed) tag]),
      ];
    } else {
      keyed.sort((a, b) {
        final byKey = a.$2!.compareTo(b.$2!);
        if (byKey != 0) return byKey;
        final byName = a.$1.name.compareTo(b.$1.name);
        return byName != 0 ? byName : a.$1.id.compareTo(b.$1.id);
      });
      sections = <TagPickerSection>[];
      for (final (tag, key) in keyed) {
        if (sections.isEmpty || sections.last.letter != key!.letter) {
          sections.add(TagPickerSection(key!.letter, <Tag>[]));
        }
        sections.last.tags.add(tag);
      }
    }
    return TagPickerView._(
      query: trimmed,
      sections: sections,
      hasExactMatch: hasExactMatch,
    );
  }

  /// 去掉首尾空白的检索词。
  final String query;
  final List<TagPickerSection> sections;

  /// 已有与检索词同名的标签（忽略大小写与全角）。
  final bool hasExactMatch;

  bool get isSearching => query.isNotEmpty;

  bool get isEmpty => sections.isEmpty;

  /// 字母索引条上的字母，与分组一一对应；默认排序时为空。
  List<String> get letters => <String>[
    for (final section in sections)
      if (section.letter != null) section.letter!,
  ];

  /// 可直接以检索词新建的名称：在检索、且还没有同名标签时为检索词。
  String? get createName => isSearching && !hasExactMatch ? query : null;
}
