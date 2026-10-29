// 英雄卡的状态胶囊：地址（点按复制）与发现状态（点按切换）。

import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/expressive_state_blend.dart';

/// 一枚 12 圆角、12.5 / w600 的胶囊。
class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.background,
    required this.foreground,
    required this.label,
    this.leading,
    this.onTap,
    this.hint,
    this.tabular = false,
  });

  final Color background;
  final Color foreground;
  final String label;
  final Widget? leading;
  final VoidCallback? onTap;
  final String? hint;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leading = this.leading;
    final radius = BorderRadius.circular(12);
    return Semantics(
      button: onTap != null,
      hint: hint,
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  leading,
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                      fontFeatures: tabular
                          ? const <FontFeature>[FontFeature.tabularFigures()]
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 地址胶囊：等宽数字，点按复制；没有地址时为灰字“未连接局域网”。
class LanSyncAddressChip extends StatelessWidget {
  const LanSyncAddressChip({
    super.key,
    required this.address,
    required this.onCopy,
  });

  final String? address;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final address = this.address;
    // 玻璃下自定底色的胶囊经 AppGlassField 取未选中态的底色（DESIGN §5.23）。
    // 暗色卡片本身就是 surfaceContainerLow，胶囊得再高一档才看得出来。
    final background =
        AppGlassField.of(context)?.fill ??
        (colors.brightness == Brightness.light
            ? colors.surfaceContainerLow
            : colors.surfaceContainerHigh);
    return _HeroChip(
      background: background,
      foreground: address == null ? colors.onSurfaceVariant : colors.onSurface,
      label: address ?? l10n.lanSyncNoNetwork,
      tabular: true,
      hint: address == null ? null : l10n.lanSyncCopyAddressHint,
      onTap: address == null ? null : onCopy,
    );
  }
}

/// 发现状态胶囊：“● 可被发现”（`primaryContainer` 底 + `primary` 圆点）/
/// “不可被发现”（`surfaceContainerHigh` 底灰字）；点按切换，换色经
/// [ExpressiveStateBlend] 补间。
class LanSyncDiscoverableChip extends StatelessWidget {
  const LanSyncDiscoverableChip({
    super.key,
    required this.discoverable,
    required this.onToggle,
  });

  final bool discoverable;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final offBackground =
        AppGlassField.of(context)?.fill ?? colors.surfaceContainerHigh;
    return ExpressiveStateBlend(
      active: discoverable,
      builder: (BuildContext context, double t, Widget? child) {
        return _HeroChip(
          background: Color.lerp(offBackground, colors.primaryContainer, t)!,
          foreground: Color.lerp(
            colors.onSurfaceVariant,
            colors.onPrimaryContainer,
            t,
          )!,
          label: discoverable
              ? l10n.lanSyncDiscoverable
              : l10n.lanSyncNotDiscoverable,
          hint: l10n.lanSyncDiscoverableToggleHint,
          onTap: onToggle,
          leading: t > 0
              ? Opacity(
                  opacity: t,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
