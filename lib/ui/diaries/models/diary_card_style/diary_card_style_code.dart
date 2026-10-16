import '../style_library/style_code.dart';
import 'diary_card_style.dart';

export '../style_library/style_code.dart' show StyleCodeResult, StyleCodeStatus;

/// 卡片样式码：`jotsy-card:v1:<base64url(JSON)>`，格式与解析规则见
/// [StyleCodeFormat]。
abstract final class DiaryCardStyleCode {
  static const String scheme = 'jotsy-card';
  static const int version = 1;
  static const int maxLength = StyleCodeFormat.maxLength;

  static final StyleCodeFormat<DiaryCardStyle> format =
      StyleCodeFormat<DiaryCardStyle>(
        scheme: scheme,
        version: version,
        fromJson: DiaryCardStyle.fromJson,
        toJson: (DiaryCardStyle style) => style.toJson(),
      );

  static String encode(DiaryCardStyle style, {String? name}) =>
      format.encode(style, name: name);

  static StyleCodeResult<DiaryCardStyle> decode(String? text) =>
      format.decode(text);
}
