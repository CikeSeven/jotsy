import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';


/// 笔记列表空状态组件。
///
/// 当当前列表没有可显示笔记时，给出简洁空态和“创建笔记”入口。
class DiariesEmptyState extends StatelessWidget {
  const DiariesEmptyState({
    super.key,
    required this.onCreate,
    this.isSearchResultEmpty = false,
  });

  final VoidCallback onCreate;
  final bool isSearchResultEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = Theme.of(context).colorScheme;
    // 搜索结果为空时使用“搜索语义”空态文案，不显示新建按钮。
    if (isSearchResultEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.search,
              size: 38,
              color: color.secondary,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.tr('没有搜索到日记', en: 'No diaries found'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.tr('换个关键词再试试吧～', en: 'Try another keyword.'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: color.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // 普通空态：提供新建入口。
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.square_pencil,
            size: 38,
            color: color.secondary,
          ),
          const SizedBox(height: 12),
          Text(l10n.tr('还没有日记', en: 'No diaries yet')),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(CupertinoIcons.add),
            label: Text(l10n.tr('新建日记', en: 'Create diary')),
          ),
        ],
      ),
    );
  }
}
