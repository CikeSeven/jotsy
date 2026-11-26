import 'package:flutter/widgets.dart';

import '../../app/theme/expressive_motion.dart';
import 'rolling_text.dart';

/// 计数变化时逐位滚动（[RollingText] 的有状态版本，自带弹簧进度）。
///
/// 两种用法：
/// - [AnimatedRollingText.new]：整段文字就是计数（“12”“3/5”），整段按位
///   滚动；
/// - [AnimatedRollingText.sentence]：计数嵌在一句本地化文字里（“还有 3 件”
///   “3 overdue”），只滚句中的数字 [number]，前后的文字照常排版与换行；
///   前后两句有一句没有数字（[number] 为 null）、或句中找不到 / 不止一处
///   这个数字时整句直接换，不会把整句当成一串字符去滚。
///
/// 静止时就是一个普通 [Text]（与直接写 Text 逐像素一致，测试按文字查找
/// 照常可用）；滚动途中读屏只念最终的文字。方向：数字变大时新数字从下面
/// 上来，变小时从上面下来（整段计数按其中的第一个整数比较）。减少动态
/// 效果时直接换字。
class AnimatedRollingText extends StatefulWidget {
  const AnimatedRollingText(this.text, {super.key, this.style})
    : number = null,
      maxLines = null,
      overflow = null,
      _sentence = false;

  const AnimatedRollingText.sentence(
    this.text, {
    super.key,
    required this.number,
    this.style,
    this.maxLines,
    this.overflow,
  }) : _sentence = true;

  final String text;

  /// 句中要滚动的数字（[AnimatedRollingText.sentence]）；null 时这句没有
  /// 可滚的数字。
  final int? number;
  final bool _sentence;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<AnimatedRollingText> createState() => _AnimatedRollingTextState();
}

class _AnimatedRollingTextState extends State<AnimatedRollingText>
    with SingleTickerProviderStateMixin {
  /// 进度是 0–1 的比例，按像素量级的默认容差太粗。
  static const Tolerance _tolerance = Tolerance(distance: 1e-3, velocity: 1e-2);

  static final RegExp _firstInt = RegExp(r'\d+');

  late final AnimationController _roll = AnimationController.unbounded(
    vsync: this,
    value: 1,
  )..addStatusListener(_handleStatus);

  /// 滚动途中的起点（整段文字，或句中数字那几位）；静止时为 null。
  String? _from;
  bool _upward = true;

  @override
  void didUpdateWidget(covariant AnimatedRollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text == widget.text) return;
    final from = _rollingPart(oldWidget);
    final to = _rollingPart(widget);
    if (ExpressiveMotion.reduceMotion(context) ||
        from == null ||
        to == null ||
        from == to) {
      _from = null;
      _roll.value = 1;
      return;
    }
    _from = from;
    final before = oldWidget.number ?? _intIn(oldWidget.text);
    final after = widget.number ?? _intIn(widget.text);
    _upward = before == null || after == null || after >= before;
    _roll.value = 0;
    ExpressiveMotion.springTo(
      context,
      _roll,
      1,
      spring: ExpressiveMotion.springSpatial,
      tolerance: _tolerance,
    );
  }

  /// 要滚动的那一段：整段文字，或句中唯一出现的那个数字。
  static String? _rollingPart(AnimatedRollingText widget) {
    if (!widget._sentence) return widget.text;
    final number = widget.number;
    if (number == null) return null;
    final digits = '$number';
    final at = widget.text.indexOf(digits);
    if (at < 0 || widget.text.indexOf(digits, at + 1) >= 0) return null;
    return digits;
  }

  static int? _intIn(String text) {
    final match = _firstInt.firstMatch(text);
    return match == null ? null : int.tryParse(match.group(0)!);
  }

  void _handleStatus(AnimationStatus status) {
    // 起步前把进度设回 0 也会触发这里：只在停在终点时收尾。
    if (!_roll.isAnimating && _roll.value == 1 && _from != null && mounted) {
      setState(() => _from = null);
    }
  }

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final from = _from;
    if (from == null) {
      return Text(
        widget.text,
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
    }
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    Widget rolling(String to) => AnimatedBuilder(
      animation: _roll,
      builder: (BuildContext context, Widget? _) => RollingText(
        from: from,
        to: to,
        progress: _roll.value,
        upward: _upward,
        style: style,
      ),
    );
    if (!widget._sentence) {
      return Semantics(
        label: widget.text,
        excludeSemantics: true,
        child: rolling(widget.text),
      );
    }
    // 句中数字：前后文字照常排版，数字那几位占一个行内块。
    final digits = '${widget.number}';
    final at = widget.text.indexOf(digits);
    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            if (at > 0) TextSpan(text: widget.text.substring(0, at)),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: rolling(digits),
            ),
            if (at + digits.length < widget.text.length)
              TextSpan(text: widget.text.substring(at + digits.length)),
          ],
        ),
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      ),
    );
  }
}
