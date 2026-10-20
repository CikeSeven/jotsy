import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../diaries/models/diary_code_block/diary_code_block_style.dart';
import '../../controllers/diary_code_block_style_editor_controller.dart';
import '../../widgets/settings_card_group.dart';
import '../../widgets/settings_option_tiles.dart';
import '../../widgets/style_editor/style_editor_common.dart';
import '../diary_card_style/diary_card_style_labels.dart';

/// “显示”标签页：行号、标题栏、自动识别语言、边框四个开关（点按即写入）
/// 与圆角滑块（拖动中只预览，松手写入）。
class DiaryCodeBlockStyleDisplayTab extends StatelessWidget {
  const DiaryCodeBlockStyleDisplayTab({super.key, required this.controller});

  final DiaryCodeBlockStyleEditorController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = controller.style;
    void commit(DiaryCodeBlockStyle next) => controller.commit(next);

    return StyleEditorTabList(
      children: <Widget>[
        SettingsCardGroup(
          children: <Widget>[
            SettingsSwitchTile(
              title: l10n.codeBlockLineNumbersTitle,
              subtitle: l10n.codeBlockLineNumbersSubtitle,
              value: style.lineNumbers,
              onChanged: (bool v) => commit(style.copyWith(lineNumbers: v)),
            ),
            SettingsSwitchTile(
              title: l10n.codeBlockHeaderTitle,
              subtitle: l10n.codeBlockHeaderSubtitle,
              value: style.header,
              onChanged: (bool v) => commit(style.copyWith(header: v)),
            ),
            SettingsSwitchTile(
              title: l10n.codeBlockAutoDetectTitle,
              subtitle: l10n.codeBlockAutoDetectSubtitle,
              value: style.autoDetect,
              onChanged: (bool v) => commit(style.copyWith(autoDetect: v)),
            ),
            SettingsSwitchTile(
              title: l10n.codeBlockBorderTitle,
              subtitle: l10n.codeBlockBorderSubtitle,
              value: style.border,
              onChanged: (bool v) => commit(style.copyWith(border: v)),
            ),
          ],
        ),
        SettingsCardGroup(
          children: <Widget>[
            SettingsSliderTile(
              title: l10n.codeBlockRadiusTitle,
              value: style.radius,
              min: DiaryCodeBlockStyle.minRadius,
              max: DiaryCodeBlockStyle.maxRadius,
              divisions: codeBlockSliderDivisions(
                DiaryCodeBlockStyle.minRadius,
                DiaryCodeBlockStyle.maxRadius,
                DiaryCodeBlockStyle.radiusStep,
              ),
              valueLabel: (double v) => diaryCardDpLabel(l10n, v),
              onChanged: (double v) =>
                  controller.previewWith((s) => s.copyWith(radius: v)),
              onChangeEnd: (double v) =>
                  controller.commitWith((s) => s.copyWith(radius: v)),
            ),
          ],
        ),
      ],
    );
  }
}

/// 滑块分段数：范围按步进切分，滑块只产出步进上的值（与模型的吸附一致）。
int codeBlockSliderDivisions(double min, double max, double step) =>
    ((max - min) / step).round();
