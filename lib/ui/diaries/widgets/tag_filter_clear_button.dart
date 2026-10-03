import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';

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

  Future<void> _clear() async {
    if (_controller.isAnimating) {
      return;
    }
    widget.onClear();
    _controller.duration = ExpressiveMotion.duration(
      context,
      const Duration(milliseconds: 340),
    );
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => unawaited(_clear()),
        child: SizedBox(
          width: 26,
          height: 32,
          child: Center(
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
    );
  }
}
