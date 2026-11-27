import 'package:flutter/material.dart';

/// 待办行的文字列：标题（最多两行）、备注首行与一排元信息胶囊。
///
/// 删除线不用 `TextDecoration`：它只能整行同时出现。这里按标题实际排出的
/// 每一行（`TextPainter.computeLineMetrics`）从起笔一侧划到另一侧，[strike]
/// 为 0~1 的总进度，按各行宽度依次分给每一行——第一行划完才轮到第二行；
/// RTL 时从右往左。已完成的行 [strike] 恒为 1，与动效最后一帧逐像素一致。
class TodoTileText extends StatelessWidget {
  const TodoTileText({
    super.key,
    required this.title,
    required this.note,
    required this.meta,
    required this.titleStyle,
    required this.strike,
    required this.strikeColor,
    this.below,
  });

  final String title;
  final String? note;
  final List<Widget> meta;
  final TextStyle? titleStyle;

  /// 删除线的进度（0~1）。
  final double strike;
  final Color strikeColor;

  /// 胶囊下面的内容（就地展开的步骤）。
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = this.note;
    final below = this.below;
    final style = DefaultTextStyle.of(context).style.merge(titleStyle);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // 撑满列宽：画删除线时按与标题相同的宽度排版，断行与标题一致。
        SizedBox(
          width: double.infinity,
          child: CustomPaint(
            foregroundPainter: strike <= 0
                ? null
                : TodoStrikePainter(
                    text: title,
                    style: style,
                    maxLines: 2,
                    textDirection: Directionality.of(context),
                    textScaler: MediaQuery.textScalerOf(context),
                    progress: strike,
                    color: strikeColor,
                  ),
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ),
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (meta.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 6, runSpacing: 4, children: meta),
          ),
        ?below,
      ],
    );
  }
}

/// 按行划出的删除线（见 [TodoTileText]）。线宽与位置按字号：线宽约 1/14 字号
/// （最细 1.2），落在基线上方约三分之一字号处，中英文的字面中部都能压住。
class TodoStrikePainter extends CustomPainter {
  TodoStrikePainter({
    required this.text,
    required this.style,
    required this.maxLines,
    required this.textDirection,
    required this.textScaler,
    required this.progress,
    required this.color,
  });

  final String text;
  final TextStyle style;
  final int maxLines;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final double progress;
  final Color color;

  /// 排版结果按（文字、样式、宽度、方向、缩放）缓存：动效逐帧换一个画笔
  /// 但只改进度，不必每帧重新排版；已完成组里各行各占一条。超出上限时丢掉
  /// 最早的。
  static final Map<_StrikeKey, List<LineMetrics>> _cache =
      <_StrikeKey, List<LineMetrics>>{};
  static const int _cacheLimit = 64;

  @override
  void paint(Canvas canvas, Size size) {
    final lines = _lines(size.width);
    final total = lines.fold<double>(
      0,
      (double sum, LineMetrics line) => sum + line.width,
    );
    if (total <= 0) return;
    final fontSize = textScaler.scale(style.fontSize ?? 14);
    final paint = Paint()
      ..color = color
      ..strokeWidth = (fontSize / 14).clamp(1.2, 3.0)
      ..strokeCap = StrokeCap.round;
    var remaining = total * progress.clamp(0.0, 1.0);
    for (final line in lines) {
      if (remaining <= 0) break;
      final length = remaining < line.width ? remaining : line.width;
      remaining -= length;
      final y = line.baseline - fontSize * 0.32;
      final start = textDirection == TextDirection.ltr
          ? line.left
          : line.left + line.width;
      final end = textDirection == TextDirection.ltr
          ? start + length
          : start - length;
      canvas.drawLine(Offset(start, y), Offset(end, y), paint);
    }
  }

  List<LineMetrics> _lines(double width) {
    final key = (text, style, width, textDirection, textScaler, maxLines);
    final cached = _cache.remove(key);
    if (cached != null) return _cache[key] = cached;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      ellipsis: '\u2026',
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: width);
    final lines = painter.computeLineMetrics();
    painter.dispose();
    if (_cache.length >= _cacheLimit) _cache.remove(_cache.keys.first);
    return _cache[key] = lines;
  }

  @override
  bool shouldRepaint(TodoStrikePainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.text != text ||
      old.style != style ||
      old.textDirection != textDirection ||
      old.textScaler != textScaler;
}

typedef _StrikeKey = (
  String,
  TextStyle,
  double,
  TextDirection,
  TextScaler,
  int,
);
