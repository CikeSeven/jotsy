import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_layout.dart';
import 'package:node_diary/ui/diaries/models/diary_toolbar_preferences.dart';

/// 面板内容距卡片上沿：可见按钮离上沿 10dp，与卡片 18dp 圆角留出呼吸。
const double _kPanelTopPadding = 6;

/// 面板最后一行与分隔线的距离：两侧可见按钮到分隔线都是 6dp。
const double _kPanelBottomPadding = 2;
const double _kPanelRowGap = 4;
const double _kPanelDividerHeight = 1;

/// 面板外框（上下留白 + 分隔线）的高度；面板目标高度 = 外框 + 内容高度。
/// 「更多」与颜色面板共用同一外框，切换内容时只有内容高度在变。
const double kDiaryToolbarPanelChrome =
    _kPanelTopPadding + _kPanelBottomPadding + _kPanelDividerHeight;

/// 面板最多直接露出的行数；更多行在面板内纵向滚动，键盘弹起后正文仍露得出来。
const int _kPanelMaxVisibleRows = 3;

/// 行数超出上限时多露出半行，提示面板还能往下滚。
const double _kPanelScrollPeek = kDiaryToolbarButtonExtent / 2;

/// 「更多」面板 [rows] 行全部展开时的内容高度。
double diaryToolbarMorePanelNaturalHeight(int rows) =>
    rows * kDiaryToolbarButtonExtent + math.max(0, rows - 1) * _kPanelRowGap;

/// 「更多」面板实际给内容的高度：最多露 3 行（再多露半行提示可滚动），并且
/// 整个面板不超过 [maxPanelExtent]。
double diaryToolbarMorePanelBodyHeight(int rows, double maxPanelExtent) {
  var body = diaryToolbarMorePanelNaturalHeight(rows);
  if (rows > _kPanelMaxVisibleRows) {
    body =
        diaryToolbarMorePanelNaturalHeight(_kPanelMaxVisibleRows) +
        _kPanelRowGap +
        _kPanelScrollPeek;
  }
  return diaryToolbarPanelBodyLimit(body, maxPanelExtent);
}

/// 把内容高度 [body] 夹到面板上限 [maxPanelExtent] 以内（扣掉外框）。
double diaryToolbarPanelBodyLimit(double body, double maxPanelExtent) =>
    math.max(0.0, math.min(body, maxPanelExtent - kDiaryToolbarPanelChrome));

/// 面板外框：内容四周留白 + 底部与工具栏一排之间的分隔线，「更多」与颜色
/// 面板共用。
///
/// 换内容（[contentKey] 变化）时外框不动：高度经 AnimatedSize 补间到新内容，
/// 新旧内容交叉淡入（`medium`）。旧内容不参与定尺寸，外框高度只跟随新内容，
/// 旧内容在补间中被裁切、淡出——否则 Stack 取两者较高者，收矮时要等旧内容
/// 移除才开始收。
class DiaryToolbarPanelFrame extends StatelessWidget {
  const DiaryToolbarPanelFrame({
    super.key,
    required this.contentKey,
    required this.child,
  });

  final Object contentKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            kDiaryToolbarHorizontalPadding,
            _kPanelTopPadding,
            kDiaryToolbarHorizontalPadding,
            _kPanelBottomPadding,
          ),
          // 0 时长的 AnimatedSize 会在自身布局中重新标脏而断言（DESIGN §4.3）。
          child: AnimatedSize(
            duration: ExpressiveMotion.durationNonZero(
              context,
              ExpressiveMotion.medium,
            ),
            curve: ExpressiveMotion.effects,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.medium,
              ),
              switchInCurve: ExpressiveMotion.effects,
              switchOutCurve: ExpressiveMotion.exit,
              layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
                alignment: Alignment.topCenter,
                children: <Widget>[
                  for (final child in previous)
                    Positioned(top: 0, left: 0, right: 0, child: child),
                  ?current,
                ],
              ),
              child: KeyedSubtree(
                key: ValueKey<Object>(contentKey),
                child: child,
              ),
            ),
          ),
        ),
        Divider(
          height: _kPanelDividerHeight,
          thickness: 0.8,
          indent: 12,
          endIndent: 12,
          color: ExpressiveSurfaces.cardBorderColor(
            Theme.of(context).colorScheme,
          ),
        ),
      ],
    );
  }
}

/// 「更多」面板的内容：收进来的工具沿用工具栏列宽逐行排布，与下方一排对齐
/// 成一张网格；行数超出 [bodyHeight] 时在面板内纵向滚动。
class DiaryToolbarMorePanel extends StatelessWidget {
  const DiaryToolbarMorePanel({
    super.key,
    required this.rows,
    required this.cell,
    required this.bodyHeight,
  });

  final List<List<DiaryToolbarItem>> rows;
  final Widget Function(DiaryToolbarItem item) cell;
  final double bodyHeight;

  @override
  Widget build(BuildContext context) {
    final rowsColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var index = 0; index < rows.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: _kPanelRowGap),
          SizedBox(
            height: kDiaryToolbarButtonExtent,
            child: Row(
              children: <Widget>[for (final item in rows[index]) cell(item)],
            ),
          ),
        ],
      ],
    );
    final scrollable =
        bodyHeight < diaryToolbarMorePanelNaturalHeight(rows.length);
    return SizedBox(
      height: bodyHeight,
      child: scrollable
          ? SingleChildScrollView(primary: false, child: rowsColumn)
          : rowsColumn,
    );
  }
}
