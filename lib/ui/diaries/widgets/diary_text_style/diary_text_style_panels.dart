import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart'
    as editor;
import 'package:node_diary/ui/diaries/controllers/diary_text_style_editing.dart';
import 'package:node_diary/ui/diaries/models/diary_text_style_options.dart';
import 'package:node_diary/ui/diaries/widgets/diary_toolbar_config.dart';

import 'diary_text_style_panel.dart';

/// 悬浮工具栏的三块文字样式面板：标题、对齐、字号。外壳、选中与停用规则见
/// [DiaryTextStylePanel]，读写正文见 `diary_text_style_editing.dart`。

/// 「标题」面板：正文 / H1–H6，作用于选区里除代码块外的文字块。
class DiaryHeadingPanel extends StatelessWidget {
  const DiaryHeadingPanel({
    super.key,
    required this.controller,
    required this.bodyHeight,
  });

  final editor.DiaryEditorController controller;
  final double bodyHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final headingLabels = <String>[
      l10n.diaryEditorHeading1,
      l10n.diaryEditorHeading2,
      l10n.diaryEditorHeading3,
      l10n.diaryEditorHeading4,
      l10n.diaryEditorHeading5,
      l10n.diaryEditorHeading6,
    ];
    return DiaryTextStylePanel<int>(
      controller: controller,
      title: l10n.diaryHeadingPanelTitle,
      options: <DiaryTextStyleOption<int>>[
        DiaryTextStyleOption<int>(
          value: 0,
          label: l10n.diaryHeadingPanelBody,
          child: Text(l10n.diaryHeadingPanelBody),
        ),
        for (var level = 1; level <= 6; level++)
          DiaryTextStyleOption<int>(
            value: level,
            label: headingLabels[level - 1],
            child: Text('H$level'),
          ),
      ],
      selectedOf: selectedDiaryHeadingLevel,
      onSelected: setDiaryHeadingLevel,
      bodyHeight: bodyHeight,
    );
  }
}

/// 「对齐」面板：左对齐 / 居中 / 右对齐 / 两端对齐（只画图标，名称留给读屏
/// 与长按提示）。
class DiaryAlignPanel extends StatelessWidget {
  const DiaryAlignPanel({
    super.key,
    required this.controller,
    required this.bodyHeight,
  });

  final editor.DiaryEditorController controller;
  final double bodyHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DiaryTextStylePanel<DiaryTextAlign>(
      controller: controller,
      title: l10n.diaryToolbarAlign,
      options: <DiaryTextStyleOption<DiaryTextAlign>>[
        for (final align in DiaryTextAlign.values)
          DiaryTextStyleOption<DiaryTextAlign>(
            value: align,
            label: switch (align) {
              DiaryTextAlign.left => l10n.diaryAlignLeft,
              DiaryTextAlign.center => l10n.diaryAlignCenter,
              DiaryTextAlign.right => l10n.diaryAlignRight,
              DiaryTextAlign.justify => l10n.diaryAlignJustify,
            },
            child: FaIcon(diaryTextAlignIcon(align), size: 16),
          ),
      ],
      selectedOf: selectedDiaryTextAlign,
      onSelected: setDiaryTextAlign,
      bodyHeight: bodyHeight,
    );
  }
}

/// 「字号」面板：小 / 正文 / 大 / 特大，每档的标签按它相对正文的倍数画大小，
/// 一眼看出差别；放不进按钮时整体等比缩小。
class DiaryFontSizePanel extends StatelessWidget {
  const DiaryFontSizePanel({
    super.key,
    required this.controller,
    required this.bodyHeight,
  });

  final editor.DiaryEditorController controller;
  final double bodyHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 按钮标签的字号（labelLarge）为“正文”一档，其余按倍数缩放。
    final base = Theme.of(context).textTheme.labelLarge?.fontSize ?? 14;
    return DiaryTextStylePanel<DiaryFontSize>(
      controller: controller,
      title: l10n.diaryToolbarFontSize,
      options: <DiaryTextStyleOption<DiaryFontSize>>[
        for (final size in DiaryFontSize.values)
          () {
            final label = switch (size) {
              DiaryFontSize.small => l10n.diaryFontSizeSmall,
              DiaryFontSize.normal => l10n.diaryFontSizeNormal,
              DiaryFontSize.large => l10n.diaryFontSizeLarge,
              DiaryFontSize.huge => l10n.diaryFontSizeHuge,
            };
            return DiaryTextStyleOption<DiaryFontSize>(
              value: size,
              label: label,
              child: Text(label, style: TextStyle(fontSize: base * size.scale)),
            );
          }(),
      ],
      selectedOf: selectedDiaryFontSize,
      onSelected: setDiaryFontSize,
      bodyHeight: bodyHeight,
    );
  }
}
