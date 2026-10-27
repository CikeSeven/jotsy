import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/expressive_icon_swap.dart';
import '../../widgets/expressive_state_blend.dart';
import '../models/notebook_pick_selection.dart';
import '../providers/notebook_providers.dart';
import '../viewmodels/notebook_tree_rows.dart';
import '../viewmodels/notebook_view.dart';
import '../widgets/notebook_pick_row.dart';

/// 上级选择面板的结果：[parentId] 为 null 表示“无（放在书架上）”。关掉面板
/// 时整个结果为 null，与“选了无”区分开。
@immutable
class NotebookParentChoice {
  const NotebookParentChoice(this.parentId);

  final String? parentId;

  @override
  bool operator ==(Object other) =>
      other is NotebookParentChoice && other.parentId == parentId;

  @override
  int get hashCode => parentId.hashCode;
}

/// 打开上级选择面板（编辑页“上级日记本”与操作面板“移动到…”共用）。
///
/// 列出“无（放在书架上）”与能当 [childId]（null 为正在新建的本子）上级的
/// 日记本：只认 `NotebookTree.parentCandidatesFor`（手动本、不是它自己或它的
/// 子孙、放过去不超过三层），按树序、子本缩进。[selectedParentId] 为当前的
/// 上级，带勾。点一行即选定返回；面板只负责挑选，写入由调用方完成。
Future<NotebookParentChoice?> showNotebookParentPickerSheet(
  BuildContext context, {
  String? childId,
  String? selectedParentId,
  String? title,
}) {
  return showAppModalBottomSheet<NotebookParentChoice>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => NotebookParentPickerSheet(
      childId: childId,
      selectedParentId: selectedParentId,
      title: title,
    ),
  );
}

/// 上级选择面板的内容：标题、“无”与候选上级。高度随内容，最高约屏高的
/// 75%，列表在其中滚动。合上的候选照常可选，整行变淡。
class NotebookParentPickerSheet extends ConsumerWidget {
  const NotebookParentPickerSheet({
    super.key,
    this.childId,
    this.selectedParentId,
    this.title,
  });

  final String? childId;
  final String? selectedParentId;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final tree = ref.watch(notebookTreeProvider);
    final counts =
        ref.watch(notebookEntryCountsProvider).value ?? const <String, int>{};
    void choose(String? parentId) =>
        Navigator.of(context).pop(NotebookParentChoice(parentId));

    final Widget list;
    if (tree == null) {
      list = const SizedBox(height: 160, child: DelayedLoadingIndicator());
    } else {
      final candidates = <String>{
        for (final notebook in tree.parentCandidatesFor(childId)) notebook.id,
      };
      final rows = notebookTreeRows(
        tree,
        include: (NotebookView notebook) => candidates.contains(notebook.id),
      );
      list = ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          media.padding.bottom + AppSpacing.l,
        ),
        children: <Widget>[
          _ParentNoneRow(
            selected: selectedParentId == null,
            onTap: () => choose(null),
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.l,
              ),
              child: Text(
                l10n.notebookParentPickerEmpty,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          for (final NotebookTreeRow(:notebook, :indent) in rows)
            Opacity(
              key: ValueKey<String>('notebook_parent_${notebook.id}'),
              opacity: notebook.isClosed ? 0.6 : 1,
              child: NotebookPickRow(
                notebook: notebook,
                indent: indent,
                count: watchNotebookDisplayCount(ref, notebook, counts),
                state: notebook.id == selectedParentId
                    ? NotebookPickState.all
                    : NotebookPickState.none,
                onTap: () => choose(notebook.id),
              ),
            ),
        ],
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.75),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.m,
            ),
            child: Text(
              title ?? l10n.notebookParentLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(child: list),
        ],
      ),
    );
  }
}

/// “无（放在书架上）”：与 [NotebookPickRow] 同一表面与勾选样式，选中时底色
/// 补间到 `secondaryContainer`。
class _ParentNoneRow extends StatelessWidget {
  const _ParentNoneRow({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        checked: selected,
        child: ExpressiveStateBlend(
          active: selected,
          builder: (BuildContext context, double t, Widget? child) => Material(
            color: Color.lerp(
              scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              scheme.secondaryContainer,
              t,
            ),
            borderRadius: BorderRadius.circular(12),
            child: child,
          ),
          child: InkWell(
            key: const ValueKey<String>('notebook_parent_none'),
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: FaIcon(
                        FontAwesomeIcons.book,
                        size: 14,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.notebookParentNone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ExpressiveIconSwap(
                      switchKey: selected,
                      child: FaIcon(
                        selected
                            ? FontAwesomeIcons.solidCircleCheck
                            : FontAwesomeIcons.circle,
                        size: 18,
                        color: selected
                            ? scheme.onSecondaryContainer
                            : scheme.outlineVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
