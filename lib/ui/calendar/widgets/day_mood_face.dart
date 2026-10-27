import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/database/app_database.dart';

// 这天的心情的视觉部件：配色 [DayMoodColors] 与五官 [DayMoodFace]。日期格
// （CalendarMoodTile）与长按面板的心情选择（DayMoodPicker）共用，面板里
// 看到的就是选完后日期格的样子。只负责绘制，无副作用。

/// 心情的名称（长按面板的标签与读屏）。
String dayMoodLabel(AppLocalizations l10n, DayMood mood) => switch (mood) {
  DayMood.awful => l10n.dayMoodAwful,
  DayMood.bad => l10n.dayMoodBad,
  DayMood.meh => l10n.dayMoodMeh,
  DayMood.good => l10n.dayMoodGood,
  DayMood.great => l10n.dayMoodGreat,
};

/// 一种心情在日历上的配色：整格底色 [tile] 与其上的五官、日期数字 [onTile]。
///
/// 取各色系的 container / onContainer 一对：明暗主题下对比度都由 Material
/// 配色保证，五官与数字在任何种子色下都读得清。色相与日记心情的五段配色
/// （`MoodBandPalette`：error / tertiary / outline / 两档 primary）同序，
/// 年视图按心情着色时同一种心情是同一色系；“不错”取 secondary 而不是浅一档
/// 的 primary——整格铺色时两档 primary 的底色几乎分不开。
@immutable
class DayMoodColors {
  const DayMoodColors({required this.tile, required this.onTile});

  factory DayMoodColors.of(ColorScheme colorScheme, DayMood mood) {
    return switch (mood) {
      DayMood.awful => DayMoodColors(
        tile: colorScheme.errorContainer,
        onTile: colorScheme.onErrorContainer,
      ),
      DayMood.bad => DayMoodColors(
        tile: colorScheme.tertiaryContainer,
        onTile: colorScheme.onTertiaryContainer,
      ),
      DayMood.meh => DayMoodColors(
        tile: colorScheme.surfaceContainerHighest,
        onTile: colorScheme.onSurfaceVariant,
      ),
      DayMood.good => DayMoodColors(
        tile: colorScheme.secondaryContainer,
        onTile: colorScheme.onSecondaryContainer,
      ),
      DayMood.great => DayMoodColors(
        tile: colorScheme.primaryContainer,
        onTile: colorScheme.onPrimaryContainer,
      ),
    };
  }

  final Color tile;
  final Color onTile;

  /// 相邻月份的日期：底色与五官一起淡化，与普通格子淡化数字同一口径。
  DayMoodColors faded() => DayMoodColors(
    tile: tile.withValues(alpha: tile.a * 0.45),
    onTile: onTile.withValues(alpha: onTile.a * 0.5),
  );

  @override
  bool operator ==(Object other) =>
      other is DayMoodColors && other.tile == tile && other.onTile == onTile;

  @override
  int get hashCode => Object.hash(tile, onTile);
}

/// 心情的脸：只画五官（眼睛、嘴，最低一档加眉毛和泪滴），没有脸的外圈——
/// 所在的格子就是脸。除了最低一档张嘴大哭，五官都是同一粗细的线条。按给定方框里最大的正方形等比缩放，
/// 小到日期格里的二十来 dp 也认得出表情。
class DayMoodFace extends StatelessWidget {
  const DayMoodFace({super.key, required this.mood, required this.color});

  final DayMood mood;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DayMoodFacePainter(mood: mood, color: color),
    );
  }
}

/// 五官以脸的半径 r 为单位、圆心为原点定位（x 向右、y 向下），线宽、点径
/// 同样按 r 缩放，大小格子里笔画比例一致。
///
/// 没有脸的外圈，五官只占半径的六成左右：r 取方框半边的 [_scale] 倍，五官
/// 撑满方框；中心略微上移，张开的嘴不会显得坠在底部。
class _DayMoodFacePainter extends CustomPainter {
  _DayMoodFacePainter({required this.mood, required this.color});

  final DayMood mood;
  final Color color;

  /// 眼睛的横向位置与点眼半径。
  static const double _eyeX = 0.41;
  static const double _eyeRadius = 0.14;
  static const double _strokeWidth = 0.16;
  static const double _scale = 1.25;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.min(size.width, size.height) / 2 * _scale;
    if (r <= 0) {
      return;
    }
    final center = size.center(Offset(0, -0.05 * r));
    Offset at(double x, double y) => center + Offset(x * r, y * r);
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = _strokeWidth * r;

    // 一条二次曲线：起点、控制点、终点。
    Path curve(Offset from, Offset control, Offset to) => Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(control.dx, control.dy, to.dx, to.dy);

    void dotEyes({double y = -0.2}) {
      canvas.drawCircle(at(-_eyeX, y), _eyeRadius * r, fill);
      canvas.drawCircle(at(_eyeX, y), _eyeRadius * r, fill);
    }

    // 张开的嘴：填色后再描一圈细边，转角是圆的，不是尖角。
    void openMouth(Path mouth) {
      canvas.drawPath(mouth, fill);
      canvas.drawPath(
        mouth,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = 0.09 * r,
      );
    }

    switch (mood) {
      case DayMood.great:
        // 笑弯的眼睛（^ ^）+ 比“不错”更宽更深的笑。没有外圈的脸上不加腮红、
        // 不画张开的嘴：腮红落在格子两侧像胡须，大嘴会压过整张脸。
        for (final side in const <double>[-1, 1]) {
          final x = side * _eyeX;
          canvas.drawPath(
            curve(at(x - 0.15, -0.14), at(x, -0.5), at(x + 0.15, -0.14)),
            stroke,
          );
        }
        canvas.drawPath(
          curve(at(-0.5, 0.16), at(0, 0.82), at(0.5, 0.16)),
          stroke,
        );
      case DayMood.good:
        dotEyes();
        canvas.drawPath(
          curve(at(-0.46, 0.23), at(0, 0.71), at(0.46, 0.23)),
          stroke,
        );
      case DayMood.meh:
        dotEyes();
        canvas.drawLine(at(-0.34, 0.39), at(0.34, 0.39), stroke);
      case DayMood.bad:
        dotEyes(y: -0.14);
        canvas.drawPath(
          curve(at(-0.41, 0.53), at(0, 0.16), at(0.41, 0.53)),
          stroke,
        );
      case DayMood.awful:
        // 八字眉 + 哭得闭上的眼睛 + 张嘴 + 一滴泪。
        for (final side in const <double>[-1, 1]) {
          final x = side * _eyeX;
          canvas.drawLine(
            at(side * 0.62, -0.41),
            at(side * 0.23, -0.575),
            stroke..strokeWidth = 0.13 * r,
          );
          canvas.drawPath(
            curve(at(x - 0.17, -0.18), at(x, 0.07), at(x + 0.17, -0.18)),
            stroke..strokeWidth = 0.14 * r,
          );
        }
        openMouth(
          curve(at(-0.35, 0.69), at(0, 0.115), at(0.35, 0.69))..close(),
        );
        canvas.drawPath(
          curve(at(0.48, 0.07), at(0.67, 0.37), at(0.48, 0.41))
            ..quadraticBezierTo(
              at(0.3, 0.37).dx,
              at(0.3, 0.37).dy,
              at(0.48, 0.07).dx,
              at(0.48, 0.07).dy,
            ),
          Paint()..color = color.withValues(alpha: color.a * 0.75),
        );
    }
  }

  @override
  bool shouldRepaint(_DayMoodFacePainter oldDelegate) =>
      oldDelegate.mood != mood || oldDelegate.color != color;
}
