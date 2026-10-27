import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../app_surface/widgets/app_glass_fab.dart';
import '../../../app_surface/widgets/app_glass_scope.dart';
import '../../../widgets/glass/glass_reveal.dart';
import '../../../../l10n/app_localizations.dart';

/// 页面顶端的阅读进度细线：宽度 = 已滚动 / 可滚动总长（不可滚动时为满）。
///
/// 只监听滚动控制器重绘这一条线，正文不随滚动重建。
class DiaryPreviewProgressLine extends StatelessWidget {
  const DiaryPreviewProgressLine({super.key, required this.controller});

  static const double thickness = 2.5;

  final ScrollController controller;

  double _progress() {
    // 只读唯一的那个滚动位置；换页等过渡里短暂挂着两个时先不更新。
    if (controller.positions.length != 1) {
      return 0;
    }
    final position = controller.position;
    if (!position.hasContentDimensions) {
      return 0;
    }
    final max = position.maxScrollExtent;
    if (max <= 0) {
      return 1;
    }
    return (position.pixels / max).clamp(0.0, 1.0).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return IgnorePointer(
      child: SizedBox(
        height: thickness,
        child: ListenableBuilder(
          listenable: controller,
          builder: (BuildContext context, Widget? child) =>
              FractionallySizedBox(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: _progress(),
                child: child,
              ),
          child: ColoredBox(color: color),
        ),
      ),
    );
  }
}

/// “回到顶部”按钮：滚过 1.5 屏后出现（`fast` 缩放 + 淡入），点按以
/// `standard` + `spatial` 滚回顶部，减少动画时直接跳回。
class DiaryPreviewBackToTop extends StatefulWidget {
  const DiaryPreviewBackToTop({super.key, required this.controller});

  /// 滚过几屏后出现。
  static const double revealScreens = 1.5;

  final ScrollController controller;

  @override
  State<DiaryPreviewBackToTop> createState() => _DiaryPreviewBackToTopState();
}

class _DiaryPreviewBackToTopState extends State<DiaryPreviewBackToTop> {
  final ValueNotifier<bool> _visible = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
  }

  @override
  void didUpdateWidget(DiaryPreviewBackToTop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_sync);
      widget.controller.addListener(_sync);
      _sync();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _visible.dispose();
    super.dispose();
  }

  /// 只在跨过阈值时通知，滚动途中不逐帧重建按钮。
  void _sync() {
    final controller = widget.controller;
    if (controller.positions.length != 1) {
      return;
    }
    final position = controller.position;
    _visible.value =
        position.pixels >
        position.viewportDimension * DiaryPreviewBackToTop.revealScreens;
  }

  void _scrollToTop() {
    final controller = widget.controller;
    if (controller.positions.length != 1) {
      return;
    }
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.standard,
    );
    if (duration == Duration.zero) {
      controller.jumpTo(0);
      return;
    }
    controller.animateTo(
      0,
      duration: duration,
      curve: ExpressiveMotion.spatial,
    );
  }

  @override
  Widget build(BuildContext context) {
    final duration = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
    final glass = AppGlass.of(context).isGlass(AppGlassComponent.controls);
    final button = FloatingActionButton.small(
      // 翻页器里每一页都有自己的按钮：不参与共享元素，避免同一路由里
      // 出现重复的 FAB Hero 标签。
      heroTag: null,
      tooltip: context.l10n.diaryPreviewBackToTop,
      onPressed: _scrollToTop,
      child: const FaIcon(FontAwesomeIcons.arrowUp, size: 16),
    );
    return ValueListenableBuilder<bool>(
      valueListenable: _visible,
      builder: (BuildContext context, bool visible, Widget? child) {
        final curve = visible
            ? ExpressiveMotion.effects
            : ExpressiveMotion.exit;
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedScale(
            scale: visible ? 1 : 0.6,
            duration: duration,
            curve: ExpressiveMotion.spatial,
            // 玻璃按钮不能放进透明度层（模糊会采不到正文），显隐改由
            // GlassReveal 按同样的时长与曲线补间进度，玻璃表面自己淡入。
            child: glass
                ? TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: visible ? 1 : 0),
                    duration: duration,
                    curve: curve,
                    builder:
                        (BuildContext context, double value, Widget? child) =>
                            GlassReveal(progress: value, child: child!),
                    child: child,
                  )
                : AnimatedOpacity(
                    opacity: visible ? 1 : 0,
                    duration: duration,
                    curve: curve,
                    child: child,
                  ),
          ),
        );
      },
      child: glass ? _glassButton(button) : button,
    );
  }

  /// 主色玻璃的小号按钮，浮在正文上，总是模糊。
  ///
  /// [AppGlassFab] 把按钮的点按区收成 40dp（否则玻璃会被补成 48dp、比看得见
  /// 的按钮大一圈），这里在外面补回 4dp 的点按边：占位与经典按钮的 48dp
  /// 相同、位置不变，点在边上同样回到顶部（不重复读屏，语义仍是按钮本身）。
  Widget _glassButton(Widget button) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: _scrollToTop,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: AppGlassFab(child: button),
      ),
    );
  }
}
