import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart' show FaIcon;

import '../../../app/theme/expressive_surfaces.dart';
import '../../widgets/expressive_state_blend.dart';
import '../models/lan_sync_platform.dart';
import 'lan_sync_labels.dart';

/// 设备行前的 48dp 图标块（DESIGN.md §5.27 设备行）。
///
/// - [active]（已配对且在线）：`primaryContainer` 底 + `onPrimaryContainer`
///   图标，右下角 14dp `primary` 在线点（2.5dp 卡片色描边）；
/// - 否则（离线、附近设备）：`surfaceContainer` 底 + `onSurfaceVariant` 图标，
///   没有在线点。
///
/// 在线 / 离线切换时底色、图标色与在线点经 [ExpressiveStateBlend] 补间，
/// 不在一帧内跳变。纯装饰，读屏只读行里的文字。
class LanSyncDeviceTile extends StatelessWidget {
  const LanSyncDeviceTile({
    super.key,
    required this.platform,
    required this.active,
  });

  static const double size = 48;
  static const double _dotSize = 14;
  static const double _dotBorder = 2.5;

  final LanSyncPlatform platform;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ringColor = ExpressiveSurfaces.cardColor(colors);
    return ExcludeSemantics(
      child: ExpressiveStateBlend(
        active: active,
        builder: (BuildContext context, double t, Widget? child) {
          // 暗色卡片为 surfaceContainerLow，中性图标块取 surfaceContainerHigh
          // 才与卡片拉开层次（亮色白卡片上 surfaceContainer 已足够）。
          final neutral = colors.brightness == Brightness.light
              ? colors.surfaceContainer
              : colors.surfaceContainerHigh;
          final background = Color.lerp(neutral, colors.primaryContainer, t)!;
          final foreground = Color.lerp(
            colors.onSurfaceVariant,
            colors.onPrimaryContainer,
            t,
          )!;
          return SizedBox.square(
            dimension: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: FaIcon(
                        lanSyncPlatformIcon(platform),
                        size: 20,
                        color: foreground,
                      ),
                    ),
                  ),
                ),
                if (t > 0)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Transform.scale(
                      scale: t,
                      child: Container(
                        width: _dotSize,
                        height: _dotSize,
                        decoration: BoxDecoration(
                          color: colors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: ringColor,
                            width: _dotBorder,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
