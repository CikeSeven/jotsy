// 应用锁的原生能力（docs/rules/app_lock.md）：Android 通道
// `com.jotsy.diary/app_lock`（`AppLockChannel.kt`）。
//
// - 输入：Dart 下发的开关（是否监听熄屏、是否防截屏）；
// - 输出：熄屏事件流 [AppLockPlatform.screenOffEvents]、这次切到后台是不是
//   应用自己打开了别的界面（[AppLockPlatform.leftForOwnActivity]）；
// - 副作用：注册 / 注销熄屏广播，设置窗口 `FLAG_SECURE`。
//
// 只有 Android 真机注册了这条通道：其他平台（以及测试里覆盖了目标平台的
// 情况）一律不调用，返回“没有这个能力”时的默认值。通道出错同样按默认值
// 处理——应用锁宁可多锁一次，也不因为原生异常而崩溃。

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppLockPlatform {
  AppLockPlatform({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.jotsy.diary/app_lock');

  final MethodChannel _channel;
  final StreamController<void> _screenOff = StreamController<void>.broadcast();
  bool _handlerInstalled = false;

  /// 通道只在 Android 真机上存在（见文件头）。
  bool get _available => !kIsWeb && Platform.isAndroid;

  /// 手机熄屏（原生收到 `ACTION_SCREEN_OFF`）时发出一次；只在
  /// [setWatchScreenOff] 打开期间才有。应用在后台时同样会收到。
  Stream<void> get screenOffEvents {
    _installHandler();
    return _screenOff.stream;
  }

  void _installHandler() {
    if (_handlerInstalled || !_available) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'screenOff') {
        _screenOff.add(null);
      }
      return null;
    });
  }

  /// 开始 / 停止监听熄屏。
  Future<void> setWatchScreenOff(bool enabled) async {
    if (!_available) return;
    _installHandler();
    await _invoke<void>('setWatchScreenOff', <String, Object>{
      'enabled': enabled,
    });
  }

  /// 打开 / 关闭防截屏。
  Future<void> setSecureScreen(bool enabled) async {
    if (!_available) return;
    await _invoke<void>('setSecureScreen', <String, Object>{
      'enabled': enabled,
    });
  }

  /// 刚才切到后台，是不是因为应用自己打开了别的界面（选图片、拍照、选文件、
  /// 系统分享面板、手机锁屏密码页），并且那个界面还盖在本应用的任务上。
  /// 是则这段时间不算离开应用。判断不了时为 false（按离开处理）。
  Future<bool> leftForOwnActivity() async {
    if (!_available) return false;
    return await _invoke<bool>('leftForOwnActivity') ?? false;
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      debugPrint('AppLockPlatform.$method failed: ${error.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}

/// 应用锁的原生能力；测试覆盖为假实现。
final appLockPlatformProvider = Provider<AppLockPlatform>(
  (Ref ref) => AppLockPlatform(),
);
