import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_meta_actions.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/diaries/viewmodels/publish_panel_labels.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';
import 'package:node_diary/ui/widgets/value_listenable_selector.dart';

import 'publish_panel_tile.dart';

/// 封面行：点按选图，已有封面时可清除。只随草稿的封面重建。
class PublishCoverTile extends StatelessWidget {
  const PublishCoverTile({
    super.key,
    required this.draft,
    required this.actions,
  });

  final DiaryMetaDraftController draft;
  final DiaryMetaActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableSelector<DiaryMetaDraft, String?>(
      valueListenable: draft,
      selector: (value) => value.cover,
      builder: (context, cover, _) => PublishPanelTile(
        onTap: () => actions.pickCover(context),
        child: Row(
          children: <Widget>[
            Text(l10n.autoT0162, style: PublishPanelTile.titleStyle(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                diaryCoverLabel(cover) ?? l10n.autoT0161,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (cover != null)
              IconButton(
                onPressed: actions.clearCover,
                icon: const FaIcon(FontAwesomeIcons.xmark, size: 12),
                visualDensity: VisualDensity.compact,
                tooltip: l10n.autoT0163,
              ),
            const SizedBox(width: 6),
            const FaIcon(FontAwesomeIcons.chevronRight, size: 12),
          ],
        ),
      ),
    );
  }
}

/// 标签行：只展示已选标签摘要，点按进入标签子页。
class PublishTagTile extends StatelessWidget {
  const PublishTagTile({
    super.key,
    required this.draft,
    required this.tags,
    required this.onOpen,
  });

  final DiaryMetaDraftController draft;
  final List<Tag> tags;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableSelector<DiaryMetaDraft, Set<int>>(
      valueListenable: draft,
      selector: (value) => value.tagIds,
      builder: (context, tagIds, _) {
        final selectedTags = tags
            .where((tag) => tagIds.contains(tag.id))
            .toList(growable: false);
        return PublishPanelTile(
          onTap: onOpen,
          child: Row(
            children: <Widget>[
              Text(l10n.autoT0109, style: PublishPanelTile.titleStyle(context)),
              const SizedBox(width: 12),
              Expanded(
                child: selectedTags.isEmpty
                    ? Text(
                        l10n.autoT0164,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: <Widget>[
                            for (final tag in selectedTags)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: _TagChip(tag: tag),
                              ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              const FaIcon(FontAwesomeIcons.angleRight, size: 14),
            ],
          ),
        );
      },
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});

  final Tag tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagColor = Color(tag.color);
    final isLight = theme.brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tagColor.withValues(alpha: isLight ? 0.08 : 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: tagColor.withValues(alpha: isLight ? 0.22 : 0.32),
          width: 0.65,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '#',
            style: TextStyle(
              color: tagColor,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            tag.name,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// 发表时间行。[label] 为 null 时显示“自动获取当前时间”。
class PublishTimeTile extends StatelessWidget {
  const PublishTimeTile({super.key, required this.label, required this.onPick});

  final String? label;
  final VoidCallback? onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final text = label?.trim();
    final hasLabel = text != null && text.isNotEmpty;
    return PublishPanelTile(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
      child: Row(
        children: <Widget>[
          Text(l10n.autoT0172, style: PublishPanelTile.titleStyle(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasLabel ? text : l10n.autoT0173,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: hasLabel
                    ? null
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
              ),
            ),
          ),
          IconButton(
            onPressed: onPick,
            tooltip: l10n.autoT0174,
            visualDensity: VisualDensity.compact,
            icon: const FaIcon(FontAwesomeIcons.calendarDays, size: 14),
          ),
        ],
      ),
    );
  }
}

/// 时间胶囊行：点按打开胶囊子页，已设置时可移除。只随草稿的胶囊重建。
class PublishCapsuleTile extends StatelessWidget {
  const PublishCapsuleTile({
    super.key,
    required this.draft,
    required this.onOpen,
  });

  final DiaryMetaDraftController draft;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableSelector<DiaryMetaDraft, TimeCapsuleSchedule?>(
      valueListenable: draft,
      selector: (value) => value.capsule,
      builder: (context, capsule, _) {
        final hasCapsule = capsule != null;
        // 设置/清除时间胶囊后底色与描边经 ExpressiveStateBlend 补间（Material
        // 只补间形状，不补间颜色）。
        return ExpressiveStateBlend(
          active: hasCapsule,
          builder: (context, t, child) => PublishPanelTile(
            onTap: onOpen,
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            color: Color.lerp(
              PublishPanelTile.surfaceColor(colorScheme),
              colorScheme.primaryContainer.withValues(alpha: 0.56),
              t,
            ),
            borderColor: Color.lerp(
              PublishPanelTile.outlineColor(colorScheme),
              colorScheme.primary.withValues(alpha: 0.34),
              t,
            ),
            child: child!,
          ),
          child: Row(
            children: <Widget>[
              FaIcon(
                FontAwesomeIcons.clock,
                size: 14,
                color: hasCapsule
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      l10n.timeCapsuleTitle,
                      style: PublishPanelTile.titleStyle(context),
                    ),
                    Text(
                      timeCapsuleLabel(l10n, capsule),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasCapsule)
                IconButton(
                  onPressed: () => draft.setCapsule(null),
                  tooltip: l10n.timeCapsuleClear,
                  visualDensity: VisualDensity.compact,
                  icon: const FaIcon(FontAwesomeIcons.xmark, size: 14),
                ),
              IconButton(
                onPressed: onOpen,
                tooltip: l10n.timeCapsulePickTitle,
                visualDensity: VisualDensity.compact,
                icon: const FaIcon(FontAwesomeIcons.lock, size: 14),
              ),
            ],
          ),
        );
      },
    );
  }
}
