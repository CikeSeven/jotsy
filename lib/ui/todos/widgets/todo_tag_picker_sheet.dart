import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../providers/todo_providers.dart';
import 'todo_bare_input.dart';
import 'todo_sheet.dart';

/// 给一条待办选标签（多选，经 [showTodoSheet]）：顶部输入框边打边筛，没有
/// 同名的就多一行“新建“…””；下面是已有的待办标签，没输入时按最近用过排
/// （这次面板里新建、还没写库的排在最前）。每点一下就经 [onChanged] 交出
/// 新的一组（详情里改一项写一项，快速新建里落到手上的值），面板留着接着选。
///
/// 只列待办标签：与日记标签无关（见 `TodoTags`）。选满
/// [TodoTags.maxPerTodo] 个后没选的淡化不可点，并写明上限。
Future<void> showTodoTagPickerSheet(
  BuildContext context, {
  required List<String> selected,
  required ValueChanged<List<String>> onChanged,
}) {
  return showTodoSheet<void>(
    context: context,
    builder: (BuildContext sheetContext) =>
        _TagPickerSheet(initial: selected, onChanged: onChanged),
  );
}

/// 选一个标签（多选栏“加标签”）：同一个面板，点一行（或新建一个）就关上并
/// 交出它；关掉面板不选时为 null。
Future<String?> showTodoTagPickOneSheet(BuildContext context) {
  return showTodoSheet<String>(
    context: context,
    builder: (BuildContext sheetContext) =>
        const _TagPickerSheet(initial: <String>[]),
  );
}

class _TagPickerSheet extends ConsumerStatefulWidget {
  const _TagPickerSheet({required this.initial, this.onChanged});

  final List<String> initial;

  /// 多选时每点一下交出新的一组；为 null 时是只选一个（点了就关上）。
  final ValueChanged<List<String>>? onChanged;

  @override
  ConsumerState<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends ConsumerState<_TagPickerSheet> {
  late List<String> _selected = TodoTags.normalizeAll(widget.initial);
  final TextEditingController _query = TextEditingController();

  /// 这次面板里新建的（库里还没有、要排在最前）。
  final List<String> _created = <String>[];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool get _full => _selected.length >= TodoTags.maxPerTodo;

  void _toggle(String name) {
    final onChanged = widget.onChanged;
    if (onChanged == null) {
      Navigator.of(context).pop(name);
      return;
    }
    final has = TodoTags.contains(_selected, name);
    if (!has && _full) return;
    setState(() {
      _selected = has
          ? <String>[
              for (final tag in _selected)
                if (!TodoTags.same(tag, name)) tag,
            ]
          : TodoTags.normalizeAll(<String>[..._selected, name]);
    });
    onChanged(_selected);
  }

  void _create(String name) {
    if (!TodoTags.contains(_created, name)) _created.insert(0, name);
    _query.clear();
    if (!TodoTags.contains(_selected, name)) _toggle(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final usages = ref.watch(todoTagsProvider).value ?? const <TodoTagUsage>[];
    final query = _query.text.trim();
    final typed = TodoTags.normalize(query);

    // 没输入时按最近用过排；输入时按名称筛（不分大小写）。
    final known = <String>[
      for (final name in _created)
        if (!usages.any((u) => TodoTags.same(u.name, name))) name,
      ...(List<TodoTagUsage>.of(usages)
            ..sort((a, b) => b.lastUsedAt.compareTo(a.lastUsedAt)))
          .map((TodoTagUsage u) => u.name),
      // 已选、但库里与这次都没有的（如快速新建里刚识别出的新标签）。
      for (final name in _selected)
        if (!usages.any((u) => TodoTags.same(u.name, name)) &&
            !TodoTags.contains(_created, name))
          name,
    ];
    final key = typed == null ? null : TodoTags.keyOf(typed);
    final shown = key == null
        ? known
        : <String>[
            for (final name in known)
              if (TodoTags.keyOf(name).contains(key)) name,
          ];
    final canCreate = typed != null && !TodoTags.contains(known, typed);

    return TodoSheetBody(
      title: l10n.todoFieldTags,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: TextField(
            controller: _query,
            autofocus: usages.isEmpty,
            maxLength: TodoTags.maxLength + 1,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (canCreate && !_full) {
                _create(typed);
              } else if (shown.isNotEmpty) {
                _toggle(shown.first);
                _query.clear();
                setState(() {});
              }
            },
            contextMenuBuilder: appTextContextMenuBuilder,
            decoration:
                todoBareInputDecoration(
                  hintText: l10n.todoTagSearchHint,
                ).copyWith(
                  counterText: '',
                  prefixIcon: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: AppSpacing.s,
                    ),
                    child: FaIcon(
                      FontAwesomeIcons.at,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 24),
                ),
          ),
        ),
        if (_full)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.s,
            ),
            child: Text(
              l10n.todoTagLimitHint(TodoTags.maxPerTodo),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        if (canCreate)
          TodoSheetOption(
            icon: FontAwesomeIcons.plus,
            label: l10n.todoTagCreate(typed),
            onTap: _full ? () {} : () => _create(typed),
          ),
        if (known.isEmpty && !canCreate)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Text(
              l10n.todoTagsEmptyHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        if (shown.isNotEmpty && key == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.l,
              AppSpacing.s,
              AppSpacing.l,
              AppSpacing.xs,
            ),
            child: Text(
              l10n.todoTagRecent,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        for (final name in shown)
          Opacity(
            // 选满后没选的淡化（面板底是玻璃时淡的是行内容，不是玻璃本身）。
            opacity: _full && !TodoTags.contains(_selected, name) ? 0.38 : 1,
            child: TodoSheetOption(
              icon: FontAwesomeIcons.tag,
              label: name,
              selected: TodoTags.contains(_selected, name),
              onTap: () => _toggle(name),
            ),
          ),
      ],
    );
  }
}
