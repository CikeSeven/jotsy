import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/models/app_surface_settings.dart';
import '../../../widgets/desktop_horizontal_scroll.dart';
import 'app_surface_labels.dart';

/// 区域胶囊行：全局 · 日记 · 日历 · 探索 · 设置 · 编辑 · 预览 · 其他。
///
/// 横向滚动（桌面经 [DesktopHorizontalScroll] 支持鼠标拖动与 Shift + 滚轮），
/// 胶囊沿用设置页里已有的 [ChoiceChip]。不跟随全局（不显示或单独设置）的
/// 区域在名字后带一个小圆点，读屏朗读“已单独设置”。
class AppSurfaceAreaChips extends StatelessWidget {
  const AppSurfaceAreaChips({
    super.key,
    required this.settings,
    required this.selected,
    required this.onSelected,
  });

  final AppSurfaceSettings settings;

  /// 选中的区域；null 为全局。
  final AppBackgroundArea? selected;
  final ValueChanged<AppBackgroundArea?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final areas = <AppBackgroundArea?>[null, ...AppBackgroundArea.values];
    return SizedBox(
      height: 48,
      child: DesktopHorizontalScroll(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: areas.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (BuildContext context, int index) {
            final area = areas[index];
            final label = appSurfaceAreaLabel(l10n, area);
            final customized =
                area != null &&
                settings.areaOf(area).mode != AppAreaBackgroundMode.follow;
            return Center(
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // 圆点本身没有语义，由名字的读屏标签补上“已单独设置”。
                    Text(
                      label,
                      semanticsLabel: customized
                          ? l10n.appSurfaceAreaCustomized(label)
                          : null,
                    ),
                    if (customized) ...<Widget>[
                      const SizedBox(width: 6),
                      const _CustomizedDot(),
                    ],
                  ],
                ),
                selected: area == selected,
                onSelected: (_) => onSelected(area),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 胶囊里“已单独设置”的小圆点。
class _CustomizedDot extends StatelessWidget {
  const _CustomizedDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('appSurfaceCustomizedDot'),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}
