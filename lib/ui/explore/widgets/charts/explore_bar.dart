import 'package:flutter/material.dart';

/// 横条：圆角轨道里按 [fraction]（0~1）填充，探索页与日记本统计页的分布条
/// 共用。
class ExploreBar extends StatelessWidget {
  const ExploreBar({
    super.key,
    required this.fraction,
    required this.color,
    required this.track,
    this.height = 12,
  });

  final double fraction;
  final Color color;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    return Container(
      height: height,
      decoration: BoxDecoration(color: track, borderRadius: radius),
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: fraction.clamp(0.0, 1.0),
        heightFactor: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: radius),
        ),
      ),
    );
  }
}
