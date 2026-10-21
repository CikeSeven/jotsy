import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_surfaces.dart';
import '../models/diary_template.dart';
import 'diary_template_icon_badge.dart';

/// 一个模板的列表行：图标徽章、名称、两行说明，以及“推荐”“已修改”标记。
/// 模板面板与模板管理页共用。
///
/// 用行而不用网格：两列网格在 320dp 宽、1.3 倍字号下放不下名称与说明。
/// [trailing] 放管理页的操作按钮；[edited] 标出改过内容的内置模板。只负责
/// 展示与回调。
class DiaryTemplateTile extends StatelessWidget {
  const DiaryTemplateTile({
    super.key,
    required this.template,
    this.onTap,
    this.recommended = false,
    this.edited = false,
    this.leading,
    this.trailing,
  });

  final DiaryTemplate template;
  final VoidCallback? onTap;
  final bool recommended;
  final bool edited;

  /// 放在图标前面（管理页的拖动手柄）。
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final secondary = colorScheme.onSurfaceVariant;
    final name = template.name.isEmpty
        ? l10n.diaryTemplateUntitled
        : template.name;
    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        leading == null ? AppSpacing.l : AppSpacing.xs,
        AppSpacing.m,
        trailing == null ? AppSpacing.l : AppSpacing.xs,
        AppSpacing.m,
      ),
      child: Row(
        children: <Widget>[
          ?leading,
          DiaryTemplateIconBadge(icon: template.icon, accent: template.accent),
          const SizedBox(width: AppSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: AppSpacing.s,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: template.name.isEmpty ? secondary : null,
                      ),
                    ),
                    if (recommended)
                      DiaryTemplateBadge(label: l10n.diaryTemplateRecommended),
                    if (edited)
                      DiaryTemplateBadge(
                        label: l10n.diaryTemplateEditedBadge,
                        muted: true,
                      ),
                  ],
                ),
                if (template.description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    template.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
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
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
