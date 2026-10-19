import 'package:flutter/material.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_text_colors.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_swatch.dart';

/// 颜色面板的色块网格：第一格默认 / 无背景，随后 11 个预设，再接这篇日记里
/// 用过的自定义颜色；按 [grid] 的列数逐行靠左排，列宽 = 可用宽度 / 列数。
///
/// - 输入：目标、选区当前颜色、网格排布与自定义颜色；
/// - 输出：[onSelected]（null 为清除颜色），不直接写正文。
class DiaryColorSwatchGrid extends StatelessWidget {
  const DiaryColorSwatchGrid({
    super.key,
    required this.target,
    required this.current,
    required this.grid,
    required this.usedColors,
    required this.onSelected,
  });

  final DiaryColorTarget target;
  final DiaryColorValue current;
  final DiaryColorGridLayout grid;
  final List<Color> usedColors;
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
      // 自定义颜色两种目标各不相同：按格子位置保留，内容换了就交叉淡入。
      for (final (index, color) in usedColors.take(grid.customCount).indexed)
        _CustomCell(
          key: ValueKey<int>(index),
          switchKey: '${target.name}-${color.toARGB32()}',
          child: DiaryColorSwatch(
            color: color,
            target: target,
            selected: current.matches(color),
            label: l10n.colorSwatchLabel(diaryColorRgbHex(color)),
            onTap: () => onSelected(color),
          ),
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

class _CustomCell extends StatelessWidget {
  const _CustomCell({super.key, required this.switchKey, required this.child});

  final String switchKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
    switchInCurve: ExpressiveMotion.effects,
    switchOutCurve: ExpressiveMotion.exit,
    child: KeyedSubtree(key: ValueKey<String>(switchKey), child: child),
  );
}
