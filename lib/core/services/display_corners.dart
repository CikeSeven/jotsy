import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FlutterView;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app_platform.dart';

/// 屏幕自带的圆角：窗口贴着的那几个屏幕角的半径（逻辑像素，四角分开）。
///
/// 用途：从卡片展开日记（`ContainerTransformPageRoute`）时，容器的圆角从卡片
/// 圆角过渡到这里，落位时与屏幕的物理圆角重合——像手机系统打开应用那样，
/// 卡片一路长成屏幕的形状，而不是中途变成直角。
///
/// 来源：Android 12+ 窗口的 `WindowInsets.getRoundedCorner`（原生通道
/// `com.jotsy.diary/display_corners`，返回物理像素，这里除以设备像素比）。
/// 分屏、小窗时窗口没贴到的角为 0。
///
/// 时机：[start] 在应用启动时读一次；之后只在窗口的物理尺寸或像素比变了
/// （旋转、分屏、折叠屏展开）时重读——键盘升降同样会触发 didChangeMetrics，
/// 逐帧调通道是浪费，所以只比尺寸。连续几次读取时只认最后发出的那一次。
///
/// 读不到（Android 12 以下、窗口还没挂上、其他平台、测试里、通道出错）时
/// 保持上一次的值，初始为 [BorderRadius.zero]，即原来的直角终点。
abstract final class DisplayCorners {
  @visibleForTesting
  static const MethodChannel channel = MethodChannel(
    'com.jotsy.diary/display_corners',
  );

  /// 当前的屏幕圆角。转场途中逐帧读取，不需要监听变化。
  static BorderRadius get radii => _radii;
  static BorderRadius _radii = BorderRadius.zero;

  @visibleForTesting
  static set debugRadii(BorderRadius value) => _radii = value;

  static _WindowSizeObserver? _observer;

  /// 每次读取的序号：较早发出、较晚返回的结果不能盖掉较新的。
  static int _generation = 0;

  /// 开始跟踪屏幕圆角（重复调用无副作用）。只在
  /// [AppPlatform.supportsDisplayCorners] 时读取。
  static void start() {
    if (_observer != null || !AppPlatform.supportsDisplayCorners) {
      return;
    }
    final observer = _observer = _WindowSizeObserver();
    WidgetsBinding.instance.addObserver(observer);
    unawaited(refresh());
  }

  /// 向原生重读一次。失败时保持原值，不抛出。
  static Future<void> refresh() async {
    final generation = ++_generation;
    final List<double>? physical;
    try {
      physical = await channel.invokeListMethod<double>('radii');
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
    if (generation != _generation || physical == null || physical.length != 4) {
      return;
    }
    final ratio = _view?.devicePixelRatio ?? 1;
    Radius logical(double value) =>
        Radius.circular(math.max(0.0, value) / (ratio > 0 ? ratio : 1));
    _radii = BorderRadius.only(
      topLeft: logical(physical[0]),
      topRight: logical(physical[1]),
      bottomRight: logical(physical[2]),
      bottomLeft: logical(physical[3]),
    );
  }

  static FlutterView? get _view =>
      WidgetsBinding.instance.platformDispatcher.implicitView;

  /// 测试之间恢复初始状态：停止跟踪、丢弃在途的读取、回到直角。
  @visibleForTesting
  static void debugReset() {
    final observer = _observer;
    if (observer != null) {
      WidgetsBinding.instance.removeObserver(observer);
    }
    _observer = null;
    _generation++;
    _radii = BorderRadius.zero;
  }
}

/// 窗口物理尺寸或像素比变化时重读屏幕圆角（见 [DisplayCorners]）。
class _WindowSizeObserver with WidgetsBindingObserver {
  _WindowSizeObserver() {
    _remember();
  }

  Size? _size;
  double? _ratio;

  /// 记下当前尺寸与像素比，返回与上次相比是否变了。
  bool _remember() {
    final view = DisplayCorners._view;
    final size = view?.physicalSize;
    final ratio = view?.devicePixelRatio;
    final changed = size != _size || ratio != _ratio;
    _size = size;
    _ratio = ratio;
    return changed;
  }

  @override
  void didChangeMetrics() {
    if (_remember()) {
      unawaited(DisplayCorners.refresh());
    }
  }
}
