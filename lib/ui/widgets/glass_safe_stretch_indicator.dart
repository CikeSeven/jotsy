// 拉伸越界效果的逻辑改编自 Flutter SDK：
//   packages/flutter/lib/src/widgets/overscroll_indicator.dart
//   （StretchingOverscrollIndicator / _StretchController）
//   packages/flutter/lib/src/widgets/stretch_effect.dart（StretchEffect 的
//   Transform 回退路径）
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file (https://github.com/flutter/flutter/blob/master/LICENSE).
//
// 改动原因：Impeller 上 SDK 的 StretchEffect 用 `ImageFiltered(ImageFilter
// .shader)` 实现拉伸，整块滚动内容被放进离屏图层；图层里的 BackdropFilter
// 只能采到图层自己（页面背景不在里面），玻璃卡片 / 玻璃顶栏在拉伸期间
// 失去背景模糊、突然变得更透明。SDK 不支持着色器时的 Transform 回退又带
// `filterQuality`，同样会推出 ImageFilterLayer（离屏）。这里保留 SDK 的通知
// 处理与拉伸控制器（弹簧参数、回弹手感逐行照搬），只把“怎么画”换成可切换：
// 默认仍交给 SDK 的 StretchEffect（像素与动画与原生拉伸完全相同），需要时
// 改用不带 filterQuality 的纯 Transform——只推 TransformLayer，不产生离屏图层，
// 玻璃照常模糊。

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

/// 判断当前滚动视图是否需要“不产生离屏图层”的拉伸。
///
/// 在本组件自己的 context 上调用（位于 Scrollable 之下），可以读继承数据；
/// 依赖只登记在本组件上，继承数据变化时只重建这一层，不牵动 Scrollable。
typedef GlassSafeStretchPredicate = bool Function(BuildContext context);

/// Android 拉伸越界效果，可在“原生着色器拉伸”与“不产生离屏图层的缩放
/// 拉伸”之间切换。
///
/// 输入：[axisDirection]、[clipBehavior] 与 [avoidOffscreenLayer] 判定；
/// 输出：随越界量拉伸的 [child]；副作用：派发
/// [OverscrollIndicatorNotification]（与 SDK 相同，`disallowIndicator` 照样
/// 生效）。不改滚动 physics，也不吞掉任何滚动通知（处理函数始终返回 false），
/// 预览页翻页与首页“滚动时隐藏底栏”照常收到越界通知。
///
/// 两种画法的树结构相同（ClipRect → Transform → StretchEffect → child）：
/// - 默认：Transform 为单位矩阵（RenderTransform 直接按偏移绘制，不推任何
///   图层），越界量交给 SDK 的 [StretchEffect]，与 SDK 的
///   StretchingOverscrollIndicator 逐像素一致；
/// - 避开离屏图层：StretchEffect 收到 0（其 ImageFiltered 关闭、不画角点），
///   由外层 Transform 沿滚动轴按 `1 + |越界量|` 缩放、从被拉的一端对齐——
///   与 SDK 不支持着色器时的回退相同，只是不设 filterQuality。
///
/// 结构相同是刻意的：判定会随页面背景图解码完成、导航栏样式切换而变化，
/// 若两种画法换用不同的组件类型，切换那一刻整块滚动内容（视口与所有列表项）
/// 都会被卸载重建，状态与入场动画全部丢失。
class GlassSafeStretchingOverscrollIndicator extends StatefulWidget {
  const GlassSafeStretchingOverscrollIndicator({
    super.key,
    required this.axisDirection,
    required this.avoidOffscreenLayer,
    this.notificationPredicate = defaultScrollNotificationPredicate,
    this.clipBehavior = Clip.hardEdge,
    this.child,
  });

  final AxisDirection axisDirection;

  Axis get axis => axisDirectionToAxis(axisDirection);

  /// 为 true 时改用不产生离屏图层的缩放拉伸。
  final GlassSafeStretchPredicate avoidOffscreenLayer;

  final ScrollNotificationPredicate notificationPredicate;

  final Clip clipBehavior;

  final Widget? child;

  @override
  State<GlassSafeStretchingOverscrollIndicator> createState() =>
      _GlassSafeStretchingOverscrollIndicatorState();
}

class _GlassSafeStretchingOverscrollIndicatorState
    extends State<GlassSafeStretchingOverscrollIndicator>
    with TickerProviderStateMixin {
  late final _StretchController _stretchController = _StretchController(
    vsync: this,
  );
  ScrollNotification? _lastNotification;
  OverscrollNotification? _lastOverscrollNotification;

  double _totalOverscroll = 0.0;

  bool _accepted = true;

  // 以下通知处理逐行照搬 SDK（含 `runtimeType is!` 这一 SDK 原样的判断），
  // 保证拉动、甩到边缘与松手回弹的触发时机与原生拉伸一致。
  bool _handleScrollNotification(ScrollNotification notification) {
    if (!widget.notificationPredicate(notification)) {
      return false;
    }
    if (notification.metrics.axis != widget.axis) {
      return false;
    }
    if (notification is ScrollStartNotification) {
      _accepted = true;
      _totalOverscroll = 0.0;
    } else if (notification is OverscrollNotification) {
      _lastOverscrollNotification = notification;
      if (_lastNotification.runtimeType is! OverscrollNotification) {
        final confirmationNotification = OverscrollIndicatorNotification(
          leading: notification.overscroll < 0.0,
        );
        confirmationNotification.dispatch(context);
        // accepted 在 SDK 里标为 protected / visibleForTesting，只有同文件的
        // 指示器能读；这里是那个指示器的拷贝，必须读它才能让祖先的
        // disallowIndicator() 照样关掉拉伸。
        // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
        _accepted = confirmationNotification.accepted;
      }

      if (_accepted) {
        _totalOverscroll += notification.overscroll;

        if (notification.velocity != 0.0) {
          assert(notification.dragDetails == null);
          _stretchController.absorbImpact(notification.velocity);
        } else {
          assert(notification.overscroll != 0.0);
          if (notification.dragDetails != null) {
            // 按视口长度归一化并夹在 ±1：多指同时拉会叠加越界量
            // （flutter/flutter#11884）。
            final double viewportDimension =
                notification.metrics.viewportDimension;
            final double distanceForPull = _totalOverscroll / viewportDimension;
            final double clampedOverscroll = clampDouble(
              distanceForPull,
              -1.0,
              1.0,
            );
            _stretchController.pull(clampedOverscroll);
          }
        }
      }
    } else if (notification is ScrollEndNotification) {
      double velocity = switch (widget.axis) {
        Axis.vertical =>
          notification.dragDetails?.velocity.pixelsPerSecond.dy ?? 0.0,
        Axis.horizontal =>
          notification.dragDetails?.velocity.pixelsPerSecond.dx ?? 0.0,
      };

      // 反向轴的 dragDetails 速度按屏幕坐标给出，需要取反。
      if (notification.metrics.axisDirection == AxisDirection.left ||
          notification.metrics.axisDirection == AxisDirection.up) {
        velocity = -velocity;
      }

      _totalOverscroll = 0.0;
      if (_accepted) {
        _stretchController.scrollEnd(velocity);
      }
    } else if (notification is ScrollUpdateNotification) {
      _totalOverscroll = 0.0;
      _stretchController.scrollEnd(0.0);
    }
    _lastNotification = notification;
    return false;
  }

  @override
  void dispose() {
    _stretchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 判定放在这里而不是 AnimatedBuilder 的 builder 里：拉伸动画的每一帧
    // 不必重复查继承数据，继承数据变化时本 State 重建即可。
    final avoidLayer = widget.avoidOffscreenLayer(context);
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: AnimatedBuilder(
        animation: _stretchController,
        builder: (BuildContext context, Widget? child) {
          final double stretch = _stretchController.overscroll;
          final double mainAxisSize = switch (widget.axis) {
            Axis.horizontal => MediaQuery.widthOf(context),
            Axis.vertical => MediaQuery.heightOf(context),
          };

          final double viewportDimension =
              _lastOverscrollNotification?.metrics.viewportDimension ??
              mainAxisSize;

          double overscroll = -stretch;

          if (widget.axisDirection == AxisDirection.up ||
              widget.axisDirection == AxisDirection.left) {
            overscroll = -overscroll;
          }

          final Widget effect = Transform(
            alignment: _alignment(overscroll, textDirection),
            transform: avoidLayer
                ? _scaleAlongAxis(overscroll)
                : Matrix4.identity(),
            // 不设 filterQuality：设了之后 RenderTransform 会改推
            // ImageFilterLayer（离屏），玻璃同样会失去背景模糊。代价是缩放
            // 时按矢量重绘而不是位图插值，越界量只有百分之几，看不出差别。
            child: StretchEffect(
              stretchStrength: avoidLayer ? 0.0 : overscroll,
              axis: widget.axis,
              child: widget.child ?? const SizedBox.shrink(),
            ),
          );

          // 只在视口比屏幕短时裁切（与 SDK 相同）：视口占满屏幕时，变换
          // 溢出的部分本来就在屏幕外。
          return ClipRect(
            clipBehavior: stretch != 0.0 && viewportDimension != mainAxisSize
                ? widget.clipBehavior
                : Clip.none,
            child: effect,
          );
        },
      ),
    );
  }

  Matrix4 _scaleAlongAxis(double overscroll) {
    final double scale = 1.0 + overscroll.abs();
    return switch (widget.axis) {
      Axis.horizontal => Matrix4.diagonal3Values(scale, 1.0, 1.0),
      Axis.vertical => Matrix4.diagonal3Values(1.0, scale, 1.0),
    };
  }

  /// 从被拉的那一端对齐（照搬 SDK StretchEffect._getAlignment）。
  AlignmentGeometry _alignment(double overscroll, TextDirection direction) {
    final bool isForward = overscroll > 0;
    if (widget.axis == Axis.vertical) {
      return isForward
          ? AlignmentDirectional.topCenter
          : AlignmentDirectional.bottomCenter;
    }
    if (direction == TextDirection.rtl) {
      return isForward
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart;
    }
    return isForward
        ? AlignmentDirectional.centerStart
        : AlignmentDirectional.centerEnd;
  }
}

/// SDK `_StretchController` 的原样拷贝（私有类，无法直接复用）：弹簧参数
/// 移植自 Android EdgeEffect.java，回弹时长与原生拉伸一致。
class _StretchController extends Listenable {
  _StretchController({required this.vsync});

  final TickerProvider vsync;
  AnimationController? _controller;

  final ValueNotifier<double> _overscrollNotifier = ValueNotifier<double>(0.0);
  double get overscroll => _overscrollNotifier.value;
  set overscroll(double newValue) {
    _overscrollNotifier.value = clampDouble(
      newValue,
      minOverscroll,
      maxOverscroll,
    );
  }

  /// 新的 pull 打断进行中的回弹动画时，记下动画当时的越界量叠加到拉动
  /// 结果上，避免拉伸突然跳变。
  double _interruptedOverscroll = 0.0;

  static const double _exponentialScalar = math.e / 0.33;
  static const double _stretchIntensity = 0.016;

  static const double minOverscroll = -1.0;
  static const double maxOverscroll = 1.0;

  static const double _flingVelocityFriction = 1 / 6000;
  static const double _absorbImpactVelocityFriction = 1 / 3000;
  static const double _maxFlingVelocity = 0.5;
  static const double _maxAbsorbImpactVelocity = 1.25;

  static const double kNaturalFrequency = 24.657;
  static const double kDampingRatio = 0.98;

  /// SDK 按目测与原生对齐的时间校正（原样保留）。
  static const double kTimeCorrectionFactor = 0.8;

  static const double kStiffness = kNaturalFrequency * kNaturalFrequency;

  static final SpringDescription _kStretchSpringDescription =
      SpringDescription.withDampingRatio(
        mass: 1,
        stiffness: kStiffness * kTimeCorrectionFactor * kTimeCorrectionFactor,
        ratio: kDampingRatio,
      );

  @override
  void addListener(VoidCallback listener) {
    _overscrollNotifier.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _overscrollNotifier.removeListener(listener);
  }

  SpringSimulation _createStretchSimulation(double velocity) {
    return SpringSimulation(
      _kStretchSpringDescription,
      overscroll,
      0.0,
      velocity * kTimeCorrectionFactor,
    );
  }

  void absorbImpact(double velocity) {
    if (velocity == 0.0) {
      return;
    }
    final double scaledVelocity = clampDouble(
      velocity * _absorbImpactVelocityFriction,
      -_maxAbsorbImpactVelocity,
      _maxAbsorbImpactVelocity,
    );

    animate(_createStretchSimulation(scaledVelocity));
  }

  void scrollEnd(double velocity) {
    if (velocity == 0.0 && overscroll == 0.0) {
      return;
    }
    final double scaledVelocity = clampDouble(
      -(velocity * _flingVelocityFriction),
      -_maxFlingVelocity,
      _maxFlingVelocity,
    );

    if (_controller == null) {
      animate(_createStretchSimulation(scaledVelocity));
    }
  }

  void animate(Simulation simulation) {
    final controller = AnimationController.unbounded(vsync: vsync)
      ..addListener(() {
        final double newOverscroll = _controller?.value ?? 0.0;
        overscroll = newOverscroll;
      })
      ..animateWith(simulation).whenComplete(() {
        overscroll = 0.0;
        _interruptedOverscroll = 0.0;
        _controller!.dispose();
        _controller = null;
      });

    _controller?.dispose();
    _controller = controller;
  }

  void pull(double normalizedOverscroll) {
    if (_controller != null) {
      _interruptedOverscroll = _controller!.value;
      _controller!.dispose();
      _controller = null;
    }

    final pullDistance = normalizedOverscroll;
    final double absDistance = pullDistance.abs();
    final double linearIntensity = _stretchIntensity * absDistance;
    final double exponentialIntensity =
        _stretchIntensity * (1 - math.exp(-absDistance * _exponentialScalar));

    final double directionSign = pullDistance.sign;
    final double newOverscroll =
        directionSign * (linearIntensity + exponentialIntensity);
    overscroll = newOverscroll + _interruptedOverscroll;
  }

  void dispose() {
    _controller?.dispose();
    _overscrollNotifier.dispose();
  }

  @override
  String toString() => '_StretchController()';
}
