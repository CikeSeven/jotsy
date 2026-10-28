import '../../diaries/models/style_library/style_code.dart';
import 'explore_layout.dart';

export '../../diaries/models/style_library/style_code.dart'
    show StyleCodeResult, StyleCodeStatus;

/// 探索页布局码：`jotsy-explore:v1:<base64url(JSON)>`，格式与解析规则见
/// [StyleCodeFormat]。携带卡片顺序与设置、范围条开关与外观，不含统计范围。
abstract final class ExploreLayoutCode {
  static const String scheme = 'jotsy-explore';
  static const int version = 1;

  static final StyleCodeFormat<ExploreLayout> format =
      StyleCodeFormat<ExploreLayout>(
        scheme: scheme,
        version: version,
        fromJson: ExploreLayout.fromJson,
        toJson: (ExploreLayout layout) => layout.toJson(),
      );
}
