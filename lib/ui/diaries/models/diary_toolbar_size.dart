import 'package:node_diary/l10n/app_localizations.dart';

/// 编辑器悬浮工具栏的大小（设置 → 编辑器设置 → 工具栏大小）。
///
/// 只是一个整体比例：按钮、图标、选中底色与一排高度一起缩放，排布规则不变
/// （见 `diary_toolbar_layout.dart`），所以变大后一排放下的工具变少、其余收进
/// 「更多」。本机偏好（与屏幕大小、手的习惯有关），不随备份导出；认不出的
/// 存储值按标准处理。
enum DiaryToolbarSize {
  small('small', 0.85),
  standard('standard', 1),
  large('large', 1.2),
  extraLarge('extra_large', 1.4);

  const DiaryToolbarSize(this.storageKey, this.scale);

  /// 设置键 `app.settings.diary_toolbar_size` 里存的值。
  final String storageKey;

  /// 相对标准大小的比例。
  final double scale;

  static DiaryToolbarSize decode(String? raw) {
    for (final size in values) {
      if (size.storageKey == raw) return size;
    }
    return standard;
  }

  String label(AppLocalizations l10n) => switch (this) {
    small => l10n.diaryToolbarSizeSmall,
    standard => l10n.diaryToolbarSizeStandard,
    large => l10n.diaryToolbarSizeLarge,
    extraLarge => l10n.diaryToolbarSizeExtraLarge,
  };
}
