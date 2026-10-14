import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../l10n/app_localizations.dart';

/// Clear-only feedback; filter mutations stay with the parent callback. A
/// cancelled ticker during lazy row removal is normal and never updates a
/// disposed widget or leaves an asynchronous animation waiting forever.
class TagFilterClearButton extends StatefulWidget {
  const TagFilterClearButton({
    super.key,
    required this.hasSelection,
    required this.onClear,
  });

  final bool hasSelection;
  final VoidCallback onClear;

  @override
  State<TagFilterClearButton> createState() => _TagFilterClearButtonState();
}

class _TagFilterClearButtonState extends State<TagFilterClearButton>
    with SingleTickerProviderStateMixin {
  static const double _halfTurn = 3.1415926535897932;
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _rotation;
  double _baseAngle = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _scale = TweenSequence<double>(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1,
          end: 0.78,
        ).chain(CurveTween(curve: const Cubic(0.2, 0.0, 0.0, 1.0))),
        weight: 32,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0.78,
          end: 1.06,
        ).chain(CurveTween(curve: const Cubic(0.16, 1, 0.3, 1))),
        weight: 44,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.06,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 24,
      ),
    ]).animate(_controller);
    _rotation = Tween<double>(begin: 0, end: _halfTurn)
        .chain(CurveTween(curve: const Cubic(0.2, 0.0, 0.0, 1.0)))
        .animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 按下时的即时反馈：图标先轻微缩小，松手后再播放清除动画。
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (_pressed != pressed && widget.hasSelection) {
      setState(() => _pressed = pressed);
    }
  }

  Future<void> _clear() async {
    // 没有选中的标签时点按什么都不会发生：不再白转一圈给出误导性的反馈。
    if (_controller.isAnimating || !widget.hasSelection) {
      return;
    }
    widget.onClear();
    _controller.duration = ExpressiveMotion.duration(context);
    try {
      await _controller.forward(from: 0).orCancel;
      if (mounted) {
        setState(() => _baseAngle += _halfTurn);
      }
    } on TickerCanceled {
      // The clear row can leave the lazy viewport while feedback is playing.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.rotate(
        angle: _baseAngle + _rotation.value,
        child: Transform.scale(scale: _scale.value, child: child),
      ),
      // 宽度受标签栏布局（TagFilterLayout 固定 26dp）约束，至少补齐读屏语义。
      child: Semantics(
        button: true,
        label: context.l10n.tagFilterClearLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _setPressed(true),
          onTapUp: (_) => _setPressed(false),
          onTapCancel: () => _setPressed(false),
          onTap: () => unawaited(_clear()),
          child: SizedBox(
            width: 26,
            height: 32,
            child: Center(
              child: AnimatedScale(
                scale: _pressed ? 0.8 : 1,
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.fast,
                ),
                curve: ExpressiveMotion.spatial,
                child: FaIcon(
                  FontAwesomeIcons.xmark,
                  size: 16,
                  color: widget.hasSelection
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
