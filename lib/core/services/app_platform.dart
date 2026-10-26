import 'package:flutter/foundation.dart';

/// 应用运行平台与按平台区分的能力开关。
///
/// 一律由 [defaultTargetPlatform]（加 [kIsWeb]）推出，而不是 `dart:io` 的
/// `Platform`：widget 测试默认按 Android 运行、保持移动端行为，需要验证桌面
/// 分支时用 `debugDefaultTargetPlatformOverride` 切换即可。
///
/// 这里只回答“界面要不要提供这个功能”。真正调用原生 MethodChannel 的地方
/// 仍在调用旁用 `Platform.isAndroid` 等运行时判断——那些通道只在真机的
/// Android 工程里注册，测试覆盖了目标平台也不能去调用它们。
abstract final class AppPlatform {
  static TargetPlatform get _platform => defaultTargetPlatform;

  static bool get isAndroid => !kIsWeb && _platform == TargetPlatform.android;
  static bool get isIOS => !kIsWeb && _platform == TargetPlatform.iOS;
  static bool get isLinux => !kIsWeb && _platform == TargetPlatform.linux;
  static bool get isWindows => !kIsWeb && _platform == TargetPlatform.windows;
  static bool get isMacOS => !kIsWeb && _platform == TargetPlatform.macOS;

  /// 手机（Android / iOS）。
  static bool get isMobile => isAndroid || isIOS;

  /// 桌面（Linux / Windows / macOS）。
  static bool get isDesktop => isLinux || isWindows || isMacOS;

  /// 系统身份验证（应用锁、上锁日记本）：local_auth 没有 Linux 实现。
  static bool get supportsDeviceAuth =>
      isAndroid || isIOS || isWindows || isMacOS;

  /// 按包名直接分享到指定应用（微信、QQ 等）：只有 Android 原生分享通道。
  static bool get supportsShareTargets => isAndroid;

  /// 系统分享面板（文字与文件）：share_plus 在 Linux 上没有实现 `shareXFiles`。
  static bool get supportsSystemFileShare =>
      isAndroid || isIOS || isWindows || isMacOS;

  /// 图片 / 视频存进系统相册（gal）；桌面没有相册概念，改为“另存为…”对话框。
  static bool get savesImagesToGallery => isMobile;

  /// 正文内嵌播放视频：video_player 没有 Linux / Windows 实现，改为交给
  /// 系统播放器打开的封面卡片。
  static bool get supportsInlineVideo => isAndroid || isIOS || isMacOS;

  /// 长图拼接的原生合并（widget_screenshot_plus 只有 Android / iOS 实现）；
  /// 其他平台在 Dart 里用 `PictureRecorder` 拼接。
  static bool get supportsNativeLongImageMerge => isMobile;

  /// 云端笔记的网页登录（webview_flutter 与读取 Cookie 的原生通道只在手机上）。
  static bool get supportsCloudNotesLogin => isMobile;

  /// 应用内下载并安装新版本：只有 Android 能把安装包交给系统安装器。
  static bool get supportsInAppInstall => isAndroid;

  /// 自动定位与按坐标获取天气：定位解析与高德 / 和风密钥都只经 Android 通道
  /// 提供，其他平台只能手动填写地点与天气。
  static bool get supportsAutoLocation => isAndroid;

  /// 录音：record 在 Windows 用系统 Media Foundation，可直接使用；Linux 的
  /// record_linux 靠外部命令 `parecord`（PulseAudio / PipeWire 工具）采音、
  /// `ffmpeg` 编码，许多发行版默认不装，启动时找不到命令只会抛 ProcessException，
  /// 所以 Linux 按不支持处理。
  static bool get supportsAudioRecording =>
      isAndroid || isIOS || isWindows || isMacOS;
}
