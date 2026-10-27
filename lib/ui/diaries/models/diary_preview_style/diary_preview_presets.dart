import 'diary_preview_style.dart';

/// 预览页内置预设的标识；名称、说明与图标由设置页按 id 解析（模型层不含
/// 文案）。
enum DiaryPreviewPresetId {
  classic,
  paper,
  magazine,
  minimal,
  night,
  journal,
  mood,
  immersive,
}

/// 内置的预览页样式预设。
///
/// 套用预设即把当前样式整体替换为预设值（之后可继续微调）；[classic] 就是
/// 默认样式。阅读行为（翻页、勾选待办等）是独立设置，预设不改动它。
abstract final class DiaryPreviewPresets {
  static const Map<DiaryPreviewPresetId, DiaryPreviewStyle> styles =
      <DiaryPreviewPresetId, DiaryPreviewStyle>{
        DiaryPreviewPresetId.classic: DiaryPreviewStyle.defaults,
        DiaryPreviewPresetId.paper: _paper,
        DiaryPreviewPresetId.magazine: _magazine,
        DiaryPreviewPresetId.minimal: _minimal,
        DiaryPreviewPresetId.night: _night,
        DiaryPreviewPresetId.journal: _journal,
        DiaryPreviewPresetId.mood: _mood,
        DiaryPreviewPresetId.immersive: _immersive,
      };

  static DiaryPreviewStyle styleOf(DiaryPreviewPresetId id) => styles[id]!;

  /// 与 [style] 完全相同的第一个预设；不是任何预设时为 null。
  static DiaryPreviewPresetId? match(DiaryPreviewStyle style) {
    for (final entry in styles.entries) {
      if (entry.value == style) {
        return entry.key;
      }
    }
    return null;
  }

  /// 纸书：暖白纸、居中标题、内嵌头图，信息排成一行，正文限宽居中。
  static const _paper = DiaryPreviewStyle(
    page: DiaryPreviewPageStyle(
      paper: DiaryPreviewPaper.warm,
      horizontalPadding: 24,
      limitWidth: true,
    ),
    cover: DiaryPreviewCoverStyle(
      mode: DiaryPreviewCoverMode.inset,
      height: 300,
      fit: DiaryPreviewCoverFit.cover,
      radius: 12,
    ),
    title: DiaryPreviewTitleStyle(
      scale: 1.1,
      weight: DiaryPreviewTitleWeight.bold,
      align: DiaryPreviewAlign.center,
    ),
    meta: DiaryPreviewMetaStyle(
      layout: DiaryPreviewMetaLayout.inline,
      dateFormat: DiaryCardDateFormat.full,
      showWeekday: true,
      datePrefix: false,
      tagStyle: DiaryCardTagStyle.plain,
      chipStyle: DiaryPreviewChipStyle.plain,
    ),
    body: DiaryPreviewBodyStyle(
      editedFormat: DiaryPreviewEditedFormat.relative,
    ),
  );

  /// 杂志：高大的通栏头图、放大的标题，日期以眉线形式放在标题上方。
  static const _magazine = DiaryPreviewStyle(
    page: DiaryPreviewPageStyle(horizontalPadding: 20),
    cover: DiaryPreviewCoverStyle(height: 520, fit: DiaryPreviewCoverFit.cover),
    title: DiaryPreviewTitleStyle(scale: 1.35),
    meta: DiaryPreviewMetaStyle(
      position: DiaryPreviewMetaPosition.aboveTitle,
      layout: DiaryPreviewMetaLayout.inline,
      dateFormat: DiaryCardDateFormat.eyebrow,
      showWeekday: true,
      datePrefix: false,
      tagStyle: DiaryCardTagStyle.plain,
      chipStyle: DiaryPreviewChipStyle.plain,
    ),
  );

  /// 极简：不要头图与顶栏标题，只留日期与圆点标签。
  static const _minimal = DiaryPreviewStyle(
    page: DiaryPreviewPageStyle(
      topBar: DiaryPreviewTopBarMode.pinned,
      topBarTitle: DiaryPreviewTopBarTitle.none,
    ),
    cover: DiaryPreviewCoverStyle(mode: DiaryPreviewCoverMode.hidden),
    title: DiaryPreviewTitleStyle(
      scale: 0.95,
      weight: DiaryPreviewTitleWeight.bold,
    ),
    meta: DiaryPreviewMetaStyle(
      layout: DiaryPreviewMetaLayout.inline,
      showLocation: false,
      showWeather: false,
      showMood: false,
      showEnergy: false,
      dateFormat: DiaryCardDateFormat.full,
      datePrefix: false,
      tagStyle: DiaryCardTagStyle.dot,
      chipStyle: DiaryPreviewChipStyle.plain,
    ),
    body: DiaryPreviewBodyStyle(showLastEdited: false),
  );

  /// 夜读：墨色纸张（整页换成深色），顶端阅读进度线。
  static const _night = DiaryPreviewStyle(
    page: DiaryPreviewPageStyle(
      paper: DiaryPreviewPaper.ink,
      horizontalPadding: 20,
      progress: DiaryPreviewProgress.line,
    ),
    title: DiaryPreviewTitleStyle(weight: DiaryPreviewTitleWeight.bold),
    meta: DiaryPreviewMetaStyle(chipStyle: DiaryPreviewChipStyle.plain),
  );

  /// 手账：按心情着色，内嵌圆角头图，居中标题，信息收进信息卡。
  static const _journal = DiaryPreviewStyle(
    page: DiaryPreviewPageStyle(
      colorSeed: DiaryPreviewColorSeed.mood,
      horizontalPadding: 20,
    ),
    cover: DiaryPreviewCoverStyle(
      mode: DiaryPreviewCoverMode.inset,
      height: 300,
      fit: DiaryPreviewCoverFit.cover,
      radius: 20,
    ),
    title: DiaryPreviewTitleStyle(scale: 1.15, align: DiaryPreviewAlign.center),
    meta: DiaryPreviewMetaStyle(
      layout: DiaryPreviewMetaLayout.card,
      dateFormat: DiaryCardDateFormat.full,
      showWeekday: true,
      showTime: true,
      datePrefix: false,
    ),
  );

  /// 心情色：整页按这篇日记的心情着色，其余保持默认。
  static const _mood = DiaryPreviewStyle(
    page: DiaryPreviewPageStyle(colorSeed: DiaryPreviewColorSeed.mood),
  );

  /// 沉浸：铺满的头图、无顶栏标题、进度线与回到顶部。
  static const _immersive = DiaryPreviewStyle(
    page: DiaryPreviewPageStyle(
      horizontalPadding: 22,
      topBarTitle: DiaryPreviewTopBarTitle.none,
      progress: DiaryPreviewProgress.line,
      backToTop: true,
    ),
    cover: DiaryPreviewCoverStyle(height: 480, fit: DiaryPreviewCoverFit.cover),
    meta: DiaryPreviewMetaStyle(
      layout: DiaryPreviewMetaLayout.inline,
      datePrefix: false,
    ),
  );
}
