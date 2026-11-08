import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_service.dart';
import '../../settings/providers/app_features_provider.dart';
import '../controllers/todo_actions.dart';
import '../controllers/todo_navigation.dart';
import '../providers/todo_providers.dart';
import 'todo_tile.dart';

/// 日记预览页正文之后的“相关待办”：关联了这篇日记的待办（未完成的在前），
/// 可直接勾选，点行打开详情。待办功能关闭或没有关联的待办时不占位（连同
/// 上方的间距一起不出现）。
///
/// 功能关闭时先返回、不订阅数据库：预览页的其他测试与默认关闭的用户都
/// 不会因此多开一条查询。
class DiaryLinkedTodosSection extends ConsumerWidget {
  const DiaryLinkedTodosSection({
    super.key,
    required this.diaryId,
    this.textColor,
  });

  final String diaryId;

  /// 预览样式的正文色（自定义纸张颜色时标题跟着它）。
  final Color? textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      appFeaturesProvider.select((features) => features.todos),
    );
    if (!enabled) return const SizedBox.shrink();
    final rows = ref.watch(todosLinkedToDiaryProvider(diaryId)).value;
    if (rows == null || rows.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final database = ref.read(appDatabaseProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s),
            child: Text(
              l10n.diaryLinkedTodosTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                color: textColor ?? theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final row in rows)
            Padding(
              key: ValueKey<String>('linked_todo_${row.todoId}'),
              padding: const EdgeInsets.only(bottom: AppSpacing.s),
              child: TodoTile(
                row: row,
                today: today,
                onToggle: () =>
                    unawaited(toggleTodoDone(context, database, row)),
                onTap: () => unawaited(openTodoDetail(context, row.todoId)),
              ),
            ),
        ],
      ),
    );
  }
}
