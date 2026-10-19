import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../../core/database/app_database.dart';
import '../../diary_templates/viewmodels/diary_template_accent.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../models/notebook_scope_resolver.dart';
import '../providers/notebook_providers.dart';
import '../sections/notebook_action_sheets.dart';
import '../viewmodels/notebook_header_meta.dart';
import '../viewmodels/notebook_view.dart';
import 'notebook_cover_parts.dart';

/// 首页在日记本里时列表上方的头部卡片：封面图（有则显示）、图标圆、名称与
/// 简介、统计行、状态胶囊与“更多”菜单。
///
/// 只负责展示；菜单项经 [onAction] 交给日记页执行（编辑 / 合上或打开 /
/// 删除），“导出成书”经 [onExportBook]。[extras] 是后续区块（写作目标进度、章节、统计 / 目录 / 添加日记
/// 等操作行）的插槽，按顺序排在统计行下方。
class NotebookHeaderCard extends ConsumerWidget {
  const NotebookHeaderCard({
    super.key,
    required this.notebook,
    required this.onAction,
    this.onExportBook,
    this.extras = const <Widget>[],
    this.bleedExtras = const <Widget>[],
    this.horizontalMargin = AppSpacing.l,
  });

  final NotebookView notebook;
  final ValueChanged<NotebookAction> onAction;

  /// 菜单里的“导出成书”；null 时不显示这一项。
  final VoidCallback? onExportBook;
  final List<Widget> extras;

  /// 排在 [extras] 之后、不受卡片左右内边距限制的区块（横向滚动的章节胶囊
  /// 行）：滚出的胶囊消失在卡片边缘而不是卡片里面；区块自己用
  /// [contentPadding] 作为左右内容边距，与上方文字对齐。
  final List<Widget> bleedExtras;

  /// 卡片内容的内边距（[bleedExtras] 的左右内容边距取它）。
  static const double contentPadding = AppSpacing.l;

  /// 卡片左右外边距：首页传入日记卡片样式的侧边距（用户可调），卡片两侧与
  /// 下方列表卡片对齐。
  final double horizontalMargin;

  static const double coverHeight = 112;
  static const double _radius = 24;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final accent = notebookAccentColors(notebook.color, scheme);
    final cover = notebook.coverPath;
    final showCover = cover != null && File(cover).existsSync();
    final statsScope = notebookStatsScope(notebook);
    final count = ref.watch(notebookScopeCountProvider(statsScope)).value;
    final overviews = ref
        .watch(notebookScopeOverviewsProvider(statsScope))
        .value;
    final meta = count == null || overviews == null
        ? null
        : notebookHeaderMetaLine(
            l10n,
            NotebookHeaderStats.from(count, overviews),
            now: DateTime.now(),
          );
    final isPrivate =
        !notebook.isSmart && notebook.visibility != NotebookVisibility.normal;
    final description = notebook.payload.description;
    final metaStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: scheme.onSurfaceVariant,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        horizontalMargin,
        AppSpacing.xs,
        horizontalMargin,
        AppSpacing.m,
      ),
      child: Material(
        color: ExpressiveSurfaces.cardColor(scheme),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_radius),
          side: ExpressiveSurfaces.cardBorderSide(scheme),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (showCover)
              SizedBox(
                height: coverHeight,
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) =>
                      NotebookCoverImage(
                        path: cover,
                        width: constraints.maxWidth,
                      ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                contentPadding,
                contentPadding,
                contentPadding,
                bleedExtras.isEmpty ? contentPadding : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // 居中：没有简介时名称只有一行，顶对齐会让它高出图标圆心。
                  Row(
                    children: <Widget>[
                      NotebookIconCircle(icon: notebook.icon, accent: accent),
                      const SizedBox(width: AppSpacing.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              notebook.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (description.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 2),
                              Text(
                                description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _HeaderMenu(
                        notebook: notebook,
                        onAction: onAction,
                        onExportBook: onExportBook,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.m),
                  // 统计还没算出来时占住一行高度，算好后不推动下方内容。
                  Text(
                    meta ?? ' ',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: metaStyle,
                  ),
                  if (notebook.isSmart || isPrivate) ...<Widget>[
                    const SizedBox(height: AppSpacing.s),
                    Wrap(
                      spacing: AppSpacing.s,
                      runSpacing: AppSpacing.xs,
                      children: <Widget>[
                        if (notebook.isSmart)
                          _StateCapsule(
                            icon: FontAwesomeIcons.wandMagicSparkles,
                            label: l10n.notebookHeaderSmartBadge,
                            accent: accent,
                          ),
                        if (isPrivate)
                          _StateCapsule(
                            icon:
                                notebook.visibility == NotebookVisibility.locked
                                ? FontAwesomeIcons.lock
                                : FontAwesomeIcons.eyeSlash,
                            label: l10n.notebookHeaderPrivateBadge,
                            accent: accent,
                          ),
                      ],
                    ),
                  ],
                  ...extras,
                ],
              ),
            ),
            if (bleedExtras.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: contentPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: bleedExtras,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 头部“更多”：编辑日记本 / 合上或重新打开 / 删除（不超过 4 项，用弹出菜单）。
class _HeaderMenu extends StatelessWidget {
  const _HeaderMenu({
    required this.notebook,
    required this.onAction,
    this.onExportBook,
  });

  final NotebookView notebook;
  final ValueChanged<NotebookAction> onAction;
  final VoidCallback? onExportBook;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final closeAction = notebook.isClosed
        ? NotebookAction.reopen
        : NotebookAction.close;
    return ExpressiveMenuButton(
      tooltip: l10n.notebookMoreActions,
      icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 18),
      items: <Widget>[
        ExpressiveMenuItem(
          leadingIcon: FaIcon(notebookActionIcon(NotebookAction.edit)),
          onPressed: () => onAction(NotebookAction.edit),
          child: Text(l10n.notebookEditTitle),
        ),
        if (onExportBook case final exportBook?)
          ExpressiveMenuItem(
            leadingIcon: const FaIcon(FontAwesomeIcons.bookOpen),
            onPressed: exportBook,
            child: Text(l10n.notebookExportAsBook),
          ),
        ExpressiveMenuItem(
          leadingIcon: FaIcon(notebookActionIcon(closeAction)),
          onPressed: () => onAction(closeAction),
          child: Text(notebookActionLabel(l10n, closeAction)),
        ),
        ExpressiveMenuItem(
          leadingIcon: FaIcon(notebookActionIcon(NotebookAction.delete)),
          destructive: true,
          onPressed: () => onAction(NotebookAction.delete),
          child: Text(notebookActionLabel(l10n, NotebookAction.delete)),
        ),
      ],
    );
  }
}

/// 状态小胶囊（智能 / 私密）：强调色的淡底 + 12px 图标与文字，无描边。
class _StateCapsule extends StatelessWidget {
  const _StateCapsule({
    required this.icon,
    required this.label,
    required this.accent,
  });

  final FaIconData icon;
  final String label;
  final DiaryTemplateAccentColors accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent.container,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FaIcon(icon, size: 11, color: accent.onContainer),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: accent.onContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
