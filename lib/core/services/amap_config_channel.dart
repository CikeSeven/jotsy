import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 读取原生注入的 AMap 配置。
///
/// 约束：
/// - 仅 Android 平台返回有效 key；
/// - key 由原生层读取本地配置注入，避免硬编码到 Dart 代码。
class AMapConfigChannel {
  const AMapConfigChannel._();

  static const MethodChannel _channel = MethodChannel('com.jotsy.diary/config');

  static Future<String?> getAmapApiKey() async {
    return _getChannelString('getAmapApiKey');
  }

  static Future<String?> getAmapWebApiKey() async {
    return _getChannelString('getAmapWebApiKey');
  }

  static Future<String?> getQWeatherCredentialId() async {
    return _getChannelString('getQWeatherCredentialId');
  }

  static Future<String?> getQWeatherApiKey() async {
    return _getChannelString('getQWeatherApiKey');
  }

  static Future<String?> getQWeatherApiHost() async {
    return _getChannelString('getQWeatherApiHost');
  }

  static Future<String?> _getChannelString(String method) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    try {
      final rawKey = await _channel.invokeMethod<String>(method);
      final normalized = rawKey?.trim();
      if (normalized == null || normalized.isEmpty) {
        return null;
      }
      return normalized;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
