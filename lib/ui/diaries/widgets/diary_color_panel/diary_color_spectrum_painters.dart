import 'package:flutter/material.dart';

/// 自定义取色页的色谱绘制：饱和度 / 亮度面、色相条、不透明度条与拖动圆点。
///
/// 应用界面禁用渐变，这里是 AGENTS.md §6 写明的例外：色谱不是装饰，而是
/// 颜色空间本身，只能连续地画出来。纯白、纯黑同理是颜色数据，不随主题变化；
/// 只有描边与不透明度条的棋盘格取主题色。
///
/// 位置换算：轨道两端各留出圆点半径 [kDiaryColorThumbRadius]，圆点中心只在
/// 这段“行程”里移动，渐变也只铺在行程上（两端以端点色延伸），手指下的颜色
/// 与圆点里的颜色始终一致。
const double kDiaryColorThumbRadius = 11;

/// 拖动中的圆点半径：放大一圈，手指压着也看得见。
const double kDiaryColorThumbActiveRadius = 13;

const Color _white = Color(0xFFFFFFFF);
const Color _clearWhite = Color(0x00FFFFFF);
const Color _black = Color(0xFF000000);
const Color _clearBlack = Color(0x00000000);

/// 圆点外圈的深色细线：白环落在纯白色谱上时靠它勾出轮廓。
const Color _thumbHairline = Color(0x59000000);

/// 色谱面的圆角；竖条用宽度一半的圆角（胶囊形）。
const double kDiaryColorSpectrumRadius = 12;

/// 圆点中心可移动的范围（轨道四周各缩进一个圆点半径）。
Rect diaryColorThumbTravel(Size size) => Rect.fromLTRB(
  kDiaryColorThumbRadius,
  kDiaryColorThumbRadius,
  size.width - kDiaryColorThumbRadius,
  size.height - kDiaryColorThumbRadius,
);

/// 画拖动圆点：深色细线 → 白环 → 所选颜色（半透明色叠在白环上）。
void paintDiaryColorThumb(
  Canvas canvas,
  Offset center,
  double radius,
  Color fill,
) {
  canvas
    ..drawCircle(center, radius, Paint()..color = _thumbHairline)
    ..drawCircle(center, radius - 1, Paint()..color = _white)
    ..drawCircle(center, radius - 4, Paint()..color = fill);
}

/// 饱和度（横向，左 0 右 1）× 亮度（纵向，上 1 下 0）面。
class DiaryColorSaturationValuePainter extends CustomPainter {
  const DiaryColorSaturationValuePainter({
    required this.color,
    required this.thumbRadius,
    required this.outline,
  });

  final HSVColor color;
  final double thumbRadius;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(
      bounds,
      const Radius.circular(kDiaryColorSpectrumRadius),
    );
    final travel = diaryColorThumbTravel(size);
    canvas
      ..save()
      ..clipRRect(shape)
      ..drawRect(
        bounds,
        Paint()..color = HSVColor.fromAHSV(1, color.hue, 1, 1).toColor(),
      )
      ..drawRect(
        bounds,
        Paint()
          ..shader = const LinearGradient(
            colors: <Color>[_white, _clearWhite],
          ).createShader(travel),
      )
      ..drawRect(
        bounds,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[_clearBlack, _black],
          ).createShader(travel),
      )
      ..restore()
      ..drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = outline,
      );
    paintDiaryColorThumb(
      canvas,
      Offset(
        travel.left + color.saturation * travel.width,
        travel.top + (1 - color.value) * travel.height,
      ),
      thumbRadius,
      color.withAlpha(1).toColor(),
    );
  }

  @override
  bool shouldRepaint(DiaryColorSaturationValuePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.thumbRadius != thumbRadius ||
      oldDelegate.outline != outline;
}

/// 竖向色相条：上 0° 到下 360°，饱和度与亮度取满。
class DiaryColorHuePainter extends CustomPainter {
  const DiaryColorHuePainter({
    required this.hue,
    required this.thumbRadius,
    required this.outline,
  });

  final double hue;
  final double thumbRadius;
  final Color outline;

  static final List<Color> _stops = <Color>[
    for (var degree = 0; degree <= 360; degree += 60)
      HSVColor.fromAHSV(1, degree % 360, 1, 1).toColor(),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final shape = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.width / 2),
    );
    final travel = diaryColorThumbTravel(size);
    canvas
      ..drawRRect(
        shape,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _stops,
          ).createShader(travel),
      )
      ..drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = outline,
      );
    paintDiaryColorThumb(
      canvas,
      Offset(size.width / 2, travel.top + hue / 360 * travel.height),
      thumbRadius,
      HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
    );
  }

  @override
  bool shouldRepaint(DiaryColorHuePainter oldDelegate) =>
      oldDelegate.hue != hue ||
      oldDelegate.thumbRadius != thumbRadius ||
      oldDelegate.outline != outline;
}

/// 竖向不透明度条：上为不透明、下为全透明，底下铺棋盘格看出透明度。
class DiaryColorAlphaPainter extends CustomPainter {
  const DiaryColorAlphaPainter({
    required this.color,
    required this.thumbRadius,
    required this.outline,
    required this.checkerLight,
    required this.checkerDark,
  });

  /// 带当前透明度的颜色；条本身按它的 RGB 从不透明画到透明。
  final Color color;
  final double thumbRadius;
  final Color outline;
  final Color checkerLight;
  final Color checkerDark;

  static const double _cell = 7;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(
      bounds,
      Radius.circular(size.width / 2),
    );
    final travel = diaryColorThumbTravel(size);
    final opaque = color.withAlpha(0xFF);
    canvas
      ..save()
      ..clipRRect(shape)
      ..drawRect(bounds, Paint()..color = checkerLight);
    final dark = Paint()..color = checkerDark;
    for (var row = 0; row * _cell < size.height; row++) {
      for (var column = row.isEven ? 0 : 1; column * _cell < size.width;) {
        canvas.drawRect(
          Rect.fromLTWH(column * _cell, row * _cell, _cell, _cell),
          dark,
        );
        column += 2;
      }
    }
    canvas
      ..drawRect(
        bounds,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[opaque, opaque.withAlpha(0)],
          ).createShader(travel),
      )
      ..restore()
      ..drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = outline,
      );
    paintDiaryColorThumb(
      canvas,
      Offset(size.width / 2, travel.top + (1 - color.a) * travel.height),
      thumbRadius,
      color,
    );
  }

  @override
  bool shouldRepaint(DiaryColorAlphaPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.thumbRadius != thumbRadius ||
      oldDelegate.outline != outline ||
      oldDelegate.checkerLight != checkerLight ||
      oldDelegate.checkerDark != checkerDark;
}
