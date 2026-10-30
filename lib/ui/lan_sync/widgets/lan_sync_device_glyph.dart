import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../models/lan_sync_platform.dart';
import 'lan_sync_labels.dart';
import 'm3e_cookie_shape.dart';

/// 九瓣饼干形里的设备图标：英雄卡雷达中心与设备详情页的大图标。
///
/// 底色 `primaryContainer`、图标 `onPrimaryContainer`（DESIGN.md §5.28）；
/// 纯装饰，读屏不读（名称由旁边的文字给出）。
class LanSyncDeviceGlyph extends StatelessWidget {
  const LanSyncDeviceGlyph({
    super.key,
    required this.platform,
    this.size = 88,
    this.iconSize = 36,
  });

  final LanSyncPlatform platform;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: ShapeDecoration(
            color: colors.primaryContainer,
            shape: const M3eCookieBorder(lobes: 9),
          ),
          child: Center(
            child: FaIcon(
              lanSyncPlatformIcon(platform),
              size: iconSize,
              color: colors.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}
