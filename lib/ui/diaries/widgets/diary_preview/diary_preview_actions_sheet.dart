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
import '../../../home/widgets/home_hint_visibility_scope.dart';
import '../../../notebooks/controllers/notebook_membership_ops.dart';
import '../../../notebooks/providers/notebook_providers.dart';
import '../../../notebooks/sections/notebook_picker_sheet.dart';
import '../../../notebooks/viewmodels/notebook_view.dart';
import '../../../settings/pages/diary_preview_style_page.dart';
import '../../../settings/providers/app_features_provider.dart';
import '../../controllers/diary_preview_export_controller.dart';
import '../../models/publish_metadata_composer.dart';

/// 预览页“更多”的完整接线：分享与导出经 [export]（分享面板里可选长图），
/// “收进日记本”打开收录选择器（[notebooks] 为这篇现在所在的本子，用作说明），
/// 设为纪念日经数据库，存为模板打开预填好的模板编辑页（去掉媒体），“页面样式”打开预览页样式设置且第一篇示例就是这篇
/// （设置尚未就绪时不显示这一项）。[ref] 属于预览页本身，页面卸载后不再使用。
Future<void> showDiaryPreviewMore(
  BuildContext context,
  WidgetRef ref, {
  required DiaryPreviewExportController export,
  required DiaryWithTags detail,
  required Color background,
  required Future<void> Function() onDelete,
  List<NotebookView> notebooks = const <NotebookView>[],
}) {
  final database = ref.read(appDatabaseProvider);
  final l10n = context.l10n;
  final settings = ref.read(settingsServiceProvider).asData?.value;
  // 日记本、纪念日、日记模板功能关闭时隐藏入口，数据保留：不给“收进
  // 日记本”“设为纪念日”“另存为模板”。
  final features = ref.read(appFeaturesProvider);
  final notebooksEnabled = features.notebooks;
  return showDiaryPreviewActionsSheet(
    context,
    onShare: () => openDiaryPreviewShare(
      context,
      ref,
      export: export,
      detail: detail,
      background: background,
    ),
    onExport: () => export.exportDiary(context, ref, detail: detail),
    notebookSubtitle: notebooks.isEmpty
        ? l10n.notebookPreviewNone
        : notebooks.map((n) => n.name).join(l10n.notebookListSeparator),
    onAddToNotebook: notebooksEnabled
        ? () => _addToNotebooks(context, ref, diaryId: detail.diary.diaryId)
        : null,
    onSetAsAnniversary: features.anniversariesEnabled
        ? () => openAnniversaryEditor(
            context,
            database: database,
            draft: AnniversaryDraft.fromDiary(detail.diary),
          )
        : null,
    onSaveAsTemplate: features.templates
        ? () {
            final meta = PublishMetadataComposer.parse(detail.diary.metadata);
            return openSaveAsTemplate(
              context,
              title: detail.diary.title,
              contentDocJson: detail.diary.content,
              tags: detail.tags,
              mood: meta.moodEmoji,
              energy: meta.energyLevel,
            );
          }
        : null,
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

/// 预览页“收进日记本”：选择器的初始勾选为这篇现在所在的本子，确认后一次
/// 写入全部变化并提示（收进私密日记本时说明它只在那本里显示）。
Future<void> _addToNotebooks(
  BuildContext context,
  WidgetRef ref, {
  required String diaryId,
}) async {
  final database = ref.read(appDatabaseProvider);
  final current = await database.getDiaryNotebookIds(diaryId);
  if (!context.mounted) return;
  final result = await showNotebookPickerSheet(
    context,
    initial: <String, NotebookPickState>{
      for (final id in current) id: NotebookPickState.all,
    },
  );
  if (result == null || !context.mounted) return;
  final l10n = context.l10n;
  final notebooks = ref.read(notebooksProvider).value ?? const <NotebookView>[];
  String message;
  try {
    await NotebookMembershipOps(database).apply(result, <String>[diaryId]);
    ref.invalidate(diaryNotebooksProvider(diaryId));
    message =
        notebookPrivateAddedHint(l10n, result.add, notebooks) ??
        (result.remove.isEmpty
            ? l10n.notebookAddedToCount(result.add.length)
            : l10n.notebookMembershipUpdated);
  } catch (error) {
    debugPrint('Updating diary notebooks failed: $error');
    message = l10n.notebookActionFailed;
  }
  if (!context.mounted) return;
  await HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
    ),
  );
}

/// 预览页的分享入口：顶栏分享按钮与“更多 → 分享”共用，打开同一个分享
/// 面板（指定应用、系统分享、复制文字与长图，见
/// `DiaryPreviewExportController.openShareSheet`）。[background] 为长图底色。
Future<void> openDiaryPreviewShare(
  BuildContext context,
  WidgetRef ref, {
  required DiaryPreviewExportController export,
  required DiaryWithTags detail,
  required Color background,
}) async {
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
}

/// 预览页“更多”面板：分享、导出、收进日记本、设为纪念日、存为模板、页面
/// 样式与删除。可选项的回调为 null 时不显示这一项（功能关闭或设置未就绪）。
///
/// 每一项先关闭面板，再执行对应动作（分享面板里选了长图时，截图要等面板
/// 完全退场，见 `DiaryPreviewExportController.openShareSheet`）。
Future<void> showDiaryPreviewActionsSheet(
  BuildContext context, {
  required Future<void> Function() onShare,
  required Future<void> Function() onExport,
  required Future<void> Function() onDelete,
  Future<void> Function()? onSetAsAnniversary,
  Future<void> Function()? onSaveAsTemplate,
  Future<void> Function()? onOpenStyle,
  Future<void> Function()? onAddToNotebook,
  String? notebookSubtitle,
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
        Widget? subtitle,
      }) {
        return ListTile(
          leading: icon,
          title: title,
          subtitle: subtitle,
          titleAlignment: ListTileTitleAlignment.center,
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
              if (onAddToNotebook != null)
                item(
                  icon: const FaIcon(FontAwesomeIcons.bookBookmark, size: 16),
                  title: Text(l10n.notebookPickerTitle),
                  subtitle: notebookSubtitle == null
                      ? null
                      : Text(
                          notebookSubtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  action: onAddToNotebook,
                ),
              if (onSetAsAnniversary != null)
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
