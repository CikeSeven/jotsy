import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../core/database/app_database.dart';

/// 日记瀑布流的布局生命周期；输入有序日记与卡片构造器，输出带侧边距的
/// sliver。只在已有条目或列数变化时清除布局，不管理分页查询或滚动控制器。
class DiaryWaterfallSliver extends StatefulWidget {
  const DiaryWaterfallSliver({
    super.key,
    required this.diaries,
    required this.columns,
    required this.sideMargin,
    required this.cardGap,
    required this.itemBuilder,
  });

  final List<DiaryWithTags> diaries;
  final int columns;
  final double sideMargin;
  final double cardGap;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<DiaryWaterfallSliver> createState() => _DiaryWaterfallSliverState();
}

class _DiaryWaterfallSliverState extends State<DiaryWaterfallSliver> {
  int _layoutGeneration = 0;

  @override
  void didUpdateWidget(covariant DiaryWaterfallSliver oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Masonry 缓存了已滚出视口的卡片高度与列位置。排序、删除或编辑已有
    // 条目后必须清掉这些旧布局，避免回滚时残留空位；但末尾追加分页不影响
    // 已有布局。若追加也换 key，新 sliver 缺少前面各列的位置，会发出滚动
    // 偏移校正，把正在快速下滑的列表突然拉回顶部附近。
    if (oldWidget.columns != widget.columns ||
        !_hasUnchangedPrefix(oldWidget.diaries, widget.diaries)) {
      _layoutGeneration++;
    }
  }

  bool _hasUnchangedPrefix(
    List<DiaryWithTags> previous,
    List<DiaryWithTags> next,
  ) {
    if (identical(previous, next)) {
      return true;
    }
    if (next.length < previous.length) {
      return false;
    }
    for (var index = 0; index < previous.length; index++) {
      final oldDiary = previous[index].diary;
      final newDiary = next[index].diary;
      if (oldDiary.diaryId != newDiary.diaryId ||
          oldDiary.updatedAt != newDiary.updatedAt) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) => SliverPadding(
    key: ValueKey<int>(_layoutGeneration),
    padding: EdgeInsets.symmetric(horizontal: widget.sideMargin),
    sliver: SliverMasonryGrid.count(
      crossAxisCount: widget.columns,
      mainAxisSpacing: widget.cardGap,
      crossAxisSpacing: widget.cardGap,
      childCount: widget.diaries.length,
      itemBuilder: widget.itemBuilder,
    ),
  );
}
