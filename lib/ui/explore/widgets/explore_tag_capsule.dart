import 'package:flutter/material.dart';

/// 标签微胶囊（DESIGN §5.2）：`# ` 前缀用标签色、标签色淡底、无描边无阴影，
/// 可选在名字后写次数。探索页标签卡与日记本统计页“常用标签”共用。
///
/// [scale] 按使用频次放大字号（标签云），默认 1；给了 [onTap] 时整个胶囊
/// 可点，水波纹画在胶囊自身的底色上。
class ExploreTagCapsule extends StatelessWidget {
  const ExploreTagCapsule({
    super.key,
    required this.name,
    required this.color,
    this.count,
    this.scale = 1,
    this.onTap,
  });

  final String name;

  /// 标签色（ARGB）。
  final int color;
  final int? count;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final tagColor = Color(color);
    final background = tagColor.withValues(alpha: isLight ? 0.12 : 0.15);
    final radius = BorderRadius.circular(8);
    final count = this.count;
    final label = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '# ',
              style: TextStyle(color: tagColor, fontWeight: FontWeight.w800),
            ),
            TextSpan(text: name),
            if (count != null)
              TextSpan(
                text: '  $count',
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 12 * scale,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
    );
    final onTap = this.onTap;
    if (onTap == null) {
      return DecoratedBox(
        decoration: BoxDecoration(color: background, borderRadius: radius),
        child: label,
      );
    }
    return Material(
      color: background,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: label),
    );
  }
}
