import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/app_platform.dart';
import '../core/services/app_service.dart';
import 'launch_splash_theme.dart';

/// 原生通道：请原生把档位设成后续启动的系统闪屏主题（`LaunchSplashThemeChannel.kt`）。
@visibleForTesting
const MethodChannel launchSplashThemeChannel = MethodChannel(
  'com.jotsy.diary/launch_splash',
);

/// 把主题色交给原生，作为下次启动时系统闪屏的配色（档位见 [LaunchSplashTheme]）。
///
/// 输入：设置服务的主题色。输出：无。副作用：经 [launchSplashThemeChannel]
/// 发送档位，原生在 Android 13+ 上调用 `setSplashScreenTheme`（档位与应用版本
/// 都没变时原生跳过）。
///
/// 时机：设置就绪后先发一次当前档位——升级上来的老用户、在别处（备份恢复、
/// 局域网同步、AI 助手）改过的主题色，都在下次启动生效——之后只在档位变化时
/// 再发。由 `NodeDiaryApp` 常驻监听。通道出错只影响下次启动的闪屏配色，忽略。
final launchSplashThemeSyncProvider = Provider<void>((Ref ref) {
  if (!AppPlatform.supportsLaunchSplashTheme) {
    return;
  }
  final settings = ref.watch(settingsServiceProvider).asData?.value;
  if (settings == null) {
    return;
  }
  final seed = settings.themeSeedColorNotifier;
  var sent = false;
  int? sentIndex;
  void sync() {
    final index = LaunchSplashTheme.indexFor(seed.value);
    if (sent && index == sentIndex) {
      return;
    }
    sent = true;
    sentIndex = index;
    unawaited(_apply(index));
  }

  sync();
  seed.addListener(sync);
  ref.onDispose(() => seed.removeListener(sync));
});

Future<void> _apply(int? index) async {
  try {
    await launchSplashThemeChannel.invokeMethod<void>(
      'apply',
      <String, Object?>{'index': index},
    );
  } on PlatformException catch (error) {
    debugPrint('launch splash theme: $error');
  } on MissingPluginException {
    // 原生端没有这个通道（测试、未注册的引擎）。
  }
}
