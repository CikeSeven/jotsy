import 'dart:async';

import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'diary_block_commands.dart';
import 'diary_slash_menu.dart';
import '../../controllers/diary_editor_controller.dart';

/// 显式覆盖上游仅桌面的 `/` 事件：斜杠总是先写进正文。桌面用上游选区
/// 菜单（实体键盘上下选择）；手机开启内联菜单会话（[DiarySlashMenuController]），
/// 斜杠后接着输入的文字即筛选词，焦点与键盘不离开正文。
af.CharacterShortcutEvent diarySlashCommand({
  required DiaryEditorController controller,
  required BuildContext context,
  required List<DiaryBlockCommand> commands,
  required DiarySlashMenuController menu,
}) {
  return af.CharacterShortcutEvent(
    key: 'diary_slash_commands',
    character: '/',
    handler: (state) async {
      if (state.isDisposed) return false;
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
        final selectionMenu = af.SelectionMenu(
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
        unawaited(selectionMenu.show());
        return true;
      }
      menu.open(node, offset, commands);
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
