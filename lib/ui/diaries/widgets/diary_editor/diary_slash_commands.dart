import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'diary_block_commands.dart';
import 'diary_command_sheet.dart';
import '../../controllers/diary_editor_controller.dart';

/// 显式覆盖上游仅桌面的 `/` 事件。手机面板的搜索字不进入正文，取消保留
/// 用户输入的斜杠；执行时只删除仍在原节点上的触发字符，避免异步返回覆盖
/// 已变动或已销毁的会话。
af.CharacterShortcutEvent diarySlashCommand({
  required DiaryEditorController controller,
  required BuildContext context,
  required List<DiaryBlockCommand> commands,
  FocusNode? focusNode,
}) {
  var opened = false;
  return af.CharacterShortcutEvent(
    key: 'diary_slash_commands',
    character: '/',
    handler: (state) async {
      if (opened || state.isDisposed) return false;
      final selection = state.selection;
      if (selection == null || !selection.isCollapsed) return false;
      final node = state.document.nodeAtPath(selection.end.path);
      if (node?.delta == null || node!.type == 'code') return false;
      final offset = selection.end.offset;
      final text = node.delta!.toPlainText();
      if (offset > 0 && text[offset - 1].trim().isNotEmpty) return false;
      await state.insertTextAtPosition('/');
      if (state.isDisposed || !context.mounted) return true;
      final platform = Theme.of(context).platform;
      if (kIsWeb ||
          (platform != TargetPlatform.android &&
              platform != TargetPlatform.iOS)) {
        final menu = af.SelectionMenu(
          context: context,
          editorState: state,
          singleColumn: true,
          deleteKeywordsByDefault: true,
          style: _style(Theme.of(context).colorScheme),
          selectionMenuItems: [
            for (final command in commands)
              af.SelectionMenuItem(
                getName: () => command.label,
                keywords: [command.type, ...command.keywords],
                icon: (_, selected, style) => FaIcon(
                  command.icon,
                  size: 16,
                  color: selected
                      ? style.selectionMenuItemSelectedIconColor
                      : style.selectionMenuItemIconColor,
                ),
                handler: (_, menu, context) async =>
                    applyDiaryBlockCommand(controller, command),
              ),
          ],
        );
        unawaited(menu.show());
        return true;
      }
      opened = true;
      final afterSlash = state.selection;
      final command = await showModalBottomSheet<DiaryBlockCommand>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => DiaryCommandSheet(commands: commands),
      );
      opened = false;
      if (state.isDisposed || !context.mounted || node.parent == null) {
        return true;
      }
      if (command != null &&
          offset < (node.delta?.length ?? 0) &&
          node.delta!.toPlainText()[offset] == '/') {
        final transaction = state.transaction
          ..deleteText(node, offset, 1)
          ..afterSelection = af.Selection.collapsed(
            af.Position(path: node.path, offset: offset),
          );
        controller.apply(transaction);
        applyDiaryBlockCommand(controller, command);
      } else if (afterSlash != null) {
        controller.select(afterSlash);
      }
      focusNode?.requestFocus();
      return true;
    },
  );
}

af.SelectionMenuStyle _style(ColorScheme colors) => af.SelectionMenuStyle(
  selectionMenuBackgroundColor: colors.surfaceContainerHigh,
  selectionMenuItemTextColor: colors.onSurface,
  selectionMenuItemIconColor: colors.primary,
  selectionMenuItemSelectedTextColor: colors.onPrimaryContainer,
  selectionMenuItemSelectedIconColor: colors.onPrimaryContainer,
  selectionMenuItemSelectedColor: colors.primaryContainer,
  selectionMenuUnselectedLabelColor: colors.onSurfaceVariant,
  selectionMenuDividerColor: colors.outlineVariant,
  selectionMenuLinkBorderColor: colors.outlineVariant,
  selectionMenuInvalidLinkColor: colors.error,
  selectionMenuButtonColor: colors.primary,
  selectionMenuButtonTextColor: colors.onPrimary,
  selectionMenuButtonIconColor: colors.onPrimary,
  selectionMenuButtonBorderColor: colors.outlineVariant,
  selectionMenuTabIndicatorColor: colors.primary,
);
