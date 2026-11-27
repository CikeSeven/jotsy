import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';
import '../../widgets/todo_check_box.dart';

/// 待办行里就地展开的步骤：每步一行（整行可点、至少 48dp 高），18dp 方框 +
/// 标题，勾掉的变灰并加删除线。点一行即经 [onToggle] 切换这一步，不打开
/// 详情。展开 / 收起的动效由调用方包（见 `TodoTile`）。
class TodoTileSteps extends StatelessWidget {
  const TodoTileSteps({super.key, required this.steps, required this.onToggle});

  final List<TodoStep> steps;
  final ValueChanged<TodoStep> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final step in steps)
            Semantics(
              checked: step.done,
              button: true,
              label: step.title,
              hint: step.done ? l10n.todoMarkUndone : l10n.todoMarkDone,
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onToggle(step),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: <Widget>[
                      TodoCheckBoxVisual(checked: step.done),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          step.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: step.done
                                ? scheme.onSurfaceVariant
                                : scheme.onSurface,
                            decoration: step.done
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
