// 熄屏 / 切到后台继续录音（#251）：Android 通道 `com.jotsy.diary/recording_service`
// （`RecordingForegroundService.kt`）。
//
// - 输入：录音开始、暂停 / 继续、结束时由 DiaryRecordingController 调用，带上
//   通知文案（应用内语言可以和系统不同，所以文案从 Dart 下发）与录音状态；
// - 输出：[RecordingKeepAlive.start] 回答“离开应用后麦克风还能不能继续采音”；
// - 副作用：Android 上启动 / 更新 / 停止 microphone 类型的前台服务，状态栏
//   常驻“正在录音”通知。
//
// Android 9 起，没有前台服务的后台应用从麦克风只拿到静音，所以服务没起来时
// 必须回答 false，录音控制器照旧在离开应用时暂停，免得录下一段空白。桌面
// 窗口最小化不影响采音，不需要任何东西；iOS 没有配置后台音频模式，回答 false。
// 只有 Android 真机注册了这条通道：测试里覆盖成 Android 也不调用，按 false 处理。

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/core/services/app_platform.dart';

/// 录音通知的文案与状态。
@immutable
class RecordingNotice {
  const RecordingNotice({
    required this.title,
    required this.text,
    required this.channelName,
    this.paused = false,
    this.elapsed = Duration.zero,
  });

  /// 通知标题（“正在录音” / “录音已暂停”）。
  final String title;

  /// 通知正文（点按返回的提示）。
  final String text;

  /// 系统通知设置里这一类通知的名称。
  final String channelName;

  /// 已暂停：通知不显示计时。
  final bool paused;

  /// 已录时长（不含暂停），录音中的通知从这里接着计时。
  final Duration elapsed;

  Map<String, Object> toArguments() => <String, Object>{
    'title': title,
    'text': text,
    'channelName': channelName,
    'paused': paused,
    'elapsedMs': elapsed.inMilliseconds,
  };
}

/// 录音时通知的三种文案，由界面按当前语言给出；控制器按状态挑选。
@immutable
class RecordingNoticeTexts {
  const RecordingNoticeTexts({
    required this.recording,
    required this.paused,
    required this.hint,
    required this.channelName,
  });

  final String recording;
  final String paused;
  final String hint;
  final String channelName;

  RecordingNotice notice({required bool paused, required Duration elapsed}) {
    return RecordingNotice(
      title: paused ? this.paused : recording,
      text: hint,
      channelName: channelName,
      paused: paused,
      elapsed: elapsed,
    );
  }
}

/// 让录音在离开应用后继续的保活。
abstract interface class RecordingKeepAlive {
  /// 开始采音前、应用还在前台时调用。返回 true 表示离开应用、熄屏后麦克风
  /// 仍能继续采音；false 时离开应用必须暂停（否则系统给静音）。
  Future<bool> start(RecordingNotice notice);

  /// 录音 ↔ 暂停时刷新通知；[start] 没成功时什么也不做。
  Future<void> update(RecordingNotice notice);

  /// 录音结束、取消或失败时调用；没有启动过时什么也不做。
  Future<void> stop();
}

/// 按平台实现的保活：Android 为前台服务，桌面不需要，其余平台不支持。
class PlatformRecordingKeepAlive implements RecordingKeepAlive {
  PlatformRecordingKeepAlive({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.jotsy.diary/recording_service');

  final MethodChannel _channel;
  bool _serviceRunning = false;

  /// 通道只在 Android 真机上存在（见文件头）。
  bool get _channelAvailable => !kIsWeb && Platform.isAndroid;

  @override
  Future<bool> start(RecordingNotice notice) async {
    if (!AppPlatform.supportsBackgroundRecording) return false;
    // 桌面：最小化不影响采音，不需要前台服务。
    if (!AppPlatform.isAndroid) return true;
    if (!_channelAvailable) return false;
    try {
      _serviceRunning =
          await _channel.invokeMethod<bool>('start', notice.toArguments()) ??
          false;
    } on PlatformException catch (error) {
      debugPrint('RecordingKeepAlive.start failed: ${error.message}');
      _serviceRunning = false;
    } on MissingPluginException {
      _serviceRunning = false;
    }
    return _serviceRunning;
  }

  @override
  Future<void> update(RecordingNotice notice) async {
    if (!_serviceRunning) return;
    await _invoke('update', notice.toArguments());
  }

  @override
  Future<void> stop() async {
    if (!_serviceRunning) return;
    _serviceRunning = false;
    await _invoke('stop');
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException catch (error) {
      debugPrint('RecordingKeepAlive.$method failed: ${error.message}');
    } on MissingPluginException {
      // 通道不在（不应发生：只有启动成功后才会走到这里）。
    }
  }
}
