import '../../../diaries/models/style_library/style_code.dart';
import 'home_bar_style.dart';

export '../../../diaries/models/style_library/style_code.dart'
    show StyleCodeResult, StyleCodeStatus;

/// 首页栏样式码：`jotsy-bars:v2:<base64url(JSON)>`，格式与解析规则见
/// [StyleCodeFormat]。只携带外观，不含栏的行为。
///
/// v1 是移除实色栏之前导出的码：稀疏 JSON 以旧默认值为基准，照旧能导入，
/// 经 [HomeBarStyle.fromLegacyJson] 读取（玻璃样式外观不变，实色样式落到
/// 新的默认悬浮栏上）。
abstract final class HomeBarStyleCode {
  static const String scheme = 'jotsy-bars';
  static const int version = 2;

  static final StyleCodeFormat<HomeBarStyle> format =
      StyleCodeFormat<HomeBarStyle>(
        scheme: scheme,
        version: version,
        fromJson: HomeBarStyle.fromJson,
        fromVersionedJson: (Object? json, int codeVersion) => codeVersion < 2
            ? HomeBarStyle.fromLegacyJson(json)
            : HomeBarStyle.fromJson(json),
        toJson: (HomeBarStyle style) => style.toJson(),
      );

  static String encode(HomeBarStyle style, {String? name}) =>
      format.encode(style, name: name);

  static StyleCodeResult<HomeBarStyle> decode(String? text) =>
      format.decode(text);
}
