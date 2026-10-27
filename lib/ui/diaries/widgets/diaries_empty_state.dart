import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/app_page_backdrop.dart';

/// 笔记列表空状态组件。
///
/// 当当前列表没有可显示笔记时，给出简洁空态和“创建笔记”入口。
class DiariesEmptyState extends StatelessWidget {
  const DiariesEmptyState({
    super.key,
    required this.onCreate,
    this.isSearchResultEmpty = false,
  });

  final VoidCallback onCreate;
  final bool isSearchResultEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = Theme.of(context).colorScheme;
    // 空状态直接画在页面背景上：有背景图时图标与文字经同一可读性兜底
    // （无背景图时原样返回，与改动前一致）。
    TextStyle? onBackground(TextStyle? style) =>
        AppPageBackdrop.onBackgroundTextStyle(context, style);
    final iconStyle = onBackground(TextStyle(color: color.secondary));
    // 搜索结果为空时使用“搜索语义”空态文案，不显示新建按钮。
    if (isSearchResultEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.magnifyingGlass,
              size: 38,
              color: iconStyle?.color,
              shadows: iconStyle?.shadows,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.autoT0152,
              style: onBackground(
                Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: color.onSurface),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.autoT0153,
              style: onBackground(
                Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    // 普通空态：提供新建入口。
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(
            FontAwesomeIcons.penToSquare,
            size: 38,
            color: iconStyle?.color,
            shadows: iconStyle?.shadows,
          ),
          const SizedBox(height: 12),
          Text(l10n.autoT0154, style: onBackground(null)),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const FaIcon(FontAwesomeIcons.plus),
            label: Text(l10n.autoT0155),
          ),
        ],
      ),
    );
  }
}
