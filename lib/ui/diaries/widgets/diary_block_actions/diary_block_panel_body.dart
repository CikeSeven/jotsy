import 'package:flutter/material.dart';

/// 一排操作格的高度、格与格之间的间距（横竖相同）、最后一排下方的留白。
const double _kRowHeight = 58;
const double _kGap = 6;
const double _kBottomGap = 4;

/// 每格左右各缩进半个间距（见 [DiaryBlockPanelBody]）。
const double kDiaryBlockPanelCellInset = _kGap / 2;

/// 末尾通栏那一格（如「清除格式」）的高度。
const double kDiaryBlockPanelFooterHeight = 40;

/// 每排的格数。320dp 的手机上四格同样排得下。
const int _kColumns = 4;

/// [rows] 排操作格（[footer] 为 true 时末尾再加一格通栏）的面板内容的自然
/// 高度（不含面板外框）。操作栏据此直接算出面板目标高度，不必等测量。
double diaryBlockPanelHeight(int rows, {bool footer = false}) =>
    rows * _kRowHeight +
    (rows - 1) * _kGap +
    (footer ? _kGap + kDiaryBlockPanelFooterHeight : 0) +
    _kBottomGap;

/// 面板里的一格：[span] 为它占几格宽（长标签占两格）。
class DiaryBlockPanelItem {
  const DiaryBlockPanelItem(this.child, {this.span = 1});

  final Widget child;
  final int span;
}

/// 段落操作栏的面板内容：若干排磁贴一样的操作格（每排四格宽，不满一排时
/// 右侧留空，各格仍按四等分对齐），末尾可再接一格通栏的 [footer]。不带
/// 标题——是哪个面板，下面那排亮着的工具已经说明了。给的高度 [bodyHeight]
/// 小于自然高度时面板内纵向滚动。
class DiaryBlockPanelBody extends StatelessWidget {
  const DiaryBlockPanelBody({
    super.key,
    required this.bodyHeight,
    required this.rows,
    this.footer,
  });

  final double bodyHeight;
  final List<List<DiaryBlockPanelItem>> rows;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < rows.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: _kGap),
          SizedBox(height: _kRowHeight, child: _row(rows[i])),
        ],
        if (footer case final footer?) ...<Widget>[
          const SizedBox(height: _kGap),
          SizedBox(
            height: kDiaryBlockPanelFooterHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kDiaryBlockPanelCellInset,
              ),
              child: footer,
            ),
          ),
        ],
        const SizedBox(height: _kBottomGap),
      ],
    );
    return SizedBox(
      height: bodyHeight,
      child:
          bodyHeight <
              diaryBlockPanelHeight(rows.length, footer: footer != null)
          ? SingleChildScrollView(primary: false, child: content)
          : content,
    );
  }

  /// 间距做成每格两侧各半个：按格数等分后，占两格的正好等于两格加一道
  /// 间距，上下两排的格子边缘对得齐。整排两端因此各缩进半个间距，操作栏
  /// 的工具一排用同样的缩进，上下对齐。
  Widget _row(List<DiaryBlockPanelItem> items) {
    final used = items.fold<int>(0, (sum, item) => sum + item.span);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final item in items)
          Expanded(
            flex: item.span,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kDiaryBlockPanelCellInset,
              ),
              child: item.child,
            ),
          ),
        if (used < _kColumns) Spacer(flex: _kColumns - used),
      ],
    );
  }
}
