import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../viewmodels/notebook_tree_rows.dart';
import '../viewmodels/notebook_view.dart';
import '../widgets/notebook_foldable_rows.dart';
import '../widgets/notebook_tree_toggle.dart';

/// [showNotebookChoiceSheet] 列表最前面的一行（“全部日记”“不指定”等），
/// 选它时结果的 `notebookId` 为 null。
@immutable
class NotebookChoiceLead {
  const NotebookChoiceLead({required this.label, required this.icon});

  final String label;
  final FaIconData icon;
}

/// [showNotebookChoiceSheet] 的结果：[notebookId] 为 null 表示选了最前面
/// 那一行；关掉面板时整个结果为 null，与之区分开。
typedef NotebookChoiceResult = ({String? notebookId});

/// 单选一本日记本的列表面板（AI 回顾的范围、小组件的“写进哪本”“哪本的
/// 日记 / 照片”共用）：标题、可选的 [lead] 行、按树序缩进的 [rows]（调用方
/// 经 `notebookTreeRows` 过滤，上级没列出时子本往外提一级），当前所选
/// [selectedId] 打勾。点一行即选定返回；面板只负责挑选。
///
/// 有子本的行可收起 / 展开（[NotebookFoldableRows]，与管理页共用收起状态），
/// 当前所选的那本所在的上级打开时按展开排。行尾先是展开 / 收起，再是对勾格
/// （没勾时也占位，展开按钮上下对齐成一列）。
Future<NotebookChoiceResult?> showNotebookChoiceSheet(
  BuildContext context, {
  required String title,
  required List<NotebookTreeRow> rows,
  required String? selectedId,
  NotebookChoiceLead? lead,
  bool leadSelected = false,
  FaIconData Function(NotebookView notebook)? iconOf,
}) {
  return showAppModalBottomSheet<NotebookChoiceResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (BuildContext sheetContext) => _NotebookChoiceSheet(
      title: title,
      rows: rows,
      selectedId: selectedId,
      lead: lead,
      leadSelected: leadSelected,
      iconOf: iconOf ?? (NotebookView notebook) => notebook.icon.data,
    ),
  );
}

class _NotebookChoiceSheet extends StatelessWidget {
  const _NotebookChoiceSheet({
    required this.title,
    required this.rows,
    required this.selectedId,
    required this.lead,
    required this.leadSelected,
    required this.iconOf,
  });

  final String title;
  final List<NotebookTreeRow> rows;
  final String? selectedId;
  final NotebookChoiceLead? lead;
  final bool leadSelected;
  final FaIconData Function(NotebookView notebook) iconOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final lead = this.lead;
    Widget check(bool selected) => SizedBox(
      width: 20,
      child: selected
          ? FaIcon(FontAwesomeIcons.check, size: 14, color: colors.primary)
          : null,
    );
    void choose(String? id) =>
        Navigator.of(context).pop<NotebookChoiceResult>((notebookId: id));
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 16),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (lead != null)
              ListTile(
                key: const ValueKey<String>('notebook_choice_lead'),
                contentPadding: const EdgeInsetsDirectional.only(
                  start: 24,
                  end: 16,
                ),
                leading: FaIcon(lead.icon, size: 16),
                title: Text(lead.label),
                trailing: check(leadSelected),
                onTap: () => choose(null),
              ),
            NotebookFoldableRows(
              rows: rows,
              reveal: <String>{?selectedId},
              itemBuilder: (context, row, toggle) {
                final notebook = row.notebook;
                return ListTile(
                  key: ValueKey<String>('notebook_choice_${notebook.id}'),
                  contentPadding: EdgeInsetsDirectional.only(
                    start: 24 + row.indent * notebookTreeIndentStep,
                    end: 16,
                  ),
                  leading: FaIcon(iconOf(notebook), size: 16),
                  title: Text(
                    notebook.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (toggle != null)
                        NotebookTreeToggleButton(
                          key: ValueKey<String>(
                            'notebook_choice_toggle_${notebook.id}',
                          ),
                          toggle: toggle,
                          compact: true,
                        ),
                      check(notebook.id == selectedId),
                    ],
                  ),
                  onTap: () => choose(notebook.id),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
