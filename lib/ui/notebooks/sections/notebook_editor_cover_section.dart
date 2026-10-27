import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../calendar/widgets/calendar_options_controls.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../controllers/notebook_cover_flows.dart';
import '../controllers/notebook_editor_controller.dart';
import '../widgets/notebook_cover/notebook_cover_style_pickers.dart';
import '../widgets/notebook_cover_parts.dart';

/// 编辑页的“封面”分组，三行：
///
/// 1. 版式：五个小预览卡横排（[NotebookCoverLayoutPicker]）；
/// 2. 纹理：五个样块（[NotebookCoverTexturePicker]）；
/// 3. 封面图：“选择图片”、“从日记中选”（只对已保存的日记本：新建时还没有
///    日记）、“调整取景”（有图时）与“移除”（有图时）。
///
/// 改动都写进 [NotebookEditorController]（参与“有改动”比较，保存时写入
/// payload 的 `coverStyle` 与封面路径），页面顶部的实时预览随之变化。拷贝
/// 封面期间封面图按钮不可点。
class NotebookEditorCoverSection extends StatelessWidget {
  const NotebookEditorCoverSection({
    super.key,
    required this.controller,
    required this.onPickCover,
  });

  final NotebookEditorController controller;
  final Future<void> Function() onPickCover;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final accent = notebookAccentColors(controller.color, scheme);
    final style = controller.coverStyle;
    final busy = controller.importingCover;
    final hasCover = controller.coverPath != null;
    return SettingsCardGroup(
      title: l10n.notebookCoverSectionTitle,
      children: <Widget>[
        // 横向滚动的预览条铺到卡片左右边缘，滚出的卡片消失在卡片边缘；
        // 小标题仍与其他行的内容左缘对齐。
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.l,
              bottom: AppSpacing.m,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
                  child: CalendarOptionsFieldLabel(
                    text: l10n.notebookCoverLayoutTitle,
                  ),
                ),
                NotebookCoverLayoutPicker(
                  style: style,
                  icon: controller.icon,
                  accent: accent,
                  coverPath: controller.coverPath,
                  onSelected: (layout) =>
                      controller.coverStyle = style.copyWith(layout: layout),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CalendarOptionsFieldLabel(text: l10n.notebookCoverTextureTitle),
                NotebookCoverTexturePicker(
                  selected: style.texture,
                  accent: accent,
                  onSelected: (texture) =>
                      controller.coverStyle = style.copyWith(texture: texture),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CalendarOptionsFieldLabel(text: l10n.notebookCoverLabel),
                Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      onPressed: busy ? null : () => unawaited(onPickCover()),
                      icon: const FaIcon(FontAwesomeIcons.image, size: 14),
                      label: Text(l10n.notebookCoverPick),
                    ),
                    if (controller.notebookId != null)
                      FilledButton.tonalIcon(
                        onPressed: busy
                            ? null
                            : () => unawaited(
                                pickNotebookCoverFromDiaries(
                                  context,
                                  controller,
                                ),
                              ),
                        icon: const FaIcon(FontAwesomeIcons.images, size: 14),
                        label: Text(l10n.notebookCoverFromDiaries),
                      ),
                    if (hasCover)
                      OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => unawaited(
                                adjustNotebookCoverCrop(context, controller),
                              ),
                        icon: const FaIcon(
                          FontAwesomeIcons.cropSimple,
                          size: 14,
                        ),
                        label: Text(l10n.notebookCoverAdjustCrop),
                      ),
                    if (hasCover)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => controller.coverPath = null,
                        child: Text(l10n.notebookCoverRemove),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
