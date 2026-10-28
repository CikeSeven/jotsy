import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import 'fast_scroller_geometry.dart';
import 'fast_scroller_parts.dart';

/// 快速滚动条叠在列表上的部分：按钮、气泡、轨道线与分段刻度的摆放，以及
/// 按钮与桌面轨道区的手势入口。
///
/// 输入：显隐进度 [visibility]、按钮位置 [thumbFraction]（0–1）、气泡进度
/// 与标签、分段与总项数、按住 / 悬停状态；输出：经各回调交给
/// `FastScroller`。不持有状态，状态与换算都在 `FastScroller`。
///
/// 命中测试：只有按钮的按压区域（显示时）与桌面轨道区挡住下面的列表，其余
/// 部件一律不接收指针；隐藏时整层不接收触摸。
class FastScrollerOverlay extends StatelessWidget {
  const FastScrollerOverlay({
    super.key,
    required this.visibility,
    required this.thumbFraction,
    required this.bubbleOpacity,
    required this.bubbleScale,
    required this.label,
    required this.sections,
    required this.itemCount,
    required this.grabbed,
    required this.hovered,
    required this.desktop,
    required this.touchSlop,
    required this.onGrab,
    required this.onDrag,
    required this.onRelease,
    required this.onTrackTap,
    required this.onPointerSignal,
    required this.onStripHover,
    required this.onThumbHover,
  });

  final Animation<double> visibility;
  final ValueListenable<double> thumbFraction;

  /// 气泡的透明度与缩放（由 `FastScroller` 创建一次，见那里的曲线）。
  final Animation<double> bubbleOpacity;
  final Animation<double> bubbleScale;

  /// 气泡里的标签；没按住时可为 null（气泡淡出期间沿用最后一个）。
  final FastScrollLabel? label;
  final List<FastScrollSection> sections;
  final int itemCount;
  final bool grabbed;
  final bool hovered;
  final bool desktop;
  final double touchSlop;
  final GestureDragDownCallback onGrab;
  final GestureDragUpdateCallback onDrag;
  final VoidCallback onRelease;
  final GestureTapUpCallback onTrackTap;
  final ValueChanged<PointerSignalEvent> onPointerSignal;
  final ValueChanged<bool> onStripHover;
  final ValueChanged<bool> onThumbHover;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final travel = constraints.maxHeight - FastScrollMetrics.slot;
        if (travel <= 0 || itemCount <= 0) {
          return const SizedBox.shrink();
        }
        return AnimatedBuilder(
          animation: visibility,
          builder: (BuildContext context, Widget? _) {
            final visible = visibility.value;
            final interactive = visible > 0.5 || grabbed;
            return Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                if (desktop) _buildDesktopStrip(interactive),
                if (visible > 0)
                  IgnorePointer(
                    ignoring: !interactive,
                    child: FadeTransition(
                      opacity: visibility,
                      child: Transform.translate(
                        offset: Offset((1 - visible) * 12, 0),
                        child: _buildScroller(context, travel),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// 桌面右缘的轨道区：悬停唤出滚动条（translucent，不挡下面的列表）；
  /// 滚动条显示时点按跳转，滚轮转交给列表。
  Widget _buildDesktopStrip(bool interactive) {
    return Positioned(
      top: 0,
      bottom: 0,
      right: 0,
      width: FastScrollMetrics.hitWidth / 2,
      child: MouseRegion(
        opaque: false,
        hitTestBehavior: HitTestBehavior.translucent,
        onEnter: (_) => onStripHover(true),
        onExit: (_) => onStripHover(false),
        child: interactive
            ? Listener(
                onPointerSignal: onPointerSignal,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: onTrackTap,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildScroller(BuildContext context, double travel) {
    final engaged = grabbed || hovered;
    return ValueListenableBuilder<double>(
      valueListenable: thumbFraction,
      builder: (BuildContext context, double fraction, Widget? _) {
        final thumbTop = fraction * travel;
        final thumbCenter = thumbTop + FastScrollMetrics.slot / 2;
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              top: FastScrollMetrics.slot / 2,
              bottom: FastScrollMetrics.slot / 2,
              right: FastScrollMetrics.axis - FastScrollTrackLine.width / 2,
              child: _EngagedFade(
                engaged: engaged,
                child: const FastScrollTrackLine(),
              ),
            ),
            ..._buildMarkers(travel, thumbCenter, engaged),
            Positioned(
              top: thumbCenter,
              right: FastScrollMetrics.labelInset,
              child: FractionalTranslation(
                translation: const Offset(0, -0.5),
                child: _buildBubble(),
              ),
            ),
            Positioned(
              top: thumbTop,
              right: FastScrollMetrics.edge,
              width: FastScrollMetrics.grabbedWidth,
              height: FastScrollMetrics.slot,
              child: Align(
                alignment: Alignment.centerRight,
                child: FastScrollThumb(grabbed: grabbed, hovered: hovered),
              ),
            ),
            Positioned(
              top: thumbTop - FastScrollMetrics.hitPadding,
              right: 0,
              width: FastScrollMetrics.hitWidth,
              height: FastScrollMetrics.slot + FastScrollMetrics.hitPadding * 2,
              child: _buildThumbHitArea(context),
            ),
          ],
        );
      },
    );
  }

  /// 按钮的按压区域：拖动阈值收到 [touchSlop]，按下即跟手。
  Widget _buildThumbHitArea(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(gestureSettings: DeviceGestureSettings(touchSlop: touchSlop)),
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        onEnter: (_) => onThumbHover(true),
        onExit: (_) => onThumbHover(false),
        child: Listener(
          onPointerSignal: desktop ? onPointerSignal : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragDown: onGrab,
            onVerticalDragUpdate: onDrag,
            onVerticalDragEnd: (_) => onRelease(),
            onVerticalDragCancel: onRelease,
          ),
        ),
      ),
    );
  }

  /// 分段刻度：按住或悬停时淡入；离得太近的省略后者，气泡附近的让开。
  List<Widget> _buildMarkers(double travel, double thumbCenter, bool engaged) {
    if (sections.length < 2) {
      return const <Widget>[];
    }
    final markers = <Widget>[];
    var lastY = double.negativeInfinity;
    for (final section in sections) {
      final y = section.index / itemCount * travel + FastScrollMetrics.slot / 2;
      if (y - lastY < FastScrollMetrics.markerSpacing) {
        continue;
      }
      lastY = y;
      // 气泡上下各约 30dp 内的刻度标签淡出，免得与气泡叠在一起。
      final clearance = grabbed
          ? (((y - thumbCenter).abs() - 30) / 20).clamp(0.0, 1.0)
          : 1.0;
      markers
        ..add(
          Positioned(
            top: y - FastScrollMarkerDot.size / 2,
            right: FastScrollMetrics.axis - FastScrollMarkerDot.size / 2,
            child: _EngagedFade(
              engaged: engaged,
              child: const FastScrollMarkerDot(),
            ),
          ),
        )
        ..add(
          Positioned(
            top: y,
            right: FastScrollMetrics.markerInset,
            child: FractionalTranslation(
              translation: const Offset(0, -0.5),
              child: _EngagedFade(
                engaged: engaged,
                child: Opacity(
                  opacity: clearance,
                  child: FastScrollMarkerLabel(text: section.label),
                ),
              ),
            ),
          ),
        );
    }
    return markers;
  }

  Widget _buildBubble() {
    final current = label;
    return AnimatedBuilder(
      animation: bubbleOpacity,
      builder: (BuildContext context, Widget? _) {
        if (bubbleOpacity.isDismissed || current == null) {
          return const SizedBox.shrink();
        }
        return IgnorePointer(
          child: FadeTransition(
            opacity: bubbleOpacity,
            child: ScaleTransition(
              scale: bubbleScale,
              alignment: Alignment.centerRight,
              child: FastScrollBubble(label: current),
            ),
          ),
        );
      },
    );
  }
}

/// 按住或悬停时才显示的部件（轨道线、刻度）：`fast` 淡入淡出，不接收指针。
class _EngagedFade extends StatelessWidget {
  const _EngagedFade({required this.engaged, required this.child});

  final bool engaged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: engaged ? 1 : 0,
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
        curve: engaged ? ExpressiveMotion.effects : ExpressiveMotion.exit,
        child: child,
      ),
    );
  }
}
