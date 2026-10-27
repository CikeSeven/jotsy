import 'package:flutter/material.dart';
import 'package:node_diary/core/database/diary_blocks/diary_list_style.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';

import '../diary_editor/diary_block_markers.dart';

/// 样式格子的高度：三行缩略列表（每行 12dp、行距 2dp）加上下各 8dp。
const double kDiaryListStyleTileHeight = 56;

/// 样式格子的最小宽度：放得下最宽的序号（“三、”）与一截正文示意条。
const double kDiaryListStyleTileMinWidth = 56;

const double _kRowHeight = 12;
const double _kRowGap = 2;

/// 序号列宽：10sp 下“(3)”“iii.”“①”都在 14dp 以内；汉字序号（“三、”）
/// 宽 20dp，单独放宽。再宽的按比例缩小。
const double _kMarkerWidth = 14;
const double _kChineseMarkerWidth = 20;

/// 无序标记列宽：最大的形状（星形、箭头）缩小后 8dp。
const double _kBulletWidth = 8;

/// “自动”预览里每深一层缩进多少。
const double _kLevelIndent = 5;

/// 列表面板里的一个样式格子：画一段三行的缩略列表（标记 + 示意条），点按
/// 即选用。对应的样式（有序看 [ordered]，无序看 [bullet]）为 null 表示
/// “自动（按层级）”，缩略图按层级逐行缩进、轮换标记。
///
/// 外观与代码块面板的语言选项一致：未选 surfaceContainerHigh，选中
/// primaryContainer，经 [ExpressiveStateBlend] 补间；只是按钮，不请求焦点。
class DiaryListStyleTile extends StatelessWidget {
  const DiaryListStyleTile({
    super.key,
    required this.numbered,
    required this.label,
    required this.selected,
    required this.onTap,
    this.ordered,
    this.bullet,
  });

  /// 有序列表的格子（否则为无序）。
  final bool numbered;
  final DiaryOrderedListStyle? ordered;
  final DiaryBulletListStyle? bullet;

  /// 读屏与悬停提示用的样式名称。
  final String label;
  final bool selected;
  final VoidCallback onTap;

  bool get _auto => numbered ? ordered == null : bullet == null;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: ExpressiveStateBlend(
          active: selected,
          builder: (BuildContext context, double t, Widget? child) {
            final marker = Color.lerp(
              colors.primary,
              colors.onPrimaryContainer,
              t,
            )!;
            final line = Color.lerp(
              colors.onSurfaceVariant,
              colors.onPrimaryContainer,
              t,
            )!.withValues(alpha: 0.35);
            return Material(
              color: Color.lerp(
                colors.surfaceContainerHigh,
                colors.primaryContainer,
                t,
              ),
              shape: shape,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                customBorder: shape,
                child: SizedBox(
                  height: kDiaryListStyleTileHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: Column(
                      children: <Widget>[
                        for (var row = 0; row < 3; row++) ...<Widget>[
                          if (row > 0) const SizedBox(height: _kRowGap),
                          _buildRow(context, row, marker, line),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 缩略列表的第 [row] 行（0 起）。“自动”时第 n 行就是第 n 层的第一项。
  Widget _buildRow(BuildContext context, int row, Color marker, Color line) {
    final level = _auto ? row : 0;
    final Widget mark;
    if (numbered) {
      final style = ordered ?? DiaryOrderedListStyle.auto(level);
      mark = FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          style.label(_auto ? 1 : row + 1),
          maxLines: 1,
          softWrap: false,
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w600,
            color: marker,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      );
    } else {
      final style = bullet ?? DiaryBulletListStyle.auto(level);
      final extent = DiaryBulletMarker.designExtent(style) * 0.8;
      mark = Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox.square(
          dimension: extent,
          child: DiaryBulletShape(style: style, color: marker, scale: 0.8),
        ),
      );
    }
    return SizedBox(
      height: _kRowHeight,
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: level * _kLevelIndent),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: !numbered
                  ? _kBulletWidth
                  : ordered == DiaryOrderedListStyle.chinese
                  ? _kChineseMarkerWidth
                  : _kMarkerWidth,
              child: mark,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: const [1.0, 0.75, 0.9][row],
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: line,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
