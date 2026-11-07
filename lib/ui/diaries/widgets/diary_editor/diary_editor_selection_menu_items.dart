import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/services/text_process_actions_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../../controllers/diary_editor_clipboard.dart';
import '../../controllers/diary_editor_controller.dart';
import '../../controllers/diary_text_process_flow.dart';
import 'diary_editor_keyboard_hold.dart';

/// 日记正文选区菜单（手机胶囊与桌面右键菜单共用）的菜单项组装。
///
/// - 输入：正文控制器、收起菜单的 [dismiss] 与复制写完剪贴板后的 [afterCopy]
///   （手机收成光标、桌面保留选区，由调用方决定）。
/// - 输出：[AppTextMenuAction] 列表，归属决定它在哪一组 / 哪一行：
///   - 主行（primary）：剪切、复制、粘贴、全选。经
///     [appTextMenuActionsFromButtonItems] 映射，文字、图标与桌面快捷键提示
///     与输入框同源。有选中文字才有复制 / 剪切，可编辑才有剪切 / 粘贴（桌面
///     右键可落在光标上、手机长按可只落下光标，此时只有粘贴与全选），全选
///     始终有。
///   - lead：AI 写作，只在有选中文字、可编辑且编辑页给了处理函数时出现。
///   - 次要区（secondary）：有选中文字时的分享（只在手机，只读正文也有）与
///     其他应用的文字处理（只在 Android，[TextProcessActionsService.current]
///     的每一项）。
/// - 副作用：只在点按时发生；点按任何一项都先收起菜单。
List<AppTextMenuAction> diaryEditorSelectionMenuItems(
  BuildContext context,
  DiaryEditorController controller, {
  required VoidCallback dismiss,
  required VoidCallback afterCopy,
}) {
  final selection = controller.selection;
  final ranged = selection != null && !selection.isCollapsed;
  final editable = !controller.readOnly;
  final ai = controller.aiSelectionHandler;
  return <AppTextMenuAction>[
    ...appTextMenuActionsFromButtonItems(context, <ContextMenuButtonItem>[
      if (ranged && editable)
        ContextMenuButtonItem(
          type: ContextMenuButtonType.cut,
          onPressed: () {
            dismiss();
            unawaited(DiaryEditorClipboard.cut(controller));
          },
        ),
      if (ranged)
        ContextMenuButtonItem(
          type: ContextMenuButtonType.copy,
          onPressed: () => unawaited(
            DiaryEditorClipboard.copy(controller).then((_) => afterCopy()),
          ),
        ),
      if (editable)
        ContextMenuButtonItem(
          type: ContextMenuButtonType.paste,
          onPressed: () {
            dismiss();
            unawaited(DiaryEditorClipboard.paste(controller));
          },
        ),
      ContextMenuButtonItem(
        type: ContextMenuButtonType.selectAll,
        onPressed: () {
          dismiss();
          // 软键盘收着时全选不把它拉起来（只是选文字，不是要打字）。
          holdHiddenKeyboard(
            context,
            controller,
            () => af.selectAllCommand.handler(controller.state),
          );
        },
      ),
    ]),
    // AI 写作：对选中的文字使用（编辑页打开 AI 写作面板）。
    if (ranged && editable && ai != null)
      AppTextMenuAction(
        slot: AppTextMenuSlot.lead,
        label: context.l10n.aiSelectionMenu,
        icon: FontAwesomeIcons.wandMagicSparkles,
        onPressed: () {
          dismiss();
          ai();
        },
      ),
    // 分享与文字处理只看“有选中文字”就出现，要用的纯文本点按时才取（与复制
    // 同一口径）：手机拖动选区把手时菜单每帧都重建，全选后拖把手不能每帧把
    // 整篇正文序列化一遍。选中的全是空白时点分享只收起菜单。
    if (ranged) ...[
      ?appTextShareActionOf(
        context,
        () => DiaryEditorClipboard.selectedPlainText(controller),
        beforeShare: dismiss,
      ),
      for (final action in TextProcessActionsService.instance.current)
        appTextProcessAction(
          action,
          onPressed: () {
            // 先取下点按时的选区与文字，回写前据此核对正文没被改过。
            final at = controller.selection?.normalized;
            final source = DiaryEditorClipboard.selectedPlainText(controller);
            dismiss();
            if (at == null || source == null) return;
            unawaited(
              runDiaryTextProcessAction(
                controller,
                actionId: action.id,
                selection: at,
                text: source,
              ),
            );
          },
        ),
    ],
  ];
}
