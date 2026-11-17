import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../core/database/diary_list_scope.dart';
import '../../../diary_templates/viewmodels/diary_template_accent.dart';
import '../../models/notebook_icon.dart';
import '../../providers/notebook_providers.dart';
import '../../viewmodels/notebook_deck_entries.dart';
import '../../viewmodels/notebook_deck_layout.dart';
import '../../viewmodels/notebook_labels.dart';
import '../notebook_cover/notebook_cover_texture.dart';
import '../notebook_cover_parts.dart';
import '../notebook_stacked_cover.dart';
import '../notebook_switcher_chip.dart';

/// 日记本卡组里的一张横卡（或“已合上”标题条）。
///
/// 卡片高 [NotebookDeckLayout.cardHeight]，上面 [NotebookDeckLayout.peek] 高
/// 的顶条是实色的强调容器色：图标圆、名称、篇数与状态，叠放时只露出这
/// 一条；下面的卡身铺封面图（按取景裁切）或只露纹理，最后一张与被抬起的
/// 卡片才看得到。不用渐变，文字只放在实色顶条上。有子本时行尾露出两层
/// 纸边，顶条尾部的角标展开 / 收起子本。
///
/// 只负责外观与点按：位置、抬起、抽出都由卡组在绘制时变换，卡片自己不做
/// 动画。已合上的本子颜色往面板底色退一截（不透明，叠放时不互相透出）。
class NotebookDeckCard extends ConsumerWidget {
  const NotebookDeckCard({
    super.key,
    required this.entry,
    required this.width,
    required this.current,
    required this.onTap,
    required this.onPressChanged,
    this.onLongPress,
    this.onToggle,
  });

  final NotebookDeckEntry entry;

  /// 卡片宽度（已扣掉缩进与纸边的位置）。
  final double width;

  /// 是当前范围。
  final bool current;
  final VoidCallback onTap;

  /// 按下 / 抬起（卡组据此抬起这张卡片）。
  final ValueChanged<bool> onPressChanged;
  final VoidCallback? onLongPress;

  /// 展开 / 收起子本（有子本时），或展开 / 收起“已合上”这一叠（标题条）。
  final VoidCallback? onToggle;

  static const double radius = 20;
  static const double iconSize = 36;

  /// 卡片右侧为纸边留出的宽度。
  static const double paperRoom = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entry.kind == NotebookDeckEntryKind.closedHeader) {
      return _ClosedHeader(entry: entry, width: width, onToggle: onToggle);
    }
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final notebook = entry.notebook;
    final DiaryTemplateAccentColors base = switch (entry.kind) {
      NotebookDeckEntryKind.all => DiaryTemplateAccentColors(
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      NotebookDeckEntryKind.unfiled => DiaryTemplateAccentColors(
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      _ => notebookAccentColors(notebook!.color, scheme),
    };
    // 已合上：颜色往面板底色退一截（仍然不透明）。叠成一摞的卡片若用整体
    // 半透明，会一层层互相透出。
    final accent = notebook?.isClosed ?? false
        ? DiaryTemplateAccentColors(
            Color.lerp(base.container, scheme.surfaceContainerLow, 0.45)!,
            Color.lerp(base.onContainer, scheme.onSurfaceVariant, 0.5)!,
          )
        : base;
    final int? count = switch (entry.kind) {
      NotebookDeckEntryKind.all =>
        ref.watch(notebookScopeCountProvider(DiaryListScope.all)).value,
      NotebookDeckEntryKind.unfiled =>
        ref.watch(notebookScopeCountProvider(DiaryListScope.unfiled)).value,
      _ => watchNotebookDisplayCount(
        ref,
        notebook!,
        ref.watch(notebookEntryCountsProvider).value ?? const <String, int>{},
      ),
    };
    final name = switch (entry.kind) {
      NotebookDeckEntryKind.all => l10n.notebookAllDiaries,
      NotebookDeckEntryKind.unfiled => l10n.notebookUnfiled,
      _ => notebook!.name,
    };
    final badge = notebook == null
        ? null
        : notebookBadgeFor(notebook.kind, notebook.effectiveVisibility);
    final subtitle = <String>[
      if (count != null) l10n.notebookEntryCount(count),
      if (entry.childCount > 0) l10n.notebookSubCount(entry.childCount),
    ].join(' · ');
    final semantics = <String>[
      name,
      if (count != null) l10n.notebookEntryCount(count),
      if (notebook?.isPinned ?? false) l10n.notebookStatePinned,
      if (badge != null) notebookBadgeLabel(l10n, badge),
      if (notebook?.isClosed ?? false) l10n.notebookStateClosed,
      if (current) l10n.notebookDeckCurrent,
    ].join(l10n.notebookSemanticsSeparator);
    final borderRadius = BorderRadius.circular(radius);
    final light = scheme.brightness == Brightness.light;
    final coverPath = notebook?.coverPath;
    final style = notebook?.coverStyle;

    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: accent.container,
        borderRadius: borderRadius,
        // 上一张被这一张盖住的地方要看得出分界：亮色往上投一道很淡的影，
        // 暗色只靠描边（黑影叠在暗面上只会发脏）。
        boxShadow: light
            ? <BoxShadow>[
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.08),
                  offset: const Offset(0, -1),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (style != null)
              NotebookCoverTextureLayer(
                texture: style.texture,
                color: notebookCoverTextureColor(accent.onContainer),
              ),
            if (coverPath != null && style != null)
              Positioned(
                top: NotebookDeckLayout.peek,
                left: 0,
                right: 0,
                bottom: 0,
                child: NotebookCoverImage(
                  path: coverPath,
                  width: width,
                  height:
                      NotebookDeckLayout.cardHeight - NotebookDeckLayout.peek,
                  style: style,
                ),
              ),
            if (notebook == null)
              PositionedDirectional(
                end: 18,
                bottom: 10,
                child: FaIcon(
                  _scopeIcon,
                  size: 34,
                  color: accent.onContainer.withValues(alpha: 0.14),
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: NotebookDeckLayout.peek,
              child: ColoredBox(
                // 顶条实色：封面图只在卡身里，名称永远压在纯色上。
                color: coverPath == null
                    ? Colors.transparent
                    : accent.container,
                child: _Band(
                  accent: accent,
                  icon: notebook?.icon,
                  scopeIcon: notebook == null ? _scopeIcon : null,
                  name: name,
                  subtitle: subtitle,
                  badge: badge,
                  pinned: notebook?.isPinned ?? false,
                  current: current,
                  entry: entry,
                  onToggle: onToggle,
                ),
              ),
            ),
            // 描边画在最上面：当前那张的主色描边不被封面图盖住。
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: current
                        ? scheme.primary
                        : scheme.outlineVariant.withValues(
                            alpha: light ? 0.6 : 0.9,
                          ),
                    width: current ? 2 : 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    card = SizedBox(
      width: width,
      height: NotebookDeckLayout.cardHeight,
      child: card,
    );
    if (entry.childCount > 0 && notebook != null) {
      card = NotebookStackedCover(
        childCount: entry.childCount,
        color: notebook.color,
        child: card,
      );
    }
    return Semantics(
      container: true,
      button: true,
      selected: current,
      label: semantics,
      onTap: onTap,
      onLongPress: onLongPress,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onPressChanged(true),
        onTapUp: (_) => onPressChanged(false),
        onTapCancel: () => onPressChanged(false),
        onTap: onTap,
        onLongPress: onLongPress,
        child: card,
      ),
    );
  }

  FaIconData get _scopeIcon => entry.kind == NotebookDeckEntryKind.unfiled
      ? NotebookSwitcherChip.unfiledIcon
      : FontAwesomeIcons.layerGroup;
}

/// 卡片顶条：图标圆、名称与篇数、状态角标、当前标记、子本角标。
class _Band extends StatelessWidget {
  const _Band({
    required this.accent,
    required this.icon,
    required this.scopeIcon,
    required this.name,
    required this.subtitle,
    required this.badge,
    required this.pinned,
    required this.current,
    required this.entry,
    required this.onToggle,
  });

  final DiaryTemplateAccentColors accent;
  final NotebookIcon? icon;
  final FaIconData? scopeIcon;
  final String name;
  final String subtitle;
  final NotebookBadge? badge;
  final bool pinned;
  final bool current;
  final NotebookDeckEntry entry;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icon = this.icon;
    // 名称、篇数与状态已经合进卡片自己的读屏说明；只有子本角标是独立的
    // 按钮，留在语义树里。
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 12, end: 10),
      child: Row(
        children: <Widget>[
          if (icon != null)
            ExcludeSemantics(
              child: NotebookIconCircle(
                icon: icon,
                accent: accent,
                size: NotebookDeckCard.iconSize,
              ),
            )
          else
            SizedBox.square(
              dimension: NotebookDeckCard.iconSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    accent.onContainer.withValues(alpha: 0.12),
                    accent.container,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: FaIcon(scopeIcon, size: 15, color: accent.onContainer),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: accent.onContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: accent.onContainer.withValues(alpha: 0.72),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (pinned)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6),
              child: FaIcon(
                FontAwesomeIcons.thumbtack,
                size: 11,
                color: accent.onContainer.withValues(alpha: 0.7),
              ),
            ),
          if (badge != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6),
              child: NotebookStateBadge(badge: badge!),
            ),
          if (entry.childCount > 0)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6),
              child: _ChildrenToggle(
                count: entry.childCount,
                expanded: entry.expanded,
                accent: accent,
                onTap: onToggle,
              ),
            ),
          if (current)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 6),
              child: SizedBox.square(
                dimension: 22,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: FaIcon(
                      FontAwesomeIcons.check,
                      size: 11,
                      color: scheme.onPrimary,
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

/// 顶条尾部的子本角标：“N”+ 旋转的箭头，点它展开 / 收起子本（不选中
/// 这一本）。
class _ChildrenToggle extends StatelessWidget {
  const _ChildrenToggle({
    required this.count,
    required this.expanded,
    required this.accent,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final DiaryTemplateAccentColors accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      button: true,
      expanded: expanded,
      label: expanded
          ? l10n.notebookDeckHideChildren
          : l10n.notebookDeckShowChildren(count),
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          // 点按区域比角标本身大一圈。
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: accent.onContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  FaIcon(
                    FontAwesomeIcons.layerGroup,
                    size: 10,
                    color: accent.onContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent.onContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 3),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: ExpressiveMotion.duration(
                      context,
                      ExpressiveMotion.fast,
                    ),
                    curve: ExpressiveMotion.effects,
                    child: FaIcon(
                      FontAwesomeIcons.chevronDown,
                      size: 9,
                      color: accent.onContainer,
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

/// “已合上”分组的标题条：书本图标 + “已合上 · N” + 箭头，点它展开 / 收起
/// 这一叠。
class _ClosedHeader extends StatelessWidget {
  const _ClosedHeader({
    required this.entry,
    required this.width,
    required this.onToggle,
  });

  final NotebookDeckEntry entry;
  final double width;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final color = scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      expanded: entry.expanded,
      label: '${l10n.notebookSectionClosed} ${entry.closedCount}',
      onTap: onToggle,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: SizedBox(
          width: width,
          height: NotebookDeckLayout.headerHeight,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 14, end: 12),
            child: Row(
              children: <Widget>[
                FaIcon(FontAwesomeIcons.book, size: 12, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${l10n.notebookSectionClosed} · ${entry.closedCount}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(color: color),
                  ),
                ),
                AnimatedRotation(
                  turns: entry.expanded ? 0.5 : 0,
                  duration: ExpressiveMotion.duration(
                    context,
                    ExpressiveMotion.fast,
                  ),
                  curve: ExpressiveMotion.effects,
                  child: FaIcon(
                    FontAwesomeIcons.chevronDown,
                    size: 11,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
