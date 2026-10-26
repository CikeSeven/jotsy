import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_swatch.dart';

/// 色板页的预设网格：第一格默认 / 无背景，随后 12 个预设；按 [grid] 的列数
/// 逐行靠左排，列宽 = 可用宽度 / 列数（下方“我的颜色”一行用同一列宽对齐）。
///
/// - 输入：目标、选区当前颜色、网格排布；
/// - 输出：[onSelected]（null 为清除颜色），不直接写正文。
class DiaryColorSwatchGrid extends StatelessWidget {
  const DiaryColorSwatchGrid({
    super.key,
    required this.target,
    required this.current,
    required this.grid,
    required this.onSelected,
  });

  final DiaryColorTarget target;
  final DiaryColorValue current;
  final DiaryColorGridLayout grid;
  final ValueChanged<Color?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final background = target == DiaryColorTarget.background;
    final cells = <Widget>[
      DiaryColorSwatch(
        color: null,
        target: target,
        selected: current.isNone,
        label: background
            ? l10n.diaryColorPanelNoBackground
            : l10n.diaryColorPanelDefaultColor,
        onTap: () => onSelected(null),
      ),
      // 预设按下标保持同一个 widget，切换目标时原地补间颜色。
      for (final preset in DiaryColorPreset.values)
        DiaryColorSwatch(
          color: preset.colorFor(target),
          target: target,
          selected: current.matches(preset.colorFor(target)),
          label: preset.label(l10n),
          onTap: () => onSelected(preset.colorFor(target)),
        ),
    ];
    final columns = grid.columns;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final cellWidth = constraints.maxWidth / columns;
        return Column(
          children: <Widget>[
            for (var start = 0; start < cells.length; start += columns)
              SizedBox(
                height: DiaryColorGridLayout.cellHeight,
                child: Row(
                  children: <Widget>[
                    for (final cell in cells.skip(start).take(columns))
                      SizedBox(width: cellWidth, child: cell),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
