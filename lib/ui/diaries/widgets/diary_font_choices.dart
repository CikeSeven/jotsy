import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/diary_font_storage_service.dart';
import '../../../core/services/diary_typography.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/desktop_horizontal_scroll.dart';

/// 一个可选的正文字体；[imported] 为 null 表示内置或系统字体。
class DiaryFontOption {
  const DiaryFontOption({required this.id, required this.label, this.imported});

  final String id;
  final String label;
  final DiaryImportedFont? imported;
}

/// 可选字体：内置字体、系统字体，之后按导入顺序列出导入的字体。
List<DiaryFontOption> diaryFontOptions(
  AppLocalizations l10n,
  List<DiaryImportedFont> importedFonts,
) {
  return <DiaryFontOption>[
    DiaryFontOption(
      id: DiaryTypography.bundledFontId,
      label: l10n.diaryTypographyFontBundled,
    ),
    DiaryFontOption(
      id: DiaryTypography.systemFontId,
      label: l10n.diaryTypographyFontSystem,
    ),
    for (final font in importedFonts)
      DiaryFontOption(id: font.id, label: font.name, imported: font),
  ];
}

/// 快捷面板里的横向字体选择条：一行放下，字体多时横向滚动，不撑高面板。
class DiaryFontChipBar extends StatelessWidget {
  const DiaryFontChipBar({
    super.key,
    required this.options,
    required this.selectedId,
    required this.onSelected,
  });

  final List<DiaryFontOption> options;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return DesktopHorizontalScroll(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
        child: Row(
          children: <Widget>[
            for (final option in options)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AppSpacing.s),
                child: ChoiceChip(
                  label: Text(option.label),
                  selected: option.id == selectedId,
                  onSelected: (_) => onSelected(option.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
