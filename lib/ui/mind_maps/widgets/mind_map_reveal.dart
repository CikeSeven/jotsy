import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';

/// 画布从一个按钮处展开：新建页点“思维导图”后，工作区从按钮的矩形长成
/// 整块（裁切出的那块从容器色过渡成页面底色，都不透明，不做透底淡入），时长与曲线同卡片展开
/// （`containerOpen` / `containerSpring`）。子树一开始就按整块布局，只是被
/// 裁切，画布第一帧就摆好位置。[origin] 为 null 或减少动态效果时直接显示。
class MindMapReveal extends StatefulWidget {
  const MindMapReveal({super.key, required this.origin, required this.child});

  /// 起点的全局矩形。
  final Rect? origin;
  final Widget child;

  @override
  State<MindMapReveal> createState() => _MindMapRevealState();
}

class _MindMapRevealState extends State<MindMapReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: ExpressiveMotion.containerOpen,
    value: widget.origin == null ? 1 : 0,
  );
  Rect? _local;

  @override
  void initState() {
    super.initState();
    if (widget.origin == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ExpressiveMotion.reduceMotion(context)) {
        _progress.value = 1;
        return;
      }
      final box = context.findRenderObject();
      final origin = widget.origin;
      if (box is RenderBox && box.hasSize && origin != null) {
        _local = Rect.fromPoints(
          box.globalToLocal(origin.topLeft),
          box.globalToLocal(origin.bottomRight),
        );
      }
      _progress.forward();
    });
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final page = AppPageBackdrop.pageColorOf(context);
    // 展开中的那块是略深的容器色，长满时过渡成页面底色：两端都不透明，
    // 看得出画布从按钮里长出来，又不露出下面的东西。
    final surface = Color.alphaBlend(
      Theme.of(context).colorScheme.surfaceContainerHigh,
      page,
    );
    return AnimatedBuilder(
      animation: _progress,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        if (_progress.value >= 1) return child!;
        final t = ExpressiveMotion.containerSpring.transform(_progress.value);
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final full = Offset.zero & constraints.biggest;
            final start =
                _local ??
                Rect.fromCenter(center: full.center, width: 0, height: 0);
            final rect = Rect.lerp(start, full, t)!;
            final radius = 18 * (1 - t);
            return ClipRRect(
              clipper: _RectClipper(rect, radius),
              child: ColoredBox(
                color: Color.lerp(surface, page, t)!,
                child: child,
              ),
            );
          },
        );
      },
    );
  }
}

class _RectClipper extends CustomClipper<RRect> {
  const _RectClipper(this.rect, this.radius);

  final Rect rect;
  final double radius;

  @override
  RRect getClip(Size size) =>
      RRect.fromRectAndRadius(rect, Radius.circular(radius));

  @override
  bool shouldReclip(_RectClipper oldClipper) =>
      oldClipper.rect != rect || oldClipper.radius != radius;
}
