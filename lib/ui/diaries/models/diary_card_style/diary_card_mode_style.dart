part of 'diary_card_style.dart';

/// 列表与瀑布流各自专属的样式：封面、间距、行数、心情天气位置与列数。
///
/// 两种模式共用同一个类、各有一份默认值（[listDefaults] / [waterfallDefaults]，
/// 即改版前的写死值）；只对一种模式有意义的字段在另一种模式下忽略，例如
/// 列表不读 [columns]，瀑布流的封面只有顶部、背景与隐藏三种位置。
@immutable
class DiaryCardModeStyle {
  const DiaryCardModeStyle({
    required this.coverPosition,
    this.coverSide = 116,
    this.coverShape = DiaryCardCoverShape.square,
    this.coverRadius = 16,
    required this.coverHeight,
    this.coverInset = false,
    this.coverDivider = true,
    required this.coverGap,
    this.scrim = 0.82,
    required this.paddingH,
    required this.paddingV,
    this.cardGap = 8,
    this.sideMargin = 12,
    required this.elementGap,
    this.titleMaxLines = 2,
    required this.previewMaxLines,
    required this.metaPosition,
    this.columns = 2,
  });

  static const listDefaults = DiaryCardModeStyle(
    coverPosition: DiaryCardCoverPosition.start,
    coverHeight: 160,
    coverGap: 14,
    paddingH: 16,
    paddingV: 14,
    elementGap: 6,
    previewMaxLines: 2,
    metaPosition: DiaryCardMetaPosition.eyebrow,
  );

  static const waterfallDefaults = DiaryCardModeStyle(
    coverPosition: DiaryCardCoverPosition.top,
    coverHeight: 140,
    coverGap: 10,
    paddingH: 14,
    paddingV: 12,
    elementGap: 5,
    previewMaxLines: 3,
    metaPosition: DiaryCardMetaPosition.footer,
  );

  static DiaryCardModeStyle defaultsFor(DiaryCardMode mode) => switch (mode) {
    DiaryCardMode.list => listDefaults,
    DiaryCardMode.waterfall => waterfallDefaults,
  };

  /// 该模式可选的封面位置。
  static List<DiaryCardCoverPosition> coverPositionsFor(DiaryCardMode mode) =>
      switch (mode) {
        DiaryCardMode.list => DiaryCardCoverPosition.values,
        DiaryCardMode.waterfall => const <DiaryCardCoverPosition>[
          DiaryCardCoverPosition.top,
          DiaryCardCoverPosition.background,
          DiaryCardCoverPosition.hidden,
        ],
      };

  final DiaryCardCoverPosition coverPosition;

  /// 列表左/右侧封面的边长（矩形形状取长边）。渲染时还会按卡片可用宽度
  /// 夹紧，窄屏上文字列不会被挤没。
  final double coverSide;
  final DiaryCardCoverShape coverShape;

  /// 侧边封面与内嵌顶部封面的圆角；通栏封面由卡片圆角裁切，不读此值。
  final double coverRadius;

  /// 顶部封面的高度，或背景封面卡片的最小高度。
  final double coverHeight;

  /// 顶部封面内缩到内边距里（带 [coverRadius] 圆角），而不是贴边通栏。
  final bool coverInset;

  /// 通栏顶部封面与正文之间的细分隔线。
  final bool coverDivider;

  /// 侧边封面与正文、或内嵌顶部封面与正文之间的间距。
  final double coverGap;

  /// 背景封面模式下正文底板的不透明度。
  final double scrim;
  final double paddingH;
  final double paddingV;

  /// 相邻卡片的间距（瀑布流同时用于行距与列距）。
  final double cardGap;

  /// 卡片与屏幕左右边缘的距离。
  final double sideMargin;

  /// 正文区块之间的间距；底栏前额外多留一点（见渲染层）。
  final double elementGap;
  final int titleMaxLines;
  final int previewMaxLines;
  final DiaryCardMetaPosition metaPosition;

  /// 瀑布流列数；窄屏放不下时渲染层自动减列。
  final int columns;

  DiaryCardModeStyle copyWith({
    DiaryCardCoverPosition? coverPosition,
    double? coverSide,
    DiaryCardCoverShape? coverShape,
    double? coverRadius,
    double? coverHeight,
    bool? coverInset,
    bool? coverDivider,
    double? coverGap,
    double? scrim,
    double? paddingH,
    double? paddingV,
    double? cardGap,
    double? sideMargin,
    double? elementGap,
    int? titleMaxLines,
    int? previewMaxLines,
    DiaryCardMetaPosition? metaPosition,
    int? columns,
  }) {
    return DiaryCardModeStyle(
      coverPosition: coverPosition ?? this.coverPosition,
      coverSide: coverSide ?? this.coverSide,
      coverShape: coverShape ?? this.coverShape,
      coverRadius: coverRadius ?? this.coverRadius,
      coverHeight: coverHeight ?? this.coverHeight,
      coverInset: coverInset ?? this.coverInset,
      coverDivider: coverDivider ?? this.coverDivider,
      coverGap: coverGap ?? this.coverGap,
      scrim: scrim ?? this.scrim,
      paddingH: paddingH ?? this.paddingH,
      paddingV: paddingV ?? this.paddingV,
      cardGap: cardGap ?? this.cardGap,
      sideMargin: sideMargin ?? this.sideMargin,
      elementGap: elementGap ?? this.elementGap,
      titleMaxLines: titleMaxLines ?? this.titleMaxLines,
      previewMaxLines: previewMaxLines ?? this.previewMaxLines,
      metaPosition: metaPosition ?? this.metaPosition,
      columns: columns ?? this.columns,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryCardModeStyle &&
        other.coverPosition == coverPosition &&
        other.coverSide == coverSide &&
        other.coverShape == coverShape &&
        other.coverRadius == coverRadius &&
        other.coverHeight == coverHeight &&
        other.coverInset == coverInset &&
        other.coverDivider == coverDivider &&
        other.coverGap == coverGap &&
        other.scrim == scrim &&
        other.paddingH == paddingH &&
        other.paddingV == paddingV &&
        other.cardGap == cardGap &&
        other.sideMargin == sideMargin &&
        other.elementGap == elementGap &&
        other.titleMaxLines == titleMaxLines &&
        other.previewMaxLines == previewMaxLines &&
        other.metaPosition == metaPosition &&
        other.columns == columns;
  }

  @override
  int get hashCode => Object.hash(
    coverPosition,
    coverSide,
    coverShape,
    coverRadius,
    coverHeight,
    coverInset,
    coverDivider,
    coverGap,
    scrim,
    paddingH,
    paddingV,
    cardGap,
    sideMargin,
    elementGap,
    titleMaxLines,
    previewMaxLines,
    metaPosition,
    columns,
  );
}
