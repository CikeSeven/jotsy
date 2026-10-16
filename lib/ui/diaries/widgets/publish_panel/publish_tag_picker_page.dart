import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';
import 'package:node_diary/ui/widgets/value_listenable_selector.dart';

/// 面板的标签子页：顶部“新建”，下面是全部标签的勾选列表。
///
/// 三态：加载中 / 加载失败 / 列表（空时提示先创建）。勾选直接写进草稿。
class PublishTagPickerPage extends StatelessWidget {
  const PublishTagPickerPage({
    super.key,
    required this.draft,
    required this.tags,
    required this.onCreateTag,
  });

  final DiaryMetaDraftController draft;
  final AsyncValue<List<Tag>> tags;
  final VoidCallback onCreateTag;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // 标签页顶部“新建”入口，视觉与标签项保持同体系卡片。
          SizedBox(
            width: double.infinity,
            child: Material(
              color: colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: InkWell(
                onTap: onCreateTag,
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 40),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const FaIcon(FontAwesomeIcons.plus, size: 12),
                        const SizedBox(width: 6),
                        Text(
                          l10n.autoT0157,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          tags.when(
            loading: () => const SizedBox(
              height: 20,
              width: 20,
              child: ExpressiveLoadingIndicator(),
            ),
            error: (error, _) => Text(
              l10n.autoT0165('$error'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            data: (list) => list.isEmpty
                ? Text(
                    l10n.autoT0166,
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                : ValueListenableSelector<DiaryMetaDraft, Set<int>>(
                    valueListenable: draft,
                    selector: (value) => value.tagIds,
                    builder: (context, selectedIds, _) => Column(
                      children: <Widget>[
                        for (final tag in list)
                          _TagRow(
                            tag: tag,
                            selected: selectedIds.contains(tag.id),
                            onToggle: (selected) =>
                                draft.setTagSelected(tag.id, selected),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.tag,
    required this.selected,
    required this.onToggle,
  });

  final Tag tag;
  final bool selected;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final tagColor = Color(tag.color);
    // 选中换色经 ExpressiveStateBlend 补间（Material 不补间颜色）。
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ExpressiveStateBlend(
        active: selected,
        builder: (context, t, child) => Material(
          color: Color.lerp(
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            tagColor.withValues(alpha: isLight ? 0.12 : 0.22),
            t,
          ),
          borderRadius: BorderRadius.circular(12),
          child: child,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onToggle(!selected),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: tagColor.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '#',
                      style: TextStyle(
                        color: tagColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tag.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  ExpressiveIconSwap(
                    switchKey: selected,
                    child: FaIcon(
                      selected
                          ? FontAwesomeIcons.solidCircleCheck
                          : FontAwesomeIcons.circle,
                      size: 18,
                      color: selected ? tagColor : colorScheme.outlineVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
