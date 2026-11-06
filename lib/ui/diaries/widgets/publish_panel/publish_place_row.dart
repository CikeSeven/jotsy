import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/app_radii.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/widgets/on_glass.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';
import 'package:node_diary/utils/relative_time_formatter.dart';

import '../../viewmodels/place_history_view.dart';

/// 用过的地点子页的一行（像地图应用的“最近”）：
///
/// ```
/// (📍)  文三路                       12 篇
///       杭州 · 西湖区               11月2日
/// ```
///
/// - 行首 36dp 圆形图标：带坐标的地点（当时自动定位）为 `secondaryContainer`
///   底 + 定位点，手填的为 `onSurface` 8% 叠色底 + 笔；当前地点就是这一项时（[selected]）
///   换成 `primary` 底的对勾，行底补间到主色浅底、名称加粗；
/// - 中间第一行是最具体的一级（[PlaceLabelParts.name]），有上级时第二行写
///   上级，各自单行省略；
/// - 右侧一列右对齐：篇数与最近一次（[RelativeTimeFormatter]）。这一列不
///   伸缩、内容很短，窄屏时只截名称与上级，数字与日期总能看全。
class PublishPlaceRow extends StatelessWidget {
  const PublishPlaceRow({
    super.key,
    required this.place,
    required this.selected,
    required this.now,
    required this.onTap,
  });

  final DiaryPlaceUsage place;
  final bool selected;

  /// 相对时间的基准；由列表统一取一次，同屏各行口径一致。
  final DateTime now;

  /// 正在定位时为 null（行不可点）。
  final VoidCallback? onTap;

  static const double _radius = AppRadii.input;

  /// 单行（手填、没有上级）与两行的地点行同高。
  static const double _minHeight = 58;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final parts = PlaceLabelParts.of(place.label);
    final region = parts.region;
    // 未选中的底色与标签行同口径：玻璃面板上为半透明凹槽色。
    final idle = OnGlass.of(context)
        ? OnGlass.wellColor(colorScheme)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
    // 选中底与标签行同口径（主色浅底，亮 12% / 暗 22%）：primaryContainer
    // 在部分配色下很饱和，整行压上去太重；选中靠行首的主色对勾一眼可见。
    final selectedFill = colorScheme.primary.withValues(
      alpha: theme.brightness == Brightness.light ? 0.12 : 0.22,
    );
    final muted = colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: ExpressiveStateBlend(
          active: selected,
          builder: (context, t, child) => Material(
            color: Color.lerp(idle, selectedFill, t),
            borderRadius: BorderRadius.circular(_radius),
            child: child,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(_radius),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _minHeight),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 8, 14, 8),
                child: Row(
                  children: <Widget>[
                    _PlaceBadge(
                      located: place.hasCoordinates,
                      selected: selected,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            parts.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                          if (region != null) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              region,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          l10n.placeHistoryUseCount(place.uses),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          RelativeTimeFormatter.formatUpdatedAt(
                            updatedAt: place.lastUsedAt,
                            now: now,
                            l10n: l10n,
                          ),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: muted.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 行首的圆形地点图标；选中时换成主色对勾，图标经 [ExpressiveIconSwap]
/// 交叉缩放、底色经 [ExpressiveStateBlend] 补间。
class _PlaceBadge extends StatelessWidget {
  const _PlaceBadge({required this.located, required this.selected});

  /// 带坐标（自动定位）的地点。
  final bool located;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 手填地点的圆底用 onSurface 叠色而不是某一级 surfaceContainer：行底
    // 本身就是半透明的容器色，暗色与玻璃下固定的容器色会和它融成一片。
    final idleFill = located
        ? colorScheme.secondaryContainer
        : colorScheme.onSurface.withValues(alpha: 0.08);
    final idleIcon = located
        ? colorScheme.onSecondaryContainer
        : colorScheme.onSurfaceVariant;
    return ExpressiveStateBlend(
      active: selected,
      builder: (context, t, _) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Color.lerp(idleFill, colorScheme.primary, t),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: ExpressiveIconSwap(
          switchKey: selected,
          child: selected
              ? FaIcon(
                  FontAwesomeIcons.check,
                  size: 15,
                  color: colorScheme.onPrimary,
                )
              : FaIcon(
                  located ? FontAwesomeIcons.locationDot : FontAwesomeIcons.pen,
                  size: located ? 15 : 12,
                  color: idleIcon,
                ),
        ),
      ),
    );
  }
}
