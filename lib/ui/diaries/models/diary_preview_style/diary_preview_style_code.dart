import '../style_library/style_code.dart';
import 'diary_preview_style.dart';

export '../style_library/style_code.dart' show StyleCodeResult, StyleCodeStatus;

/// 预览页样式码：`jotsy-reader:v1:<base64url(JSON)>`，格式与解析规则见
/// [StyleCodeFormat]。只携带外观，不含阅读行为。
abstract final class DiaryPreviewStyleCode {
  static const String scheme = 'jotsy-reader';
  static const int version = 1;

  static final StyleCodeFormat<DiaryPreviewStyle> format =
      StyleCodeFormat<DiaryPreviewStyle>(
        scheme: scheme,
        version: version,
        fromJson: DiaryPreviewStyle.fromJson,
        toJson: (DiaryPreviewStyle style) => style.toJson(),
      );

  static String encode(DiaryPreviewStyle style, {String? name}) =>
      format.encode(style, name: name);

  static StyleCodeResult<DiaryPreviewStyle> decode(String? text) =>
      format.decode(text);
}
