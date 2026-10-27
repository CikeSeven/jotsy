import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/app_glass_scope.dart';
import '../../app_surface/widgets/app_glass_surface.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';
import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../widgets/expressive_menu/expressive_menu.dart';
import '../models/diary_template.dart';
import '../widgets/diary_template_tile.dart';

/// 模板行菜单里的操作。[reset] 只出现在改过的内置模板上。
enum DiaryTemplateAction { edit, duplicate, copyCode, reset, delete }

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
          // 分组标题直接画在页面背景上（不在卡片里），有背景图时加可读性兜底。
          style: AppPageBackdrop.onBackgroundTextStyle(
            context,
            theme.textTheme.titleMedium?.copyWith(
              fontSize: 16,
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
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
    final body = Padding(
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
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
      // 玻璃时为内容玻璃（共用页面背景读取、无背景图不模糊）；经典分支
      // 保持原样。
      child: AppGlass.of(context).isGlass(AppGlassComponent.cards)
          ? AppGlassSurface(
              component: AppGlassComponent.cards,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadii.input),
              ),
              child: body,
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                color: ExpressiveSurfaces.cardColor(colorScheme),
                borderRadius: BorderRadius.circular(AppRadii.input),
                border: Border.fromBorderSide(
                  ExpressiveSurfaces.cardBorderSide(colorScheme),
                ),
              ),
              child: body,
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

/// 内置模板（不含已删除的）：与我的模板一样点按即编辑，菜单里编辑、复制、
/// 复制模板码、恢复默认（只在改过时出现）与删除；不能拖动排序，始终按内置
/// 顺序排列。
class DiaryTemplatesBuiltInSliver extends StatelessWidget {
  const DiaryTemplatesBuiltInSliver({
    super.key,
    required this.templates,
    required this.editedIds,
    required this.onTap,
    required this.onAction,
  });

  final List<DiaryTemplate> templates;

  /// 改过内容的内置模板，带“已修改”标记与“恢复默认”。
  final Set<String> editedIds;
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
          final edited = editedIds.contains(template.id);
          return DiaryTemplateTile(
            key: ValueKey<String>('template_builtin_${template.id}'),
            template: template,
            edited: edited,
            onTap: () => onTap(template),
            trailing: DiaryTemplateActionsButton(
              actions: <DiaryTemplateAction>[
                DiaryTemplateAction.edit,
                DiaryTemplateAction.duplicate,
                DiaryTemplateAction.copyCode,
                if (edited) DiaryTemplateAction.reset,
                DiaryTemplateAction.delete,
              ],
              onSelected: (action) => onAction(template, action),
            ),
          );
        },
      ),
    );
  }
}

/// 模板行右侧的“更多操作”菜单；删除项为危险操作（error 色）。
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
      DiaryTemplateAction.copyCode => l10n.diaryTemplatesCopyCode,
      DiaryTemplateAction.reset => l10n.diaryTemplatesResetBuiltIn,
      DiaryTemplateAction.delete => l10n.commonDelete,
    };
    FaIconData icon(DiaryTemplateAction action) => switch (action) {
      DiaryTemplateAction.edit => FontAwesomeIcons.penToSquare,
      DiaryTemplateAction.duplicate => FontAwesomeIcons.copy,
      DiaryTemplateAction.copyCode => FontAwesomeIcons.code,
      DiaryTemplateAction.reset => FontAwesomeIcons.rotateLeft,
      DiaryTemplateAction.delete => FontAwesomeIcons.trashCan,
    };
    return ExpressiveMenuButton(
      tooltip: l10n.diaryTemplatesMoreActions,
      icon: FaIcon(
        FontAwesomeIcons.ellipsisVertical,
        size: 16,
        color: colorScheme.onSurfaceVariant,
      ),
      items: <Widget>[
        for (final action in actions)
          ExpressiveMenuItem(
            leadingIcon: FaIcon(icon(action)),
            destructive: action == DiaryTemplateAction.delete,
            onPressed: () => onSelected(action),
            child: Text(label(action)),
          ),
      ],
    );
  }
}
