import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';

/// 首页 / 搜索列表的查询条件。列表只加载了前面一部分（每次 20 条）时，翻页
/// 器按同一条件一次取出全部日记 id，接在已加载的部分后面。
@immutable
class DiaryPreviewListQuery {
  const DiaryPreviewListQuery({
    required this.keyword,
    required this.requiredTagIds,
    required this.sortMode,
    this.scope = DiaryListScope.all,
    this.excludedIds = const <String>{},
  });

  final String keyword;
  final List<int> requiredTagIds;
  final DiarySortMode sortMode;

  /// 列表所在的范围（全部日记或某本日记本），接续时按同一范围取 id。
  final DiaryListScope scope;

  /// 列表里暂时隐藏、等待撤销的日记（刚归档或删除），翻页时同样跳过。
  final Set<String> excludedIds;
}

/// 预览页左右滑动的顺序：进入时所在列表的日记 id，打开时即冻结。
///
/// 冻结的原因：在预览页里编辑或勾选待办会更新 `updatedAt`，按更新时间排序的
/// 列表会因此重排；顺序冻结后当前页不会被挤走，返回列表时列表照常按最新顺序
/// 显示。[seeds] 是列表里已有的完整数据，对应页面首帧直接渲染；[query] 只在
/// 列表还有没加载的部分时给出（见 [DiaryPreviewListQuery]）。
@immutable
class DiaryPreviewSequence {
  DiaryPreviewSequence({
    required List<String> ids,
    this.seeds = const <String, DiaryWithTags>{},
    this.query,
  }) : ids = List<String>.unmodifiable(ids);

  factory DiaryPreviewSequence.fromItems(
    Iterable<DiaryWithTags> items, {
    DiaryPreviewListQuery? query,
  }) {
    final seeds = <String, DiaryWithTags>{};
    for (final item in items) {
      seeds.putIfAbsent(item.diary.diaryId, () => item);
    }
    return DiaryPreviewSequence(
      ids: seeds.keys.toList(growable: false),
      seeds: Map<String, DiaryWithTags>.unmodifiable(seeds),
      query: query,
    );
  }

  final List<String> ids;
  final Map<String, DiaryWithTags> seeds;
  final DiaryPreviewListQuery? query;

  /// 有可翻的另一篇：快照里不止一篇，或列表还有没加载的部分。
  bool get canPage => ids.length > 1 || query != null;

  /// 把按同一条件查到的完整 id 列表接在后面：只追加快照最后一个 id 之后、
  /// 尚不在快照里且未被排除的部分，已有页的下标不变。找不到衔接点（快照
  /// 末尾那篇已被删除等）时退回到“追加所有新 id”。
  List<String> extendedWith(List<String> fullIds) {
    final known = ids.toSet();
    final excluded = query?.excludedIds ?? const <String>{};
    var start = 0;
    for (var i = ids.length - 1; i >= 0; i--) {
      final at = fullIds.indexOf(ids[i]);
      if (at >= 0) {
        start = at + 1;
        break;
      }
    }
    return <String>[
      ...ids,
      for (final id in fullIds.skip(start))
        if (!known.contains(id) && !excluded.contains(id)) id,
    ];
  }
}
