import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'color_palette_families.dart';
import 'color_swatch_button.dart';
import 'desktop_horizontal_scroll.dart';

/// 调色板取色器：当前颜色的 HEX 预览、横向的色系色块与所选色系的八个深浅。
///
/// 只负责展示与回调，选中状态由调用方按 [resolveColorPaletteSelection] 解析
/// 后传入（与这里同一份 [families]）。主题色设置与日记卡片的自定义颜色共用
/// 这一套；主题色多一个“黑白”色系（[kThemeColorPaletteFamilies]）。
class PaletteColorPicker extends StatelessWidget {
  const PaletteColorPicker({
    super.key,
    required this.selectedColor,
    required this.selectedFamilyIndex,
    required this.selectedColorIndex,
    required this.selectedFamily,
    required this.onSelectFamily,
    required this.onSelectColor,
    this.families = kColorPaletteFamilies,
  });

  final Color selectedColor;
  final int selectedFamilyIndex;
  final int selectedColorIndex;
  final ColorPaletteFamily selectedFamily;
  final ValueChanged<int> onSelectFamily;
  final ValueChanged<Color> onSelectColor;

  /// 色系一行列出的色系，下标与 [selectedFamilyIndex]、[onSelectFamily] 对应。
  final List<ColorPaletteFamily> families;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selectedColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '#${selectedColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                letterSpacing: 0.5,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DesktopHorizontalScroll(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List<Widget>.generate(families.length, (index) {
                final family = families[index];
                final selected = selectedFamilyIndex == index;
                return ColorSwatchButton(
                  color: family.swatch,
                  splitColor: family.swatchSplit,
                  selected: selected,
                  borderRadius: 10,
                  showCheck: false,
                  semanticLabel: context.l10n.colorFamilySwatchLabel(
                    index + 1,
                    colorSwatchHex(family.swatch),
                  ),
                  onTap: () => onSelectFamily(index),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 14),
        // 48dp 点击区域内已含 16dp 视觉留白，色块之间不再额外加间距。
        Wrap(
          children: List<Widget>.generate(selectedFamily.colors.length, (
            index,
          ) {
            final color = selectedFamily.colors[index];
            return ColorSwatchButton(
              color: color,
              selected: selectedColorIndex == index,
              semanticLabel: context.l10n.colorSwatchLabel(
                colorSwatchHex(color),
              ),
              onTap: () => onSelectColor(color),
            );
          }),
        ),
      ],
    );
  }
}
