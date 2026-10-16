import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'journal_import_cloud_cookie_jar.dart';

/// 登录网页视图里的 Cookie：读取供本次云端读取使用，读取结束后清除。
///
/// 每次登录前先清空，等同于参考实现的“临时私密浏览器目录”：不会带入上一
/// 次（或其他平台）的登录状态，也不在应用里长期保留任何账号凭据。
class CloudLoginCookies {
  const CloudLoginCookies._();

  static const MethodChannel _channel = MethodChannel(
    'com.jotsy.diary/web_cookies',
  );

  /// 只有 Android 与 iOS 提供网页视图与 Cookie 读取通道。
  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// 读取对各接口源生效的 Cookie（含 HttpOnly），按源主机放进新的罐子。
  static Future<CloudCookieJar> read(Iterable<String> origins) async {
    await _channel.invokeMethod<void>('flush');
    final jar = CloudCookieJar();
    for (final origin in origins) {
      final header = await _channel.invokeMethod<String>('getCookies', {
        'url': origin,
      });
      if (header != null && header.trim().isNotEmpty) {
        jar.addHeader(Uri.parse(origin).host, header);
      }
    }
    return jar;
  }

  /// 清除网页视图中的全部 Cookie（应用内只有云端导入使用网页视图）。
  static Future<void> clear() async {
    if (!supported) return;
    await WebViewCookieManager().clearCookies();
  }
}
