import 'package:flutter/material.dart';

import '../../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../../l10n/app_localizations.dart';
import '../../models/diary_link_candidate.dart';
import '../diary_editor/diary_caret_menu.dart';
import 'diary_link_candidate_item.dart';

/// `@` / `[[` 候选列表的数据来源：正文光标旁的菜单
/// （`DiaryMentionMenuController`）与写留言面板（`DiaryCommentMentionController`）。
abstract interface class DiaryLinkCandidateSource implements Listenable {
  /// 候选；首次结果回来之前为 null。
  List<DiaryLinkCandidate>? get results;

  /// 键盘选中的一项（桌面 ↑ / ↓）。
  int get highlighted;

  /// 检索词（空词时列表末尾附上用法提示）。
  String get query;

  /// 选中一项。
  void pick(DiaryLinkCandidate candidate);
}

/// `@` / `[[` 的候选列表：按种类分组（日记本在前），键盘高亮的一行滚进
/// 可见范围；还没有结果时只有用法提示，没有匹配时为“没有结果”。正文的
/// 光标旁菜单与写留言面板的候选区共用。
class DiaryLinkCandidateList extends StatefulWidget {
  const DiaryLinkCandidateList({
    super.key,
    required this.menu,
    this.cardCaption,
    this.padding = const EdgeInsets.all(8),
  });

  final DiaryLinkCandidateSource menu;

  /// 卡片模式（只找一种）的小标题；给出时不再按种类分组。
  final String? cardCaption;

  final EdgeInsetsGeometry padding;

  @override
  State<DiaryLinkCandidateList> createState() => _DiaryLinkCandidateListState();
}

class _DiaryLinkCandidateListState extends State<DiaryLinkCandidateList> {
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
    final cardCaption = widget.cardCaption;
    final card = cardCaption != null;
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
      if (cardCaption != null) DiaryCaretMenuCaption(cardCaption, first: true),
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
        padding: widget.padding,
        children: children,
      ),
    );
  }
}
