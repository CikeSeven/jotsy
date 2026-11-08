import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../notebooks/models/notebook_icon.dart';
import '../../notebooks/widgets/notebook_icon_grid.dart';
import '../../widgets/color_palette_families.dart';
import '../../widgets/color_swatch_button.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../viewmodels/todo_list_style.dart';
import 'todo_sheet.dart';

/// 新建 / 编辑清单面板的结果。
@immutable
class TodoListEdit {
  const TodoListEdit({
    required this.name,
    required this.colorKey,
    required this.iconKey,
  });

  final String name;
  final String colorKey;
  final String iconKey;
}

/// 新建（[editing] 为 null）或编辑清单：名称、强调色（跟随主题或色板十个
/// 色系）与图标（与日记本同一套图标）。名称为空时“保存”不可用。点“保存”
/// 返回结果，关闭为 null。
Future<TodoListEdit?> showTodoListEditSheet(
  BuildContext context, {
  TodoListRow? editing,
}) {
  return showTodoSheet<TodoListEdit>(
    context: context,
    builder: (BuildContext sheetContext) => _ListEditSheet(editing: editing),
  );
}

class _ListEditSheet extends StatefulWidget {
  const _ListEditSheet({required this.editing});

  final TodoListRow? editing;

  @override
  State<_ListEditSheet> createState() => _ListEditSheetState();
}

class _ListEditSheetState extends State<_ListEditSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.editing?.name ?? '',
  );
  late int? _seed = TodoListStyle.seedOf(widget.editing?.colorKey ?? '');
  late NotebookIcon _icon =
      TodoListStyle.notebookIconOf(widget.editing?.iconKey ?? '') ??
      TodoListStyle.defaultIcon;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      TodoListEdit(
        name: name,
        colorKey: TodoListStyle.keyOfSeed(_seed),
        iconKey: _icon == TodoListStyle.defaultIcon ? '' : _icon.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return TodoSheetBody(
      title: widget.editing == null ? l10n.todoListNew : l10n.todoListEdit,
      trailing: TextButton(
        onPressed: _name.text.trim().isEmpty ? null : _save,
        child: Text(l10n.commonSave),
      ),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: TextField(
            controller: _name,
            autofocus: widget.editing == null,
            maxLength: 50,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
            contextMenuBuilder: appTextContextMenuBuilder,
            decoration: InputDecoration(
              hintText: l10n.todoListNameHint,
              counterText: '',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.l,
            AppSpacing.l,
            AppSpacing.s,
          ),
          child: Text(l10n.todoListColor, style: labelStyle),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              ColorSwatchButton(
                color: scheme.primaryContainer,
                selected: _seed == null,
                semanticLabel: l10n.diaryTemplateEditorAccentTheme,
                onTap: () => setState(() => _seed = null),
              ),
              for (final family in kColorPaletteFamilies)
                ColorSwatchButton(
                  color: TodoListStyle.accentOf(
                    TodoListStyle.keyOfSeed(family.colors[5].toARGB32()),
                    scheme,
                  ).container,
                  selected: _seed == family.colors[5].toARGB32(),
                  semanticLabel: family.label,
                  onTap: () =>
                      setState(() => _seed = family.colors[5].toARGB32()),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.l,
            AppSpacing.l,
            AppSpacing.l,
            AppSpacing.s,
          ),
          child: Text(l10n.todoListIcon, style: labelStyle),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
          child: NotebookIconGrid(
            selected: _icon,
            color: _seed,
            onSelected: (NotebookIcon icon) => setState(() => _icon = icon),
          ),
        ),
      ],
    );
  }
}
