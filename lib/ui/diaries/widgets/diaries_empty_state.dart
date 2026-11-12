import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';

/// 日记列表空状态：图标圆 + 标题（搜索为空时再加一行提示）。
///
/// 不放“新建”按钮：首页右下角（或底栏里）已有新建入口，空态里再放一个
/// 会重复。整块直接画在页面背景上、不垫底色：玻璃 / 背景图时透出页面，
/// 不出现一块实色；图标圆只用低透明度的主色，叠在任何底上都只是淡淡一层。
class DiariesEmptyState extends StatelessWidget {
  const DiariesEmptyState({super.key, this.isSearchResultEmpty = false});

  /// 搜索没有结果：换成放大镜与“换个关键词”的提示。
  final bool isSearchResultEmpty;

  static const double _iconDiscSize = 72;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // 有背景图时图标与文字经同一可读性兜底（无背景图时原样返回）。
    TextStyle? onBackground(TextStyle? style) =>
        AppPageBackdrop.onBackgroundTextStyle(context, style);
    final iconStyle = onBackground(TextStyle(color: scheme.primary));
    final subtitle = isSearchResultEmpty ? l10n.autoT0153 : null;

    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xl * 2,
        bottom: AppSpacing.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: _iconDiscSize,
            height: _iconDiscSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: 0.10),
            ),
            child: FaIcon(
              isSearchResultEmpty
                  ? FontAwesomeIcons.magnifyingGlass
                  : FontAwesomeIcons.penToSquare,
              size: 28,
              color: iconStyle?.color,
              shadows: iconStyle?.shadows,
            ),
          ),
          const SizedBox(height: AppSpacing.m),
          Text(
            isSearchResultEmpty ? l10n.autoT0152 : l10n.autoT0154,
            textAlign: TextAlign.center,
            style: onBackground(
              theme.textTheme.titleMedium?.copyWith(color: scheme.onSurface),
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: onBackground(
                theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
