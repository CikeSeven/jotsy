import '../sections/diary_head_section.dart';

/// 日记列表视图偏好。
///
/// 负责把设置层的原始字符串映射到页面可用的枚举，
/// 让页面不再承担解析细节。
class DiaryViewPreferences {
  const DiaryViewPreferences({
    required this.sortMode,
    required this.layoutMode,
  });

  final DiarySortMode sortMode;
  final DiaryLayoutMode layoutMode;

  factory DiaryViewPreferences.fromRaw({
    required String sortRaw,
    required String layoutRaw,
  }) {
    return DiaryViewPreferences(
      sortMode: _parseSortMode(sortRaw),
      layoutMode: _parseLayoutMode(layoutRaw),
    );
  }

  static DiarySortMode _parseSortMode(String raw) {
    switch (raw) {
      case 'updatedAsc':
        return DiarySortMode.updatedAsc;
      case 'titleAsc':
        return DiarySortMode.titleAsc;
      case 'updatedDesc':
      default:
        return DiarySortMode.updatedDesc;
    }
  }

  static DiaryLayoutMode _parseLayoutMode(String raw) {
    switch (raw) {
      case 'waterfall':
        return DiaryLayoutMode.waterfall;
      case 'list':
      default:
        return DiaryLayoutMode.list;
    }
  }
}
