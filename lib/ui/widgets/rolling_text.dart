import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// 逐位滚动的短文字（计数角标等）：从 [from] 变到 [to] 时，只有变了的那几位
/// 上下滚动——旧字符滑出、新字符从另一侧滑入，没变的位原地不动；位数变化
/// 时那一位的宽度随进度插值，外面的胶囊跟着平滑变宽 / 变窄。
///
/// 输入：起止文字（按右端对齐，数字从个位起对齐）、进度 [progress]
/// （0 = 起点，1 = 终点；可略超出 1，弹簧的过冲表现为新字符稍微越过再落回）
/// 与方向 [upward]（true：新字符从下面上来，用于变大）。[from] 为 null 时
/// 就是静止的一段 [to]，只有一个 [Text]，与普通文字无异。
///
/// 只负责一帧的画面，进度由调用方驱动；纵向超出一行的部分被裁掉。
class RollingText extends StatelessWidget {
  const RollingText({
    super.key,
    required this.from,
    required this.to,
    required this.progress,
    required this.style,
    this.upward = true,
  });

  final String? from;
  final String to;
  final double progress;
  final bool upward;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final from = this.from;
    if (from == null || from == to) {
      return Text(to, style: style, maxLines: 1, softWrap: false);
    }
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double widthOf(String text) {
      if (text.isEmpty) return 0;
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final probe = TextPainter(
      text: TextSpan(text: '0', style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final lineHeight = probe.height;
    probe.dispose();

    final oldChars = from.characters.toList();
    final newChars = to.characters.toList();
    final length = oldChars.length > newChars.length
        ? oldChars.length
        : newChars.length;
    String at(List<String> chars, int index) {
      final shift = length - chars.length;
      return index < shift ? '' : chars[index - shift];
    }

    final t = progress;
    final widthT = t.clamp(0.0, 1.0);
    final sign = upward ? 1.0 : -1.0;
    final slots = <Widget>[];
    for (var index = 0; index < length; index++) {
      final oldChar = at(oldChars, index);
      final newChar = at(newChars, index);
      if (oldChar == newChar) {
        slots.add(Text(newChar, style: style, maxLines: 1, softWrap: false));
        continue;
      }
      Widget glyph(String char, double dy) => Positioned(
        left: 0,
        right: 0,
        top: dy,
        height: lineHeight,
        child: OverflowBox(
          minWidth: 0,
          maxWidth: double.infinity,
          child: Text(char, style: style, maxLines: 1, softWrap: false),
        ),
      );
      slots.add(
        SizedBox(
          width: lerpDouble(widthOf(oldChar), widthOf(newChar), widthT),
          height: lineHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              if (oldChar.isNotEmpty) glyph(oldChar, -sign * t * lineHeight),
              if (newChar.isNotEmpty)
                glyph(newChar, sign * (1 - t) * lineHeight),
            ],
          ),
        ),
      );
    }
    return ClipRect(
      child: SizedBox(
        height: lineHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: TextDirection.ltr,
          children: slots,
        ),
      ),
    );
  }
}
