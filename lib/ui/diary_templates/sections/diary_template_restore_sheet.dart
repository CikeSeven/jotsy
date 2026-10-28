import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../../app_surface/widgets/app_glass_scope.dart';
import '../../app_surface/widgets/app_glass_surface.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../models/diary_template.dart';
import '../widgets/diary_template_tile.dart';

/// 内置模板列表末尾的“恢复已删除的内置模板”一行：只在有被删除的内置模板
/// 时出现，右侧是个数，点按打开 [showDiaryTemplateRestoreSheet]。外形与模板
/// 行一致（卡片表面 + 微边框）。
class DiaryTemplatesRestoreRow extends StatelessWidget {
  const DiaryTemplatesRestoreRow({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final ink = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.l),
        child: Row(
          children: <Widget>[
            FaIcon(
              FontAwesomeIcons.rotateLeft,
              size: 16,
              color: colorScheme.primary,
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text(
                l10n.diaryTemplatesRestoreDeleted,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            Text(
              l10n.diaryTemplatesRestoreDeletedCount(count),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            FaIcon(
              FontAwesomeIcons.angleRight,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
    // 与 [DiaryTemplateTile] 同一材质：玻璃时为内容玻璃，经典分支保持原样。
    if (AppGlass.of(context).isGlass(AppGlassComponent.cards)) {
      return AppGlassSurface(
        component: AppGlassComponent.cards,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadii.input)),
        child: ink,
      );
    }
    return Material(
      color: ExpressiveSurfaces.cardColor(colorScheme),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.input),
        side: BorderSide(
          color: ExpressiveSurfaces.cardBorderColor(colorScheme),
          width: 0.8,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ink,
    );
  }
}

/// 已删除的内置模板面板：每行一个模板，右侧“恢复”；两个以上时标题旁有
/// “全部恢复”。只负责挑选，返回要恢复的模板 id（一个或全部），关闭面板
/// 返回 null；写入由调用方经 `DiaryTemplatesController.restoreBuiltIns` 完成。
Future<List<String>?> showDiaryTemplateRestoreSheet(
  BuildContext context, {
  required List<DiaryTemplate> templates,
}) {
  return showAppModalBottomSheet<List<String>>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) {
      final l10n = sheetContext.l10n;
      final theme = Theme.of(sheetContext);
      void pick(List<String> ids) => Navigator.of(sheetContext).pop(ids);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        builder: (BuildContext context, ScrollController controller) {
          return ListView(
            controller: controller,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.l,
              0,
              AppSpacing.l,
              AppSpacing.l + MediaQuery.paddingOf(context).bottom,
            ),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        l10n.diaryTemplatesRestoreSheetTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (templates.length > 1)
                      TextButton(
                        onPressed: () =>
                            pick(<String>[for (final t in templates) t.id]),
                        child: Text(l10n.diaryTemplatesRestoreAll),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.xs,
                  AppSpacing.m,
                ),
                child: Text(
                  l10n.diaryTemplatesRestoreSheetHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final (index, template) in templates.indexed) ...<Widget>[
                if (index > 0) const SizedBox(height: AppSpacing.s),
                DiaryTemplateTile(
                  key: ValueKey<String>('template_restore_${template.id}'),
                  template: template,
                  onTap: () => pick(<String>[template.id]),
                  trailing: TextButton(
                    onPressed: () => pick(<String>[template.id]),
                    child: Text(l10n.diaryTemplatesRestore),
                  ),
                ),
              ],
            ],
          );
        },
      );
    },
  );
}
