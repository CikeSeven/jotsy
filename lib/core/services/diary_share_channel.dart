import 'dart:io';

import 'package:flutter/services.dart';

/// 分享到指定应用的原生通道（仅 Android）。
///
/// share_plus 只能打开系统分享面板，不能指定目标应用；“分享到微博”这类
/// 一步直达的入口需要原生侧按包名发出 Intent。职责边界：
/// - 输入：目标包名、可选文字、已暂存到应用缓存 `diary_share/` 下的图片路径；
/// - 输出：是否成功拉起目标应用；
/// - 副作用：原生侧经 FileProvider 为图片临时授予目标应用读权限。
/// 其他平台上 [installedPackages] 返回空集，界面只显示系统分享。
class DiaryShareChannel {
  const DiaryShareChannel();

  static const MethodChannel _channel = MethodChannel('com.jotsy.diary/share');

  bool get isSupported => Platform.isAndroid;

  /// 返回 [packageNames] 中已安装且能接收分享的包名。
  ///
  /// 查询失败（原生未实现、包可见性受限）按“都没装”处理：分享面板退回
  /// 系统分享，不因检测失败而打不开。
  Future<Set<String>> installedPackages(Iterable<String> packageNames) async {
    if (!isSupported) {
      return const <String>{};
    }
    try {
      final result = await _channel.invokeListMethod<String>(
        'installedPackages',
        <String, Object?>{'packages': packageNames.toList()},
      );
      return result?.toSet() ?? const <String>{};
    } on PlatformException {
      return const <String>{};
    } on MissingPluginException {
      return const <String>{};
    }
  }

  /// 把 [text] 或 [imagePaths] 发给 [packageName]。
  ///
  /// [imagePaths] 非空时发图片（多张用 `ACTION_SEND_MULTIPLE`），并在
  /// [text] 非空时一并放入 `EXTRA_TEXT`；为空时只发文字。返回 false 表示
  /// 目标应用没有能接收该内容的入口（卸载或版本过旧）。
  Future<bool> shareToPackage({
    required String packageName,
    String? text,
    List<String> imagePaths = const <String>[],
    String? chooserTitle,
  }) async {
    final launched = await _channel
        .invokeMethod<bool>('shareToPackage', <String, Object?>{
          'packageName': packageName,
          'text': text,
          'imagePaths': imagePaths,
          'chooserTitle': chooserTitle,
        });
    return launched ?? false;
  }
}
