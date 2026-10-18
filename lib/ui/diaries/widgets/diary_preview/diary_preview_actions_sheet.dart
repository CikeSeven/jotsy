import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/app_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../anniversaries/controllers/anniversary_navigation.dart';
import '../../../anniversaries/models/anniversary_draft.dart';
import '../../../diary_templates/controllers/diary_template_save_as.dart';
import '../../../settings/pages/diary_preview_style_page.dart';
import '../../controllers/diary_preview_export_controller.dart';
import '../../models/publish_metadata_composer.dart';

/// 预览页“更多”的完整接线：分享与导出经 [export]（分享面板里可选长图），
/// 设为纪念日经数据库，存为模板打开预填好的模板编辑页（去掉媒体），“页面样式”打开预览页样式设置且第一篇示例就是这篇
/// （设置尚未就绪时不显示这一项）。[ref] 属于预览页本身，页面卸载后不再使用。
Future<void> showDiaryPreviewMore(
  BuildContext context,
  WidgetRef ref, {
  required DiaryPreviewExportController export,
  required DiaryWithTags detail,
  required Color background,
  required Future<void> Function() onDelete,
}) {
  final database = ref.read(appDatabaseProvider);
  final settings = ref.read(settingsServiceProvider).asData?.value;
  return showDiaryPreviewActionsSheet(
    context,
    onShare: () async {
      final service = await ref.read(settingsServiceProvider.future);
      if (!context.mounted) {
        return;
      }
      await export.openShareSheet(
        context,
        detail: detail,
        settings: service,
        background: background,
      );
    },
    onExport: () => export.exportDiary(context, ref, detail: detail),
    onSetAsAnniversary: () => openAnniversaryEditor(
      context,
      database: database,
      draft: AnniversaryDraft.fromDiary(detail.diary),
    ),
    onSaveAsTemplate: () {
      final meta = PublishMetadataComposer.parse(detail.diary.metadata);
      return openSaveAsTemplate(
        context,
        title: detail.diary.title,
        contentDocJson: detail.diary.content,
        tags: detail.tags,
        mood: meta.moodEmoji,
        energy: meta.energyLevel,
      );
    },
    onDelete: onDelete,
    onOpenStyle: settings == null
        ? null
        : () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => DiaryPreviewStylePage(
                settingsService: settings,
                previewDiary: detail,
              ),
            ),
          ),
  );
}

/// 预览页“更多”面板：分享、导出、设为纪念日、存为模板、页面样式与删除。
///
/// 每一项先关闭面板，再执行对应动作（长图截图要等面板完全退场，见
/// `DiaryPreviewExportController.shareLongImage`）。
Future<void> showDiaryPreviewActionsSheet(
  BuildContext context, {
  required Future<void> Function() onShare,
  required Future<void> Function() onExport,
  required Future<void> Function() onSetAsAnniversary,
  required Future<void> Function() onDelete,
  Future<void> Function()? onSaveAsTemplate,
  Future<void> Function()? onOpenStyle,
}) {
  final l10n = context.l10n;
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) {
      final colorScheme = Theme.of(sheetContext).colorScheme;
      Widget item({
        required FaIcon icon,
        required Widget title,
        required Future<void> Function() action,
      }) {
        return ListTile(
          leading: icon,
          title: title,
          onTap: () async {
            Navigator.of(sheetContext).pop();
            await action();
          },
        );
      }

      return SafeArea(
        top: false,
        // 面板高度上限约 9/16 屏高，矮屏或横屏放不下全部操作时可滚动。
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              item(
                icon: const FaIcon(FontAwesomeIcons.shareNodes, size: 16),
                title: Text(l10n.previewShare),
                action: onShare,
              ),
              item(
                icon: const FaIcon(FontAwesomeIcons.fileExport, size: 16),
                title: Text(l10n.previewExport),
                action: onExport,
              ),
              item(
                icon: const FaIcon(FontAwesomeIcons.heart, size: 16),
                title: Text(l10n.previewSetAsAnniversary),
                action: onSetAsAnniversary,
              ),
              if (onSaveAsTemplate != null)
                item(
                  icon: const FaIcon(FontAwesomeIcons.layerGroup, size: 16),
                  title: Text(l10n.diaryTemplateSaveAs),
                  action: onSaveAsTemplate,
                ),
              if (onOpenStyle != null)
                item(
                  icon: const FaIcon(FontAwesomeIcons.swatchbook, size: 16),
                  title: Text(l10n.diaryPreviewStyleMoreEntry),
                  action: onOpenStyle,
                ),
              item(
                icon: FaIcon(
                  FontAwesomeIcons.trashCan,
                  size: 16,
                  color: colorScheme.error,
                ),
                title: Text(
                  l10n.commonDelete,
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.bodyLarge?.copyWith(color: colorScheme.error),
                ),
                action: onDelete,
              ),
            ],
          ),
        ),
      );
    },
  );
}
