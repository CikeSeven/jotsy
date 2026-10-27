import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../providers/notebook_providers.dart';
import '../viewmodels/notebook_view.dart';

/// 子本头部卡片名称上方的上级路径：“旅行 › 2025 ›”，每一级可点，点按经
/// [onOpen] 回到那一本（由日记页切换范围，往上走不需要验证）。
///
/// 层级只读 `notebookTreeProvider`（顶层本子没有上级，什么也不画）。最多
/// 三层，路径最多两级；名称过长时各级按比例省略，不折行。
class NotebookBreadcrumb extends ConsumerWidget {
  const NotebookBreadcrumb({
    super.key,
    required this.notebook,
    required this.onOpen,
  });

  final NotebookView notebook;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ancestors =
        ref.watch(notebookTreeProvider)?.ancestorsOf(notebook.id) ??
        const <NotebookView>[];
    if (ancestors.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    // 分隔符画在每一级之后（最后一个指向下面的名称），读作“这本在哪里”。
    Widget separator() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: FaIcon(
        FontAwesomeIcons.angleRight,
        size: 10,
        color: scheme.onSurfaceVariant,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: <Widget>[
          for (final ancestor in ancestors) ...<Widget>[
            Flexible(
              child: _Crumb(
                key: ValueKey<String>('notebook_crumb_${ancestor.id}'),
                notebook: ancestor,
                onTap: () => onOpen(ancestor.id),
              ),
            ),
            separator(),
          ],
        ],
      ),
    );
  }
}

/// 路径里的一级：primary 色的名称，墨水层贴着文字。读屏读作“回到「旅行」”。
class _Crumb extends StatelessWidget {
  const _Crumb({super.key, required this.notebook, required this.onTap});

  final NotebookView notebook;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = context.l10n.notebookNestGoUp(notebook.name);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          // 竖向留出点按高度；横向不加内边距，第一级与下方名称左缘对齐。
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 32),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: 1,
              child: Text(
                notebook.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
