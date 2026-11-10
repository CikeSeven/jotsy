import '../../../diaries/models/style_library/style_code.dart';
import 'home_bar_style.dart';

export '../../../diaries/models/style_library/style_code.dart'
    show StyleCodeResult, StyleCodeStatus;

/// 首页栏样式码：`jotsy-bars:v1:<base64url(JSON)>`，格式与解析规则见
/// [StyleCodeFormat]。只携带外观，不含栏的行为。
abstract final class HomeBarStyleCode {
  static const String scheme = 'jotsy-bars';
  static const int version = 1;

  static final StyleCodeFormat<HomeBarStyle> format =
      StyleCodeFormat<HomeBarStyle>(
        scheme: scheme,
        version: version,
        fromJson: HomeBarStyle.fromJson,
        toJson: (HomeBarStyle style) => style.toJson(),
      );

  static String encode(HomeBarStyle style, {String? name}) =>
      format.encode(style, name: name);

  static StyleCodeResult<HomeBarStyle> decode(String? text) =>
      format.decode(text);
}
