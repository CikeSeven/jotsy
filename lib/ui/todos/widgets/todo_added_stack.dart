import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/animated_rolling_text.dart';
import '../../widgets/list_item_presence.dart';

/// 快速新建面板里刚添加的一条。
@immutable
class TodoAddedItem {
  const TodoAddedItem({required this.id, required this.title});

  final String id;
  final String title;
}

/// 快速新建面板上“已添加 N 条”的小堆栈（连续记录时）：标题行的条数逐位
/// 滚动，下面是最近的 [maxShown] 条（最新的在上，从 0 展开进来），每条点开
/// 详情（[onOpen]），行尾可撤销添加（[onUndo]，删掉这一条）。没有时不占位。
class TodoAddedStack extends StatelessWidget {
  const TodoAddedStack({
    super.key,
    required this.items,
    required this.onOpen,
    required this.onUndo,
  });

  /// 这次打开面板后添加的，按添加先后。
  final List<TodoAddedItem> items;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onUndo;

  static const int maxShown = 3;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final shown = items.reversed.take(maxShown).toList();
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        0,
        AppSpacing.l,
        AppSpacing.s,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AnimatedRollingText.sentence(
            l10n.todoQuickAddedCount(items.length),
            number: items.length,
            style: theme.textTheme.labelMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final item in shown)
            ListItemPresence(
              key: ValueKey<String>('added_${item.id}'),
              visible: true,
              appearing: true,
              duration: duration,
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Material(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onOpen(item.id),
                    child: SizedBox(
                      height: 40,
                      child: Row(
                        children: <Widget>[
                          const SizedBox(width: AppSpacing.m),
                          FaIcon(
                            FontAwesomeIcons.circleCheck,
                            size: 13,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.s),
                          Expanded(
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          IconButton(
                            tooltip: l10n.todoQuickAddedUndo,
                            onPressed: () => onUndo(item.id),
                            icon: const FaIcon(
                              FontAwesomeIcons.rotateLeft,
                              size: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
