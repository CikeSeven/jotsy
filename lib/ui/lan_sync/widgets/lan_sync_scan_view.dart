// 扫码页的画面（DESIGN.md §5.28“扫码页”），与相机解耦：相机画面由调用方
// 传入 [camera]，其余全由参数决定，测试可直接挂上。
//
// 布局：相机铺满 → 取景层（遮罩、括号、扫描线）→ 顶部 44dp 半透明圆形
// 关闭按钮 +“扫码连接” → 框下两行说明 → 底部一行轻提示（扫到别的码时）、
// 60dp 半透明圆形手电筒按钮与“没有二维码？手动输入地址”。相机不可用
// （[failure] 非空）时取景层、说明与手电筒换成居中的说明块。
//
// 颜色一律取当前主题：扫码页整页套用暗色主题（见 lan_sync_scan_page.dart），
// 这里不写任何固定色值。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import 'lan_sync_scan_overlay.dart';
import 'lan_sync_scan_parts.dart';

/// 相机为什么用不了。
enum LanSyncScanFailure {
  /// 用户拒绝了相机权限。
  permissionDenied,

  /// 没有相机、被占用或其他错误。
  unavailable,
}

/// 手电筒状态。
enum LanSyncTorch { off, on, unavailable }

/// 见文件头注释。
class LanSyncScanView extends StatelessWidget {
  const LanSyncScanView({
    super.key,
    required this.camera,
    required this.failure,
    required this.torch,
    required this.hint,
    required this.onClose,
    required this.onToggleTorch,
    required this.onManualAddress,
    this.onOpenSettings,
  });

  final Widget camera;
  final LanSyncScanFailure? failure;
  final LanSyncTorch torch;

  /// 底部的轻提示（扫到不是 Jotsy 的码）；null 不显示。
  final String? hint;
  final VoidCallback onClose;
  final VoidCallback onToggleTorch;
  final VoidCallback onManualAddress;

  /// 权限被拒时的“去设置”；null 时不显示该按钮。
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final failure = this.failure;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final frame = lanSyncScanFrameRect(constraints.biggest);
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            camera,
            if (failure == null) ...<Widget>[
              LanSyncScanOverlay(frame: frame),
              Positioned(
                left: 24,
                right: 24,
                top: frame.bottom + 28,
                child: Column(
                  children: <Widget>[
                    Text(
                      l10n.lanSyncScanHint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.lanSyncScanHintDetail,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              ColoredBox(
                color: colors.surfaceContainerLowest,
                child: LanSyncScanFailureBody(
                  failure: failure,
                  onOpenSettings: onOpenSettings,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: <Widget>[
                      LanSyncScanRoundButton(
                        extent: 44,
                        tooltip: l10n.commonClose,
                        icon: FontAwesomeIcons.xmark,
                        onPressed: onClose,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.lanSyncScanQr,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _BottomBar(
                    hint: failure == null ? hint : null,
                    torch: failure == null ? torch : null,
                    onToggleTorch: onToggleTorch,
                    onManualAddress: onManualAddress,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.hint,
    required this.torch,
    required this.onToggleTorch,
    required this.onManualAddress,
  });

  final String? hint;

  /// null 为不显示手电筒（相机不可用）。
  final LanSyncTorch? torch;
  final VoidCallback onToggleTorch;
  final VoidCallback onManualAddress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = context.l10n;
    final hint = this.hint;
    final torch = this.torch;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedSwitcher(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
          switchInCurve: ExpressiveMotion.effects,
          switchOutCurve: ExpressiveMotion.exit,
          child: hint == null
              ? const SizedBox(height: 0, width: double.infinity)
              : Padding(
                  key: ValueKey<String>(hint),
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      hint,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
        ),
        if (torch != null) ...<Widget>[
          LanSyncScanRoundButton(
            extent: 60,
            tooltip: torch == LanSyncTorch.on
                ? l10n.lanSyncScanTorchOff
                : l10n.lanSyncScanTorchOn,
            icon: torch == LanSyncTorch.on
                ? FontAwesomeIcons.solidLightbulb
                : FontAwesomeIcons.lightbulb,
            selected: torch == LanSyncTorch.on,
            onPressed: torch == LanSyncTorch.unavailable ? null : onToggleTorch,
          ),
          const SizedBox(height: 12),
        ],
        TextButton(
          onPressed: onManualAddress,
          child: Text(l10n.lanSyncScanManual),
        ),
      ],
    );
  }
}
