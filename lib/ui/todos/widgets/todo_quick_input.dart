import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../widgets/expressive_entrance.dart';
import '../../../core/database/app_database.dart';
import '../viewmodels/todo_quick_parse.dart';
import 'todo_labels.dart';

/// 快速新建的输入框控制器：把智能识别出的片段（[highlights]）画成
/// `secondaryContainer` 底的高亮（与下面识别结果的胶囊同色）。
///
/// 新认出片段时高亮淡入：宿主给 [fade]（0~1 的动画），在片段变多时从 0
/// 重新播；没给时直接显示。
///
/// 输入法正在组字（composing 区间非空）时不加高亮、交回默认的组字下划线：
/// 组字期间文字随时会变，片段位置跟着变，自己拼 span 会让组字区的下划线
/// 与候选对不上。
class TodoQuickInputController extends TextEditingController {
  TodoQuickInputController({super.text});

  List<TextRange> _highlights = const <TextRange>[];

  Animation<double>? _fade;

  /// 高亮的淡入进度（宿主持有、播放）。
  set fade(Animation<double>? value) {
    if (identical(value, _fade)) return;
    _fade?.removeListener(notifyListeners);
    _fade = value?..addListener(notifyListeners);
  }

  /// 要高亮的片段（在当前文字里的位置）。
  set highlights(List<TextRange> value) {
    if (_sameRanges(value, _highlights)) return;
    _highlights = value;
    notifyListeners();
  }

  /// 是否多认出了片段（宿主据此重新播 [fade]）。
  bool gainsHighlights(List<TextRange> value) =>
      value.any((TextRange range) => !_highlights.contains(range));

  @override
  void dispose() {
    _fade?.removeListener(notifyListeners);
    super.dispose();
  }

  static bool _sameRanges(List<TextRange> a, List<TextRange> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final composing = value.composing;
    if (_highlights.isEmpty ||
        (withComposing && composing.isValid && !composing.isCollapsed)) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final t = _fade?.value ?? 1;
    final mark = TextStyle(
      backgroundColor: scheme.secondaryContainer.withValues(
        alpha: scheme.secondaryContainer.a * t,
      ),
      color: Color.lerp(
        style?.color ?? scheme.onSurface,
        scheme.onSecondaryContainer,
        t,
      ),
    );
    final text = this.text;
    final children = <TextSpan>[];
    var cursor = 0;
    for (final range in _highlights) {
      if (!range.isValid ||
          range.start < cursor ||
          range.end > text.length ||
          range.isCollapsed) {
        continue;
      }
      if (range.start > cursor) {
        children.add(TextSpan(text: text.substring(cursor, range.start)));
      }
      children.add(TextSpan(text: range.textInside(text), style: mark));
      cursor = range.end;
    }
    if (cursor < text.length) {
      children.add(TextSpan(text: text.substring(cursor)));
    }
    return TextSpan(style: style, children: children);
  }
}

/// 按设置决定识不识别：关闭“智能识别”时整段文字就是标题。
TodoQuickParse todoQuickParseOf(
  String text, {
  required bool enabled,
  required DateTime today,
  required List<TodoListRow> lists,
  List<String> tags = const <String>[],
  Set<TodoQuickTokenKind> ignore = const <TodoQuickTokenKind>{},
  Set<String> ignoreTags = const <String>{},
}) {
  if (!enabled || text.trim().isEmpty) {
    return parseTodoQuickInput(
      text,
      today: today,
      ignore: TodoQuickTokenKind.values.toSet(),
    );
  }
  return parseTodoQuickInput(
    text,
    today: today,
    lists: <String, String>{for (final list in lists) list.listId: list.name},
    tags: tags,
    ignore: ignore,
    ignoreTags: ignoreTags,
  );
}

/// 识别结果的一排小胶囊（`secondaryContainer` 底、带 ×）：日期（含时刻）、
/// 重复、提醒、清单、优先级各一个，标签每个一颗；点 × 经 [onDismiss] 交出
/// 这一种（调用方把它加进忽略集合，原文留在标题里），标签经 [onDismissTag]
/// 单个交出。新出现的胶囊淡入上移（按种类认，
/// 值变了不重演）。没有识别出东西时为空。
class TodoParsedChips extends StatelessWidget {
  const TodoParsedChips({
    super.key,
    required this.parse,
    required this.today,
    required this.lists,
    required this.onDismiss,
    required this.onDismissTag,
    this.allDayMinute = 9 * 60,
  });

  final TodoQuickParse parse;
  final DateTime today;
  final List<TodoListRow> lists;
  final ValueChanged<TodoQuickTokenKind> onDismiss;
  final ValueChanged<String> onDismissTag;

  /// 全天待办的默认提醒时刻（识别出“提前一天”时用）。
  final int allDayMinute;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final chips = <Widget>[];
    final date = parse.date;
    if (date != null) {
      final hasTime = parse.tokens.any(
        (t) => t.kind == TodoQuickTokenKind.time,
      );
      final hasDate = parse.tokens.any(
        (t) => t.kind == TodoQuickTokenKind.date,
      );
      chips.add(
        _ParsedChip(
          key: const ValueKey<String>('due'),
          icon: parse.minute == null
              ? FontAwesomeIcons.calendar
              : FontAwesomeIcons.clock,
          label: TodoLabels.due(context, date, parse.minute, today),
          tooltip: l10n.todoQuickParseDismiss,
          onDismiss: () {
            // 只识别出时刻时（日期取今天）点掉的是时刻；有日期时连同时刻
            // 一起不识别。
            if (hasDate) onDismiss(TodoQuickTokenKind.date);
            if (hasTime) onDismiss(TodoQuickTokenKind.time);
          },
        ),
      );
    }
    final repeat = parse.repeatRule;
    if (repeat != null) {
      chips.add(
        _ParsedChip(
          key: const ValueKey<String>('repeat'),
          icon: FontAwesomeIcons.repeat,
          label: TodoLabels.repeat(l10n, repeat),
          tooltip: l10n.todoQuickParseDismiss,
          onDismiss: () => onDismiss(TodoQuickTokenKind.repeat),
        ),
      );
    }
    final reminder = parse.reminder?.resolve(
      dueMinute: parse.minute,
      allDayMinute: allDayMinute,
    );
    if (reminder != null) {
      chips.add(
        _ParsedChip(
          key: const ValueKey<String>('reminder'),
          icon: FontAwesomeIcons.bell,
          label: TodoLabels.reminder(context, reminder),
          tooltip: l10n.todoQuickParseDismiss,
          onDismiss: () => onDismiss(TodoQuickTokenKind.reminder),
        ),
      );
    }
    final listId = parse.listId;
    if (listId != null) {
      String? name;
      for (final list in lists) {
        if (list.listId == listId) name = list.name;
      }
      if (name != null) {
        chips.add(
          _ParsedChip(
            key: const ValueKey<String>('list'),
            icon: FontAwesomeIcons.hashtag,
            label: name,
            tooltip: l10n.todoQuickParseDismiss,
            onDismiss: () => onDismiss(TodoQuickTokenKind.list),
          ),
        );
      }
    }
    for (final tag in parse.tags) {
      chips.add(
        _ParsedChip(
          key: ValueKey<String>('tag:${TodoTags.keyOf(tag)}'),
          icon: FontAwesomeIcons.at,
          label: tag,
          tooltip: l10n.todoQuickParseDismiss,
          onDismiss: () => onDismissTag(tag),
        ),
      );
    }
    final priority = parse.priority;
    if (priority != null && priority != TodoPriority.none) {
      chips.add(
        _ParsedChip(
          key: const ValueKey<String>('priority'),
          icon: FontAwesomeIcons.solidFlag,
          iconColor: TodoLabels.priorityColor(scheme, priority),
          label: TodoLabels.priority(l10n, priority),
          tooltip: l10n.todoQuickParseDismiss,
          onDismiss: () => onDismiss(TodoQuickTokenKind.priority),
        ),
      );
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final chip in chips)
          ExpressiveEntrance(
            key: chip.key,
            offset: const Offset(0, 0.3),
            child: chip,
          ),
      ],
    );
  }
}

class _ParsedChip extends StatelessWidget {
  const _ParsedChip({
    super.key,
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.onDismiss,
    this.iconColor,
  });

  final FaIconData icon;
  final String label;
  final String tooltip;
  final VoidCallback onDismiss;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = scheme.onSecondaryContainer;
    return Container(
      height: 28,
      padding: const EdgeInsetsDirectional.only(start: AppSpacing.s + 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FaIcon(icon, size: 11, color: iconColor ?? fg),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: tooltip,
            excludeSemantics: true,
            child: InkResponse(
              onTap: onDismiss,
              radius: 14,
              child: SizedBox(
                width: 28,
                height: 28,
                child: Center(
                  child: FaIcon(FontAwesomeIcons.xmark, size: 10, color: fg),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
