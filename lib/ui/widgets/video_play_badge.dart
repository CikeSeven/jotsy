import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 视频缩略图正中的小播放圆钮：表面色 82% 圆底 + `onSurface` 播放图标，只
/// 表示“这是一段视频”，不响应点按（点按由缩略图本身处理）。存储管理的
/// 缩略图与正文视频小图共用。
class VideoPlayBadge extends StatelessWidget {
  const VideoPlayBadge({super.key, this.iconSize = 10});

  /// 播放图标的边长；圆底的内边距按它的 0.6 倍取。
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.82),
        shape: BoxShape.circle,
      ),
      child: Padding(
        padding: EdgeInsets.all(iconSize * 0.6),
        child: FaIcon(
          FontAwesomeIcons.play,
          size: iconSize,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
