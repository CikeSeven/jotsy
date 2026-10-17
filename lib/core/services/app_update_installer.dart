import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 安装包的基本信息（原生解析），用于安装前确认能覆盖安装。
@immutable
class AppUpdateApkInfo {
  const AppUpdateApkInfo({
    required this.packageName,
    required this.versionCode,
    required this.installedVersionCode,
    this.versionName,
    this.sameSigner,
  });

  static AppUpdateApkInfo? fromMap(Map<Object?, Object?>? map) {
    if (map == null) {
      return null;
    }
    final packageName = map['packageName'];
    final versionCode = map['versionCode'];
    final installedVersionCode = map['installedVersionCode'];
    if (packageName is! String ||
        versionCode is! int ||
        installedVersionCode is! int) {
      return null;
    }
    final versionName = map['versionName'];
    final sameSigner = map['sameSigner'];
    return AppUpdateApkInfo(
      packageName: packageName,
      versionCode: versionCode,
      installedVersionCode: installedVersionCode,
      versionName: versionName is String ? versionName : null,
      sameSigner: sameSigner is bool ? sameSigner : null,
    );
  }

  final String packageName;
  final int versionCode;
  final int installedVersionCode;
  final String? versionName;

  /// 与本机应用是否有共同的签名证书；读不到时为 null（交给系统安装器判断）。
  final bool? sameSigner;
}

/// 原生安装通道（Android `AppUpdateInstaller`）。非 Android 平台不支持应用内
/// 安装，各方法返回保守值，由界面改为打开 Release 页面。
class AppUpdateInstaller {
  const AppUpdateInstaller({
    this._channel = const MethodChannel('com.jotsy.diary/app_update'),
  });

  final MethodChannel _channel;

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// 设备支持的 ABI，首选在前；拿不到时为空列表。
  Future<List<String>> supportedAbis() async {
    if (!isSupported) {
      return const <String>[];
    }
    try {
      return await _channel.invokeListMethod<String>('supportedAbis') ??
          const <String>[];
    } on PlatformException {
      return const <String>[];
    } on MissingPluginException {
      return const <String>[];
    }
  }

  /// Android 8+ 是否已允许本应用“安装未知应用”；更早的版本恒为 true。
  Future<bool> canRequestPackageInstalls() async {
    if (!isSupported) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('canRequestPackageInstalls') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// 打开本应用的“安装未知应用”设置页；打不开时返回 false。
  Future<bool> openInstallPermissionSettings() async {
    if (!isSupported) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(
            'openInstallPermissionSettings',
          ) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<AppUpdateApkInfo?> inspectApk(String path) async {
    if (!isSupported) {
      return null;
    }
    try {
      return AppUpdateApkInfo.fromMap(
        await _channel.invokeMapMethod<Object?, Object?>(
          'inspectApk',
          <String, Object?>{'path': path},
        ),
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// 打开系统安装器；没有能处理安装包的应用时返回 false。缺少安装权限时
  /// 抛出 code 为 `permission_required` 的 [PlatformException]。
  Future<bool> install(String path) async {
    if (!isSupported) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('installApk', <String, Object?>{
            'path': path,
          }) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }
}
