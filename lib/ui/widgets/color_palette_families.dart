import 'package:flutter/material.dart';

/// 应用内统一色板家族，供标签与主题色选择复用。
class ColorPaletteFamily {
  const ColorPaletteFamily({required this.label, required this.colors});

  final String label;
  final List<Color> colors;
}

/// 色板中命中的颜色位置。
class ColorPaletteSelection {
  const ColorPaletteSelection({
    required this.familyIndex,
    required this.colorIndex,
    required this.colorValue,
  });

  final int familyIndex;
  final int colorIndex;
  final int colorValue;
}

const List<ColorPaletteFamily> kColorPaletteFamilies = <ColorPaletteFamily>[
  ColorPaletteFamily(
    label: '红',
    colors: <Color>[
      Color(0xFFFFEBEE),
      Color(0xFFFFCDD2),
      Color(0xFFE57373),
      Color(0xFFEF5350),
      Color(0xFFE53935),
      Color(0xFFD32F2F),
      Color(0xFFC62828),
      Color(0xFFB71C1C),
    ],
  ),
  ColorPaletteFamily(
    label: '粉',
    colors: <Color>[
      Color(0xFFFCE4EC),
      Color(0xFFF8BBD0),
      Color(0xFFF48FB1),
      Color(0xFFF06292),
      Color(0xFFEC407A),
      Color(0xFFD81B60),
      Color(0xFFC2185B),
      Color(0xFF880E4F),
    ],
  ),
  ColorPaletteFamily(
    label: '橙',
    colors: <Color>[
      Color(0xFFFFF3E0),
      Color(0xFFFFE0B2),
      Color(0xFFFFB74D),
      Color(0xFFFFA726),
      Color(0xFFFB8C00),
      Color(0xFFF57C00),
      Color(0xFFEF6C00),
      Color(0xFFE65100),
    ],
  ),
  ColorPaletteFamily(
    label: '黄',
    colors: <Color>[
      Color(0xFFFFFDE7),
      Color(0xFFFFF9C4),
      Color(0xFFFFF176),
      Color(0xFFFFEE58),
      Color(0xFFFDD835),
      Color(0xFFFBC02D),
      Color(0xFFF9A825),
      Color(0xFFF57F17),
    ],
  ),
  ColorPaletteFamily(
    label: '绿',
    colors: <Color>[
      Color(0xFFE8F5E9),
      Color(0xFFC8E6C9),
      Color(0xFFA5D6A7),
      Color(0xFF81C784),
      Color(0xFF66BB6A),
      Color(0xFF43A047),
      Color(0xFF2E7D32),
      Color(0xFF1B5E20),
    ],
  ),
  ColorPaletteFamily(
    label: '青',
    colors: <Color>[
      Color(0xFFE0F7FA),
      Color(0xFFB2EBF2),
      Color(0xFF80DEEA),
      Color(0xFF4DD0E1),
      Color(0xFF26C6DA),
      Color(0xFF00ACC1),
      Color(0xFF00838F),
      Color(0xFF006064),
    ],
  ),
  ColorPaletteFamily(
    label: '蓝',
    colors: <Color>[
      Color(0xFFE3F2FD),
      Color(0xFFBBDEFB),
      Color(0xFF90CAF9),
      Color(0xFF64B5F6),
      Color(0xFF42A5F5),
      Color(0xFF1E6586),
      Color(0xFF1565C0),
      Color(0xFF0D47A1),
    ],
  ),
  ColorPaletteFamily(
    label: '紫',
    colors: <Color>[
      Color(0xFFF3E5F5),
      Color(0xFFE1BEE7),
      Color(0xFFCE93D8),
      Color(0xFFBA68C8),
      Color(0xFFAB47BC),
      Color(0xFF8E24AA),
      Color(0xFF6A1B9A),
      Color(0xFF4A148C),
    ],
  ),
  ColorPaletteFamily(
    label: '棕',
    colors: <Color>[
      Color(0xFFEFEBE9),
      Color(0xFFD7CCC8),
      Color(0xFFBCAAA4),
      Color(0xFFA1887F),
      Color(0xFF8D6E63),
      Color(0xFF6D4C41),
      Color(0xFF5D4037),
      Color(0xFF3E2723),
    ],
  ),
  ColorPaletteFamily(
    label: '灰',
    colors: <Color>[
      Color(0xFFFAFAFA),
      Color(0xFFF5F5F5),
      Color(0xFFEEEEEE),
      Color(0xFFE0E0E0),
      Color(0xFFBDBDBD),
      Color(0xFF9E9E9E),
      Color(0xFF757575),
      Color(0xFF616161),
    ],
  ),
];

ColorPaletteSelection resolveColorPaletteSelection({
  required int? initialColor,
  required int fallbackFamilyIndex,
  required int fallbackColorIndex,
  bool preserveUnknownColor = true,
}) {
  if (initialColor != null) {
    for (
      var familyIndex = 0;
      familyIndex < kColorPaletteFamilies.length;
      familyIndex++
    ) {
      final family = kColorPaletteFamilies[familyIndex];
      for (
        var colorIndex = 0;
        colorIndex < family.colors.length;
        colorIndex++
      ) {
        if (family.colors[colorIndex].toARGB32() == initialColor) {
          return ColorPaletteSelection(
            familyIndex: familyIndex,
            colorIndex: colorIndex,
            colorValue: initialColor,
          );
        }
      }
    }
  }

  final fallbackColor =
      kColorPaletteFamilies[fallbackFamilyIndex].colors[fallbackColorIndex]
          .toARGB32();
  return ColorPaletteSelection(
    familyIndex: fallbackFamilyIndex,
    colorIndex: fallbackColorIndex,
    colorValue:
        preserveUnknownColor ? (initialColor ?? fallbackColor) : fallbackColor,
  );
}
