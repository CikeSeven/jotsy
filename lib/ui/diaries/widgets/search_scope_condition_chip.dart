import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

/// 搜索页的日记本条件胶囊：日记本图标 + 名称 + 移除按钮，样式与标签条件
/// 胶囊一致。移除后改为在全部日记中搜索。
class SearchScopeConditionChip extends StatelessWidget {
  const SearchScopeConditionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onRemove,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 24),
      padding: const EdgeInsets.fromLTRB(8, 2, 4, 2),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FaIcon(icon, size: 12, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          // 点击区域扩到 24dp（与胶囊最小高度一致，不撑高搜索栏）。
          Semantics(
            button: true,
            label: context.l10n.notebookSearchRemoveScope(label),
            child: InkResponse(
              onTap: onRemove,
              radius: 12,
              child: SizedBox.square(
                dimension: 24,
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.xmark,
                    size: 10,
                    color: colorScheme.onSurfaceVariant,
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
