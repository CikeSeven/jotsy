import 'package:flutter/material.dart';

/// 段落操作栏面板的表头高度（含与下方内容的间距）：与表格、代码块、列表
/// 面板的表头同高。
const double kDiaryBlockPanelHeaderHeight = 40 + 4;

/// 一排操作格的高度与间距（同表格面板）。
const double _kRowHeight = 58;
const double _kRowGap = 4;
const double _kBottomGap = 4;

/// 标题与各排操作的左右缩进，左缘对齐。
const double _kInset = 4;

/// [rows] 排操作格的面板内容的自然高度（不含面板外框）。工具栏据此直接
/// 算出面板目标高度，不必等测量。
double diaryBlockPanelHeight(int rows) =>
    kDiaryBlockPanelHeaderHeight +
    rows * _kRowHeight +
    (rows - 1) * _kRowGap +
    _kBottomGap;

/// 段落操作栏的面板内容：表头（标题、右侧可选的文字按钮）+ 若干排等分整行
/// 宽度的操作格（每排四格，同表格面板，320dp 的手机上同样排得下）。给的
/// 高度 [bodyHeight] 小于自然高度时面板内纵向滚动。
class DiaryBlockPanelBody extends StatelessWidget {
  const DiaryBlockPanelBody({
    super.key,
    required this.title,
    required this.bodyHeight,
    required this.rows,
    this.trailing,
  });

  final String title;
  final double bodyHeight;

  /// 每排的操作格；不满一排时右侧留空，各格仍按四等分对齐。
  final List<List<Widget>> rows;

  /// 表头右侧的一个文字按钮（如样式面板的「清除格式」）。
  final Widget? trailing;

  static const int _columns = 4;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _header(context),
        for (var i = 0; i < rows.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: _kRowGap),
          SizedBox(
            height: _kRowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _kInset),
              child: Row(
                children: <Widget>[
                  for (var j = 0; j < _columns; j++)
                    Expanded(
                      child: j < rows[i].length
                          ? rows[i][j]
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: _kBottomGap),
      ],
    );
    return SizedBox(
      height: bodyHeight,
      child: bodyHeight < diaryBlockPanelHeight(rows.length)
          ? SingleChildScrollView(primary: false, child: content)
          : content,
    );
  }

  /// 标题字号与字重同表格、代码块、列表面板的表头。
  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: _kInset, bottom: 4),
    child: SizedBox(
      height: 40,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    ),
  );
}
