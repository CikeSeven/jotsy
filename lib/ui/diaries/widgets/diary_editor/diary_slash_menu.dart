import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import 'diary_block_commands.dart';
import 'diary_caret_menu.dart';

/// 手机上的 `/` 命令会话（会话边界与浮层见 [DiaryCaretMenuSession] /
/// [DiaryCaretMenuHost]）：斜杠后接着输入的文字（如 `/代码`、`/h2`）就是
/// 筛选词，选中命令时删掉 `/筛选词` 再执行。
class DiarySlashMenuController extends DiaryCaretMenuSession {
  DiarySlashMenuController(super.editor);

  List<DiaryBlockCommand> _commands = const [];

  @override
  String get triggerCharacter => '/';

  @override
  bool hasMatchesFor(String query) =>
      _commands.any((command) => command.matches(query));

  /// 按筛选词过滤后的命令，保持定义顺序（分组顺序）。
  List<DiaryBlockCommand> get matches =>
      _commands.where((command) => command.matches(query)).toList();

  void open(af.Node node, int slashOffset, List<DiaryBlockCommand> commands) {
    _commands = commands;
    openAt(node, slashOffset);
  }

  /// 删掉 `/筛选词`，再按命令转换当前块或插入内容。
  void run(DiaryBlockCommand command) {
    if (consumeTrigger() == null) return;
    applyDiaryBlockCommand(editor, command);
  }
}

/// `/` 菜单浮层：[DiaryCaretMenuHost] + 命令列表。
class DiarySlashMenuHost extends StatelessWidget {
  const DiarySlashMenuHost({
    super.key,
    required this.menu,
    required this.coveredHeight,
    required this.child,
  });

  final DiarySlashMenuController menu;

  /// 叠在正文底部的浮层（工具栏等）高度，菜单不压在它们上面。
  final double coveredHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => DiaryCaretMenuHost(
    session: menu,
    coveredHeight: coveredHeight,
    menu: (_) => _SlashMenuList(menu: menu),
    child: child,
  );
}

class _SlashMenuList extends StatelessWidget {
  const _SlashMenuList({required this.menu});

  final DiarySlashMenuController menu;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final matches = menu.matches;
    final grouped = menu.query.isEmpty;
    if (matches.isEmpty) {
      return DiaryCaretMenuEmpty(l10n.diaryEditorCommandEmpty);
    }
    final children = <Widget>[];
    DiaryBlockCommandGroup? group;
    for (final command in matches) {
      if (grouped && command.group != group) {
        group = command.group;
        children.add(
          DiaryCaretMenuCaption(
            diaryBlockCommandGroupLabel(l10n, command.group),
            first: children.isEmpty,
          ),
        );
      }
      children.add(
        _SlashMenuItem(command: command, onTap: () => menu.run(command)),
      );
    }
    if (grouped) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            l10n.diaryEditorCommandTypeToFilter,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return Semantics(
      label: l10n.diaryEditorSlashCommands,
      explicitChildNodes: true,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(8),
        children: children,
      ),
    );
  }
}

/// 命令行：图标块 + 名称 + 行尾 Markdown 写法（行的外形见 [DiaryCaretMenuItem]）。
class _SlashMenuItem extends StatelessWidget {
  const _SlashMenuItem({required this.command, required this.onTap});

  final DiaryBlockCommand command;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final markdown = command.markdown;
    return DiaryCaretMenuItem(
      onTap: onTap,
      leading: _CommandIcon(command: command),
      child: Row(
        children: [
          Expanded(
            child: Text(
              command.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (markdown != null) ...[
            const SizedBox(width: 8),
            ExcludeSemantics(
              child: Text(
                markdown,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontFamily: 'monospace',
                  fontFamilyFallback: const ['Menlo', 'Consolas'],
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

/// 标题命令在图标上叠一个小号级别数字，三级标题一眼可分。
class _CommandIcon extends StatelessWidget {
  const _CommandIcon({required this.command});

  final DiaryBlockCommand command;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final level = command.attributes['level'];
    if (command.type != 'heading' || level is! int) {
      return FaIcon(command.icon, size: 14, color: colors.onSecondaryContainer);
    }
    return Text(
      'H$level',
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: colors.onSecondaryContainer,
        fontWeight: FontWeight.w700,
        height: 1,
      ),
    );
  }
}
