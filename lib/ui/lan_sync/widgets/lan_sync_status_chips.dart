// 同步界面的状态胶囊：英雄卡的地址（点按复制）与发现状态（点按切换），
// 设备详情页的在线 / 离线与平台胶囊共用同一枚 [LanSyncChip]。

import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/expressive_state_blend.dart';

/// 一枚 12 圆角、12.5 / w600 的胶囊。
class LanSyncChip extends StatelessWidget {
  const LanSyncChip({
    super.key,
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

/// 中性胶囊（地址、平台）的底色：玻璃下经 AppGlassField 取未选中态的底色
/// （DESIGN §5.23）；暗色卡片本身就是 surfaceContainerLow，胶囊得再高一档
/// 才看得出来。
Color lanSyncNeutralChipFill(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return AppGlassField.of(context)?.fill ??
      (colors.brightness == Brightness.light
          ? colors.surfaceContainerLow
          : colors.surfaceContainerHigh);
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
    return LanSyncChip(
      background: lanSyncNeutralChipFill(context),
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
        return LanSyncChip(
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
          leading: _statusDot(colors, t),
        );
      },
    );
  }
}

/// “● 可被发现”“● 在线”前的 7dp `primary` 圆点，随补间进度淡入淡出。
Widget? _statusDot(ColorScheme colors, double t) {
  if (t <= 0) return null;
  return Opacity(
    opacity: t,
    child: Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
    ),
  );
}

/// 设备详情页的在线状态胶囊：在线为 `primaryContainer` 底 + `primary` 圆点，
/// 离线为中性底灰字；切换经 [ExpressiveStateBlend] 补间。
class LanSyncOnlineChip extends StatelessWidget {
  const LanSyncOnlineChip({super.key, required this.online});

  final bool online;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final offBackground = lanSyncNeutralChipFill(context);
    return ExpressiveStateBlend(
      active: online,
      builder: (BuildContext context, double t, Widget? child) => LanSyncChip(
        background: Color.lerp(offBackground, colors.primaryContainer, t)!,
        foreground: Color.lerp(
          colors.onSurfaceVariant,
          colors.onPrimaryContainer,
          t,
        )!,
        label: online ? l10n.lanSyncOnline : l10n.lanSyncOffline,
        leading: _statusDot(colors, t),
      ),
    );
  }
}
