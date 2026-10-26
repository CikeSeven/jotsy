import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import 'color_palette_families.dart';
import 'color_swatch_button.dart';
import 'desktop_horizontal_scroll.dart';

/// 两级色板：上面一排横向滚动的色系方块，下面是当前色系里的具体颜色圆点。
/// 标签弹窗与日记本编辑页共用。
///
/// 输入：当前选中的 ARGB [selectedColor]（null 表示没有选中任何色块，例如
/// “跟随主题”）；输出：[onSelected] 回调选中的颜色值。只记住正在浏览的色系，
/// 选中值由调用方持有。
///
/// 切换色系时同时选中该色系的第一个颜色（与改版前的标签弹窗一致）：只换色系
/// 不换颜色时，色系页签与实际选中的颜色会对不上。
class ColorPalettePicker extends StatefulWidget {
  const ColorPalettePicker({
    super.key,
    required this.selectedColor,
    required this.onSelected,
    this.fallbackFamilyIndex = 0,
  });

  final int? selectedColor;
  final ValueChanged<int> onSelected;

  /// [selectedColor] 不在色板里（或为 null）时先展示的色系。
  final int fallbackFamilyIndex;

  @override
  State<ColorPalettePicker> createState() => _ColorPalettePickerState();
}

class _ColorPalettePickerState extends State<ColorPalettePicker> {
  late int _familyIndex = resolveColorPaletteSelection(
    initialColor: widget.selectedColor,
    fallbackFamilyIndex: widget.fallbackFamilyIndex,
    fallbackColorIndex: 0,
  ).familyIndex;

  void _selectFamily(int index) {
    setState(() => _familyIndex = index);
    widget.onSelected(kColorPaletteFamilies[index].colors[0].toARGB32());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final family = kColorPaletteFamilies[_familyIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DesktopHorizontalScroll(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List<Widget>.generate(kColorPaletteFamilies.length, (
                index,
              ) {
                final swatch = kColorPaletteFamilies[index].colors[2];
                return ColorSwatchButton(
                  color: swatch,
                  selected: _familyIndex == index,
                  swatchSize: 34,
                  borderRadius: 10,
                  showCheck: false,
                  semanticLabel: l10n.colorFamilySwatchLabel(
                    index + 1,
                    colorSwatchHex(swatch),
                  ),
                  onTap: () => _selectFamily(index),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 48dp 点击区域内已含视觉留白，色块之间不再额外加间距。
        Wrap(
          children: <Widget>[
            for (final color in family.colors)
              ColorSwatchButton(
                color: color,
                selected: widget.selectedColor == color.toARGB32(),
                swatchSize: 34,
                semanticLabel: l10n.colorSwatchLabel(colorSwatchHex(color)),
                onTap: () => widget.onSelected(color.toARGB32()),
              ),
          ],
        ),
      ],
    );
  }
}
