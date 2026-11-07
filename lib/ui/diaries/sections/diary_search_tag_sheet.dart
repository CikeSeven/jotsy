import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../notebooks/sections/notebook_rule_sheets.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';

/// 打开搜索页的标签面板：全部标签的 `#` 胶囊多选，点选即生效、面板保持
/// 打开（同日历筛选面板），浅遮罩下能看到结果随之变化；下拉或点遮罩关闭。
///
/// 选中态由面板自己维护（初值取打开时的条件），每次点选经 [onChanged] 把
/// 整组标签交给搜索页；语义仍是“全部都含”（AND）。
Future<void> showDiarySearchTagSheet(
  BuildContext context, {
  required Set<int> selected,
  required ValueChanged<Set<int>> onChanged,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.16),
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext _) =>
        _DiarySearchTagSheet(initial: selected, onChanged: onChanged),
  );
}

class _DiarySearchTagSheet extends ConsumerStatefulWidget {
  const _DiarySearchTagSheet({required this.initial, required this.onChanged});

  final Set<int> initial;
  final ValueChanged<Set<int>> onChanged;

  @override
  ConsumerState<_DiarySearchTagSheet> createState() =>
      _DiarySearchTagSheetState();
}

class _DiarySearchTagSheetState extends ConsumerState<_DiarySearchTagSheet> {
  late final Set<int> _selected = <int>{...widget.initial};

  void _toggle(int tagId) {
    setState(() {
      if (!_selected.remove(tagId)) {
        _selected.add(tagId);
      }
    });
    widget.onChanged(Set<int>.unmodifiable(_selected));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tags = ref.watch(tagListProvider).asData?.value ?? const <Tag>[];
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.diarySearchTagSheetTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.diarySearchTagSheetHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            if (tags.isEmpty)
              Text(
                l10n.calendarFilterNoTags,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: AppSpacing.s,
                runSpacing: AppSpacing.s,
                children: <Widget>[
                  for (final tag in tags)
                    notebookRuleTagChip(
                      theme,
                      name: tag.name,
                      color: Color(tag.color),
                      selected: _selected.contains(tag.id),
                      onTap: () => _toggle(tag.id),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
