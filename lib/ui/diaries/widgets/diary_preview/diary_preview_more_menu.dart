import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/services/app_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../anniversaries/controllers/anniversary_navigation.dart';
import '../../../anniversaries/models/anniversary_draft.dart';
import '../../../todos/widgets/todo_convert_sheet.dart';
import '../../../todos/widgets/todo_quick_add_sheet.dart';
import '../../../notebooks/controllers/diary_notebook_pick_flow.dart';
import '../../../notebooks/viewmodels/notebook_view.dart';
import '../../../settings/pages/diary_preview_style_page.dart';
import '../../../settings/providers/app_features_provider.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';
import '../../controllers/diary_preview_export_controller.dart';
import '../../viewmodels/diary_preview_view_data.dart';

/// 预览页顶栏“更多”弹出菜单的条目：导出、收进日记本、设为纪念日、添加待办、
/// 转为独立待办 | 页面样式 | 删除。分享在顶栏上；写留言与 AI 回应在页尾的
/// 留言区、回应区各有一行入口，菜单里不再重复。
///
/// 在预览页的 build 里调用：功能开关与设置经 `ref.watch` 订阅，开关一变菜单
/// 随之更新（日记本、纪念日、待办功能关闭时隐藏对应入口，数据保留）。
/// [notebooks] 为这篇现在所在的本子，作“收进日记本”的说明；正文里的待办
/// 列表项取自 [viewData]（按正文记忆化，只在待办功能开启时才解析）。
/// “页面样式”打开预览页样式设置且第一篇示例就是这篇，设置尚未就绪时不显示。
List<Widget> diaryPreviewMoreItems(
  BuildContext context,
  WidgetRef ref, {
  required DiaryPreviewExportController export,
  required DiaryWithTags detail,
  required DiaryPreviewViewData viewData,
  required Future<void> Function() onDelete,
  List<NotebookView> notebooks = const <NotebookView>[],
}) {
  final l10n = context.l10n;
  final features = ref.watch(appFeaturesProvider);
  final settings = ref.watch(settingsServiceProvider).asData?.value;
  final todoItems = features.todos ? viewData.todoItems : null;
  return diaryMoreMenuItems(
    l10n,
    onExport: () => export.exportDiary(context, ref, detail: detail),
    onAddToNotebook: features.notebooks
        ? () =>
              pickNotebooksForDiary(context, ref, diaryId: detail.diary.diaryId)
        : null,
    notebookSummary: notebooks.isEmpty
        ? l10n.notebookPreviewNone
        : notebooks.map((n) => n.name).join(l10n.notebookListSeparator),
    onSetAsAnniversary: features.anniversariesEnabled
        ? () => openAnniversaryEditor(
            context,
            database: ref.read(appDatabaseProvider),
            draft: AnniversaryDraft.fromDiary(detail.diary),
          )
        : null,
    // 待办功能开启时：添加一条关联这篇的待办（标题预填日记标题）；正文里有
    // 待办列表项时再给“转为独立待办”。
    onAddTodo: features.todos
        ? () => showTodoQuickAddSheet(
            context,
            preset: TodoQuickAddPreset(
              title: detail.diary.title.trim(),
              linkedDiaryId: detail.diary.diaryId,
            ),
          )
        : null,
    onConvertTodos: todoItems != null && todoItems.isNotEmpty
        ? () => showTodoConvertSheet(
            context,
            diaryId: detail.diary.diaryId,
            items: todoItems,
          )
        : null,
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
    onDelete: onDelete,
  );
}

/// 预览页与阅读式编辑页“更多”弹出菜单（[ExpressiveMenuButton] 的条目）的
/// 统一排法，按组排列、组间画分隔线：
/// 1. 这篇日记的动作：[leading]（编辑页的“编辑信息”）、分享、导出、写留言、
///    收进日记本（[notebookSummary] 为一行说明）、设为纪念日、添加待办、
///    转为独立待办、另存为模板；
/// 2. 写作辅助 [tools]（编辑页的这天的照片与 AI 二级菜单）；
/// 3. 页面样式（预览页）与 [settings]（编辑页的编辑器设置）；
/// 4. 删除（error 色）。
///
/// 回调为 null 的项不出现（功能关闭、设置未就绪或这一页不提供），空组不画
/// 分隔线。条目点按时先经锚点收起菜单再执行（见 [ExpressiveMenuItem]），动作
/// 自己处理后续（对话框、面板、新页面），这里不等待。
List<Widget> diaryMoreMenuItems(
  AppLocalizations l10n, {
  required Future<void> Function() onDelete,
  List<Widget> leading = const <Widget>[],
  Future<void> Function()? onShare,
  Future<void> Function()? onExport,
  Future<void> Function()? onWriteComment,
  Future<void> Function()? onAddToNotebook,
  String? notebookSummary,
  Future<void> Function()? onSetAsAnniversary,
  Future<void> Function()? onAddTodo,
  Future<void> Function()? onConvertTodos,
  Future<void> Function()? onSaveAsTemplate,
  List<Widget> tools = const <Widget>[],
  Future<void> Function()? onOpenStyle,
  List<Widget> settings = const <Widget>[],
}) {
  final groups = <List<Widget>>[
    <Widget>[
      ...leading,
      if (onShare != null)
        diaryMoreMenuEntry(
          FontAwesomeIcons.shareNodes,
          l10n.previewShare,
          onShare,
        ),
      if (onExport != null)
        diaryMoreMenuEntry(
          FontAwesomeIcons.fileExport,
          l10n.previewExport,
          onExport,
        ),
      if (onWriteComment != null)
        diaryMoreMenuEntry(
          FontAwesomeIcons.comment,
          l10n.diaryCommentSheetNew,
          onWriteComment,
        ),
      if (onAddToNotebook != null)
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.bookBookmark),
          summary: notebookSummary == null
              ? null
              : Text(
                  notebookSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
          onPressed: () => unawaited(onAddToNotebook()),
          child: Text(l10n.notebookPickerTitle),
        ),
      if (onSetAsAnniversary != null)
        diaryMoreMenuEntry(
          FontAwesomeIcons.heart,
          l10n.previewSetAsAnniversary,
          onSetAsAnniversary,
        ),
      if (onAddTodo != null)
        diaryMoreMenuEntry(
          FontAwesomeIcons.squareCheck,
          l10n.diaryPreviewAddTodo,
          onAddTodo,
        ),
      if (onConvertTodos != null)
        diaryMoreMenuEntry(
          FontAwesomeIcons.listCheck,
          l10n.diaryPreviewConvertTodos,
          onConvertTodos,
        ),
      if (onSaveAsTemplate != null)
        diaryMoreMenuEntry(
          FontAwesomeIcons.layerGroup,
          l10n.diaryTemplateSaveAs,
          onSaveAsTemplate,
        ),
    ],
    tools,
    <Widget>[
      if (onOpenStyle != null)
        diaryMoreMenuEntry(
          FontAwesomeIcons.swatchbook,
          l10n.diaryPreviewStyleMoreEntry,
          onOpenStyle,
        ),
      ...settings,
    ],
    <Widget>[
      ExpressiveMenuItem(
        leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
        destructive: true,
        onPressed: () => unawaited(onDelete()),
        child: Text(l10n.commonDelete),
      ),
    ],
  ];
  final items = <Widget>[];
  for (final group in groups) {
    if (group.isEmpty) continue;
    if (items.isNotEmpty) items.add(const ExpressiveMenuDivider());
    items.addAll(group);
  }
  return items;
}

/// “更多”菜单里的一项：图标、文字与动作；[action] 为 null 时条目禁用（如
/// 编辑页保存或导入媒体期间的写作辅助）。
Widget diaryMoreMenuEntry(
  FaIconData icon,
  String label,
  Future<void> Function()? action,
) {
  return ExpressiveMenuItem(
    leadingIcon: FaIcon(icon),
    onPressed: action == null ? null : () => unawaited(action()),
    child: Text(label),
  );
}

/// 预览页的分享入口：顶栏分享按钮（预览页与阅读式编辑页）与编辑页“更多 →
/// 分享”共用，打开同一个分享面板（指定应用、系统分享、复制文字与长图，见
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
