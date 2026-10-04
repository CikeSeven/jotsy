import 'package:flutter/material.dart';

import '../../../app/theme/app_radii.dart';
import '../../../app/theme/expressive_surfaces.dart';

/// 设置页统一分组卡片组件。
///
/// 职责：
/// - 将设置项收纳为现代 Grouped Inset Island 卡片；
/// - 消除全屏割裂式粗暴 Divider，内部项之间使用优雅微缩进分割线；
/// - 支持可选的分组标题与底部附注。
class SettingsCardGroup extends StatelessWidget {
  const SettingsCardGroup({
    super.key,
    this.title,
    this.footer,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  final String? title;
  final String? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isLight = colorScheme.brightness == Brightness.light;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 8),
              child: Text(
                title!,
                style: textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(
                color: ExpressiveSurfaces.cardBorderColor(colorScheme),
                width: 0.8,
              ),
              boxShadow: isLight
                  ? <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              color: ExpressiveSurfaces.cardColor(colorScheme),
              borderRadius: BorderRadius.circular(AppRadii.card),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (var i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i < children.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(
                          height: 1,
                          thickness: 0.6,
                          color: colorScheme.outlineVariant.withValues(
                            alpha: isLight ? 0.35 : 0.18,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (footer != null) ...[
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 6),
              child: Text(
                footer!,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
