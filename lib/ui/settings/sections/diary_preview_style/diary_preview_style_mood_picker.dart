import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../../diaries/providers/diary_mood_palette_provider.dart';
import '../../../diaries/widgets/tag_filter_chip.dart';

/// “预览心情”：一排胶囊，“按示例”加上用户的十个心情（由低落到高兴），每个
/// 心情胶囊带它在心情色板里的颜色。只负责挑选，选中值经 [onSelected] 交给
/// 编辑页控制器（`previewMood`，只在本页内存里），不写设置。
///
/// 胶囊配色与日历筛选面板的标签胶囊同一写法（颜色浅底 + 色点，选中加深并
/// 描边），颜色取心情的强调色（按当前明暗换算），浅色与深色下都看得清。
class DiaryPreviewMoodPicker extends ConsumerWidget {
  const DiaryPreviewMoodPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// 当前选中的心情符号；null 为“按示例”。
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final isLight = scheme.brightness == Brightness.light;
    final palette = ref.watch(diaryMoodPaletteProvider);
    final glassField = AppGlassField.of(context);
    const padding = EdgeInsets.symmetric(horizontal: 10, vertical: 6);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        TagFilterChip(
          label: l10n.diaryPreviewStylePreviewMoodSample,
          selected: selected == null,
          selectedColor: scheme.primary.withValues(
            alpha: isLight ? 0.16 : 0.28,
          ),
          selectedForegroundColor: scheme.onSurface,
          selectedBorderColor: scheme.primary,
          unselectedColor: glassField?.fill ?? scheme.surfaceContainerHigh,
          unselectedForegroundColor: scheme.onSurface,
          unselectedBorderColor: glassField?.border?.color,
          radius: 12,
          padding: padding,
          animateBorder: true,
          onTap: () => onSelected(null),
        ),
        for (var slot = 1; slot <= palette.moodOptions.length; slot += 1)
          _moodChip(
            palette.moodOptions[slot - 1],
            palette.accentForSlot(slot, scheme.brightness),
            scheme,
            padding,
          ),
      ],
    );
  }

  Widget _moodChip(
    String mood,
    Color color,
    ColorScheme scheme,
    EdgeInsets padding,
  ) {
    final isLight = scheme.brightness == Brightness.light;
    return TagFilterChip(
      label: mood,
      colorDot: color,
      selected: mood == selected,
      selectedColor: color.withValues(alpha: isLight ? 0.22 : 0.36),
      selectedForegroundColor: scheme.onSurface,
      selectedBorderColor: color,
      unselectedColor: color.withValues(alpha: isLight ? 0.08 : 0.16),
      unselectedForegroundColor: scheme.onSurface,
      unselectedBorderColor: color.withValues(alpha: isLight ? 0.22 : 0.32),
      radius: 12,
      padding: padding,
      animateBorder: true,
      onTap: () => onSelected(mood),
    );
  }
}
