import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../models/diary_template.dart';
import '../widgets/diary_template_tile.dart';

/// 模板行菜单里的操作。
enum DiaryTemplateAction {
  edit,
  duplicate,
  copyToMine,
  copyCode,
  hide,
  show,
  delete,
}

/// 模板管理页的分组标题（与设置分组标题同一字阶）。
class DiaryTemplatesSectionHeader extends StatelessWidget {
  const DiaryTemplatesSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, AppSpacing.xxl, 16, AppSpacing.s),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 16,
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// “我的模板”为空时的提示卡片。
class DiaryTemplatesMineEmpty extends StatelessWidget {
  const DiaryTemplatesMineEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ExpressiveSurfaces.cardColor(colorScheme),
          borderRadius: BorderRadius.circular(AppRadii.input),
          border: Border.fromBorderSide(
            ExpressiveSurfaces.cardBorderSide(colorScheme),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Row(
            children: <Widget>[
              FaIcon(
                FontAwesomeIcons.layerGroup,
                size: 18,
                color: colorScheme.secondary,
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: Text(
                  context.l10n.diaryTemplatesMineEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 我的模板：按住左侧手柄拖动排序，点按编辑，菜单里复制、复制模板码、删除。
class DiaryTemplatesMineSliver extends StatelessWidget {
  const DiaryTemplatesMineSliver({
    super.key,
    required this.templates,
    required this.onTap,
    required this.onAction,
    required this.onReorder,
  });

  final List<DiaryTemplate> templates;
  final ValueChanged<DiaryTemplate> onTap;
  final void Function(DiaryTemplate template, DiaryTemplateAction action)
  onAction;

  /// onReorderItem 语义：[newIndex] 已按移除 [oldIndex] 后的列表修正。
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      sliver: SliverReorderableList(
        itemCount: templates.length,
        onReorderItem: onReorder,
        // 拿起条目即生效的瞬间给一次触觉：手柄是立即拖动，不经过长按。
        onReorderStart: (_) => unawaited(HapticFeedback.mediumImpact()),
        proxyDecorator: _liftProxy,
        itemBuilder: (BuildContext context, int index) {
          final template = templates[index];
          return Padding(
            key: ValueKey<String>('template_mine_${template.id}'),
            padding: const EdgeInsets.only(bottom: AppSpacing.s),
            child: DiaryTemplateTile(
              template: template,
              onTap: () => onTap(template),
              leading: ReorderableDragStartListener(
                index: index,
                child: Semantics(
                  label: l10n.diaryTemplatesDragHandle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.m,
                      vertical: AppSpacing.l,
                    ),
                    child: FaIcon(
                      FontAwesomeIcons.gripLines,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              trailing: DiaryTemplateActionsButton(
                actions: const <DiaryTemplateAction>[
                  DiaryTemplateAction.edit,
                  DiaryTemplateAction.duplicate,
                  DiaryTemplateAction.copyCode,
                  DiaryTemplateAction.delete,
                ],
                onSelected: (action) => onAction(template, action),
              ),
            ),
          );
        },
      ),
    );
  }

  /// 拖起时只轻微放大，不另加卡片：模板行本身就是带描边的卡片。
  static Widget _liftProxy(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (BuildContext context, Widget? child) => Transform.scale(
        scale: 1 + 0.02 * ExpressiveMotion.effects.transform(animation.value),
        child: Material(type: MaterialType.transparency, child: child),
      ),
    );
  }
}

/// 内置模板：点按预览，菜单里复制为我的模板、复制模板码、隐藏或显示。
class DiaryTemplatesBuiltInSliver extends StatelessWidget {
  const DiaryTemplatesBuiltInSliver({
    super.key,
    required this.templates,
    required this.hiddenIds,
    required this.onTap,
    required this.onAction,
  });

  final List<DiaryTemplate> templates;
  final Set<String> hiddenIds;
  final ValueChanged<DiaryTemplate> onTap;
  final void Function(DiaryTemplate template, DiaryTemplateAction action)
  onAction;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      sliver: SliverList.separated(
        itemCount: templates.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.s),
        itemBuilder: (BuildContext context, int index) {
          final template = templates[index];
          final hidden = hiddenIds.contains(template.id);
          return DiaryTemplateTile(
            key: ValueKey<String>('template_builtin_${template.id}'),
            template: template,
            hidden: hidden,
            onTap: () => onTap(template),
            trailing: DiaryTemplateActionsButton(
              actions: <DiaryTemplateAction>[
                DiaryTemplateAction.copyToMine,
                DiaryTemplateAction.copyCode,
                hidden ? DiaryTemplateAction.show : DiaryTemplateAction.hide,
              ],
              onSelected: (action) => onAction(template, action),
            ),
          );
        },
      ),
    );
  }
}

/// 模板行右侧的“更多操作”菜单；删除项用 error 色。
class DiaryTemplateActionsButton extends StatelessWidget {
  const DiaryTemplateActionsButton({
    super.key,
    required this.actions,
    required this.onSelected,
  });

  final List<DiaryTemplateAction> actions;
  final ValueChanged<DiaryTemplateAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    String label(DiaryTemplateAction action) => switch (action) {
      DiaryTemplateAction.edit => l10n.commonEdit,
      DiaryTemplateAction.duplicate => l10n.diaryTemplatesDuplicate,
      DiaryTemplateAction.copyToMine => l10n.diaryTemplatesCopyToMine,
      DiaryTemplateAction.copyCode => l10n.diaryTemplatesCopyCode,
      DiaryTemplateAction.hide => l10n.diaryTemplatesHide,
      DiaryTemplateAction.show => l10n.diaryTemplatesShow,
      DiaryTemplateAction.delete => l10n.commonDelete,
    };
    return PopupMenuButton<DiaryTemplateAction>(
      tooltip: l10n.diaryTemplatesMoreActions,
      icon: FaIcon(
        FontAwesomeIcons.ellipsisVertical,
        size: 16,
        color: colorScheme.onSurfaceVariant,
      ),
      onSelected: onSelected,
      itemBuilder: (BuildContext context) =>
          <PopupMenuEntry<DiaryTemplateAction>>[
            for (final action in actions)
              PopupMenuItem<DiaryTemplateAction>(
                value: action,
                child: Text(
                  label(action),
                  style: action == DiaryTemplateAction.delete
                      ? TextStyle(color: colorScheme.error)
                      : null,
                ),
              ),
          ],
    );
  }
}
