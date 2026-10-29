import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';

import '../../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../../l10n/app_localizations.dart';
import '../../controllers/diary_editor_controller.dart';
import '../../controllers/diary_link_editing.dart';
import '../../controllers/diary_link_search.dart';
import '../../models/diary_link_candidate.dart';
import '../diary_link/diary_link_candidate_item.dart';
import 'diary_caret_menu.dart';

/// `@` 会话插入的是什么：行内链接（打字触发）或卡片（`/` 菜单的
/// “日记卡片 / 日记本卡片”）。
enum DiaryMentionMode { inline, card }

/// `@` 日记链接会话：`@` 写进正文后，接着输入的文字就是检索词，候选浮在
/// 光标旁（会话边界与浮层见 [DiaryCaretMenuSession] / [DiaryCaretMenuHost]）。
///
/// 候选经 [DiaryLinkSearchController] 防抖查询；[highlighted] 是键盘选中的
/// 一项（桌面 ↑ / ↓，Enter / Tab 与软键盘回车确认），候选变化时回到第一项。
/// 选中后删掉 `@检索词`，按 [mode] 写入行内链接或卡片（一步撤销）。
class DiaryMentionMenuController extends DiaryCaretMenuSession {
  DiaryMentionMenuController(super.editor, {required DiaryLinkSearch search})
    : _search = DiaryLinkSearchController(search, kinds: const {}) {
    _search.addListener(_onResults);
  }

  final DiaryLinkSearchController _search;
  DiaryMentionMode _mode = DiaryMentionMode.inline;
  int _highlighted = 0;

  @override
  String get triggerCharacter => '@';

  /// 日记标题常比命令名长，放宽到 32 字。
  @override
  int get maxQueryLength => 32;

  /// 标题里常有空格：结果还没回来时不结束，回来后以空格结尾且没有候选才结束。
  @override
  bool hasMatchesFor(String query) => _search.results?.isNotEmpty ?? true;

  DiaryMentionMode get mode => _mode;
  Set<DiaryLinkKind> get kinds => _search.kinds;

  /// 候选；首次结果回来之前为 null。
  List<DiaryLinkCandidate>? get results => _search.results;
  int get highlighted => _highlighted;

  /// 开启会话：[node] 的 [offset] 处已写好 `@`。
  void open(
    af.Node node,
    int offset, {
    required Set<DiaryLinkKind> kinds,
    DiaryMentionMode mode = DiaryMentionMode.inline,
  }) {
    close();
    _mode = mode;
    _search.kinds = kinds;
    openAt(node, offset);
  }

  /// 在光标处写一个 `@` 并以卡片模式开启（`/` 菜单的卡片命令）。光标不在
  /// 文字块里（如选中了媒体）时什么也不做。
  Future<void> openCardAtCaret(Set<DiaryLinkKind> kinds) async {
    final selection = editor.selection?.normalized;
    if (selection == null || editor.readOnly || editor.isDisposed) return;
    final end = selection.end;
    final node = editor.document.nodeAtPath(end.path);
    if (node?.delta == null || node!.type == 'code') return;
    await editor.state.insertTextAtPosition('@', position: end);
    if (editor.isDisposed) return;
    open(node, end.offset, kinds: kinds, mode: DiaryMentionMode.card);
  }

  @override
  void onQueryChanged() {
    _highlighted = 0;
    _search.update(query, force: true);
  }

  @override
  void onClosed() => _search.reset();

  void _onResults() {
    final count = results?.length ?? 0;
    _highlighted = count == 0 ? 0 : _highlighted.clamp(0, count - 1);
    if (isOpen) notifyListeners();
  }

  /// 键盘移动高亮（首尾循环）；没有候选时返回 false，按键交还正文。
  bool moveHighlight(int delta) {
    final count = results?.length ?? 0;
    if (!isOpen || count == 0) return false;
    _highlighted = (_highlighted + delta) % count;
    if (_highlighted < 0) _highlighted += count;
    notifyListeners();
    return true;
  }

  /// 确认高亮项；没有候选时返回 false（回车照常换行）。
  bool confirm() {
    final list = results;
    if (!isOpen || list == null || list.isEmpty) return false;
    pick(list[_highlighted.clamp(0, list.length - 1)]);
    return true;
  }

  /// 删掉 `@检索词`，按模式写入 [candidate]。
  void pick(DiaryLinkCandidate candidate) {
    final mode = _mode;
    final at = consumeTrigger();
    if (at == null || editor.isDisposed) return;
    switch (mode) {
      case DiaryMentionMode.inline:
        insertDiaryInlineLink(editor, at, candidate.target, candidate.label);
      case DiaryMentionMode.card:
        insertDiaryLinkCard(editor, candidate.target, candidate.label);
    }
  }

  @override
  void dispose() {
    _search.removeListener(_onResults);
    super.dispose();
    _search.dispose();
  }
}

/// 打字触发 `@`：规则同 `/`（前一个字是空白或行首、不在代码块里），先把
/// `@` 写进正文再开启会话；[kinds] 在触发时读取（随日记本功能开关）。
af.CharacterShortcutEvent diaryMentionCommand({
  required DiaryEditorController controller,
  required DiaryMentionMenuController menu,
  required Set<DiaryLinkKind> Function() kinds,
}) {
  return af.CharacterShortcutEvent(
    key: 'diary_mention',
    character: '@',
    handler: (state) async {
      if (state.isDisposed || controller.linkSource == null) return false;
      final selection = state.selection;
      if (selection == null || !selection.isCollapsed) return false;
      final node = state.document.nodeAtPath(selection.end.path);
      if (node?.delta == null || node!.type == 'code') return false;
      final offset = selection.end.offset;
      final text = node.delta!.toPlainText();
      if (offset > 0 && text[offset - 1].trim().isNotEmpty) return false;
      await state.insertTextAtPosition('@');
      if (state.isDisposed) return true;
      menu.open(node, offset, kinds: kinds());
      return true;
    },
  );
}

/// 会话开着且有候选时，回车确认高亮项（软键盘与桌面的回车都经字符事件
/// 送来）；否则交给后面的事件照常换行。须排在字符事件最前面。
af.CharacterShortcutEvent diaryMentionEnterCommand(
  DiaryMentionMenuController menu,
) {
  return af.CharacterShortcutEvent(
    key: 'diary_mention_enter',
    character: '\n',
    handler: (_) async => menu.confirm(),
  );
}

/// 桌面：会话开着时 ↑ / ↓ 移动高亮、Tab 确认；会话没开或没有候选时交还
/// 上游（移动光标、缩进）。须排在上游同键事件之前。
List<af.CommandShortcutEvent> diaryMentionCommandShortcuts(
  DiaryMentionMenuController menu,
) => [
  for (final (name, command, delta) in [
    ('up', 'arrow up', -1),
    ('down', 'arrow down', 1),
  ])
    af.CommandShortcutEvent(
      key: 'diary_mention_$name',
      getDescription: () => 'move the @ menu highlight $name',
      command: command,
      handler: (_) => menu.moveHighlight(delta)
          ? KeyEventResult.handled
          : KeyEventResult.ignored,
    ),
  af.CommandShortcutEvent(
    key: 'diary_mention_tab',
    getDescription: () => 'pick the highlighted @ candidate',
    command: 'tab',
    handler: (_) =>
        menu.confirm() ? KeyEventResult.handled : KeyEventResult.ignored,
  ),
];

/// `@` 菜单浮层：[DiaryCaretMenuHost] + 候选列表。
class DiaryMentionMenuHost extends StatelessWidget {
  const DiaryMentionMenuHost({
    super.key,
    required this.menu,
    required this.coveredHeight,
    required this.child,
  });

  final DiaryMentionMenuController menu;

  /// 叠在正文底部的浮层（工具栏等）高度，菜单不压在它们上面。
  final double coveredHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => DiaryCaretMenuHost(
    session: menu,
    coveredHeight: coveredHeight,
    menu: (_) => _MentionMenuList(menu: menu),
    child: child,
  );
}

class _MentionMenuList extends StatefulWidget {
  const _MentionMenuList({required this.menu});

  final DiaryMentionMenuController menu;

  @override
  State<_MentionMenuList> createState() => _MentionMenuListState();
}

class _MentionMenuListState extends State<_MentionMenuList> {
  final GlobalKey _highlightedKey = GlobalKey();
  int? _revealed;

  /// 键盘移动高亮后，把那一行滚进可见范围（列表比菜单高时）。
  void _revealHighlighted(int index) {
    if (_revealed == index) return;
    _revealed = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _highlightedKey.currentContext;
      if (!mounted || row == null) return;
      Scrollable.ensureVisible(
        row,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      Scrollable.ensureVisible(
        row,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final menu = widget.menu;
    final results = menu.results;
    final card = menu.mode == DiaryMentionMode.card;
    final hint = Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Text(
        l10n.diaryLinkMenuHint,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    final children = <Widget>[
      if (card)
        DiaryCaretMenuCaption(
          menu.kinds.contains(DiaryLinkKind.notebook)
              ? l10n.diaryEditorNotebookCard
              : l10n.diaryEditorDiaryCard,
          first: true,
        ),
    ];
    if (results == null) {
      children.add(hint);
    } else if (results.isEmpty) {
      children.add(DiaryCaretMenuEmpty(l10n.diaryLinkEmpty));
    } else {
      DiaryLinkKind? group;
      for (final (index, candidate) in results.indexed) {
        // 卡片模式只有一种，不再分组。
        if (!card && candidate.kind != group) {
          group = candidate.kind;
          children.add(
            DiaryCaretMenuCaption(
              group == DiaryLinkKind.notebook
                  ? l10n.diaryLinkGroupNotebooks
                  : l10n.diaryLinkGroupDiaries,
              first: children.isEmpty,
            ),
          );
        }
        final highlighted = index == menu.highlighted;
        children.add(
          DiaryLinkCandidateItem(
            key: highlighted ? _highlightedKey : null,
            candidate: candidate,
            highlighted: highlighted,
            onTap: () => menu.pick(candidate),
          ),
        );
      }
      _revealHighlighted(menu.highlighted);
      if (menu.query.isEmpty) children.add(hint);
    }
    return Semantics(
      label: l10n.diaryLinkMenuLabel,
      explicitChildNodes: true,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(8),
        children: children,
      ),
    );
  }
}
