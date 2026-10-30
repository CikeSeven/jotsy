part of 'diary_preview_style.dart';

/// 页面与顶栏：配色基调（及其着色强度、取不到颜色时的回退）、纸张（及是否
/// 随基调染色、背景遮罩是否随基调染色）、正文颜色、边距、正文宽度、顶栏、
/// 阅读进度与回到顶部。
///
/// 自定义颜色分浅色与深色两态（不透明 ARGB）：深色为 null 时由渲染层按色相
/// 推导；正文颜色浅色值为 null 表示“自动”（跟随纸张与主题）。
@immutable
class DiaryPreviewPageStyle {
  const DiaryPreviewPageStyle({
    this.colorSeed = DiaryPreviewColorSeed.app,
    this.seedColor,
    this.seedIntensity = DiaryPreviewSeedIntensity.soft,
    this.seedFallback = DiaryPreviewSeedFallback.app,
    this.paper = DiaryPreviewPaper.theme,
    this.tintPaper = false,
    this.tintScrim = false,
    this.paperLight,
    this.paperDark,
    this.textLight,
    this.textDark,
    this.horizontalPadding = 16,
    this.limitWidth = false,
    this.contentWidth = 640,
    this.topBar = DiaryPreviewTopBarMode.floating,
    this.topBarTitle = DiaryPreviewTopBarTitle.label,
    this.showTypographyButton = true,
    this.showEditButton = true,
    this.showShareButton = false,
    this.progress = DiaryPreviewProgress.none,
    this.backToTop = false,
  });

  final DiaryPreviewColorSeed colorSeed;

  /// [DiaryPreviewColorSeed.custom] 时的种子色。
  final int? seedColor;

  /// 基调不是“跟随应用”时整页主题的配色方案。
  final DiaryPreviewSeedIntensity seedIntensity;

  /// 基调为心情 / 首个标签而这篇取不到颜色时的整页主题。
  final DiaryPreviewSeedFallback seedFallback;
  final DiaryPreviewPaper paper;

  /// 纸张为 [DiaryPreviewPaper.theme] 且取到了基调颜色时，页面底色叠上一层
  /// 淡淡的基调色（选了内置或自定义纸色时以纸色为准，不染色）。
  final bool tintPaper;

  /// 纸张跟随主题、预览页画着“背景与材质”的背景图时，图上的遮罩换成这篇
  /// 的基调色（深浅仍按背景设置里的遮罩），见 [tintsBackgroundScrim]。
  final bool tintScrim;

  /// [DiaryPreviewPaper.custom] 时的纸色（浅色 / 深色）。
  final int? paperLight;
  final int? paperDark;

  /// 自定义正文颜色（浅色 / 深色）；浅色为 null 表示自动。
  final int? textLight;
  final int? textDark;
  final double horizontalPadding;

  /// 是否限制正文宽度（平板与横屏时居中排版）。
  final bool limitWidth;
  final double contentWidth;
  final DiaryPreviewTopBarMode topBar;
  final DiaryPreviewTopBarTitle topBarTitle;
  final bool showTypographyButton;
  final bool showEditButton;
  final bool showShareButton;
  final DiaryPreviewProgress progress;
  final bool backToTop;

  /// 纸张是否跟随主题（没有纸色）：主题纸张，或选了自定义却还没有颜色。
  /// 只有这时预览页才让位给“背景与材质”的背景（与
  /// `DiaryPreviewResolvedStyle.paperFollowsTheme` 同一口径）。
  bool get paperFollowsTheme =>
      paper == DiaryPreviewPaper.theme ||
      (paper == DiaryPreviewPaper.custom && paperLight == null);

  /// “背景遮罩随基调染色”是否生效：开关打开、有基调（不是跟随应用）且纸张
  /// 让位给背景。生效时预览页的背景不画遮罩，由各篇按自己的基调色画（见
  /// `AppPageBackground.deferScrim`）。
  bool get tintsBackgroundScrim =>
      tintScrim && colorSeed != DiaryPreviewColorSeed.app && paperFollowsTheme;

  DiaryPreviewPageStyle copyWith({
    DiaryPreviewColorSeed? colorSeed,
    ValueGetter<int?>? seedColor,
    DiaryPreviewSeedIntensity? seedIntensity,
    DiaryPreviewSeedFallback? seedFallback,
    DiaryPreviewPaper? paper,
    bool? tintPaper,
    bool? tintScrim,
    ValueGetter<int?>? paperLight,
    ValueGetter<int?>? paperDark,
    ValueGetter<int?>? textLight,
    ValueGetter<int?>? textDark,
    double? horizontalPadding,
    bool? limitWidth,
    double? contentWidth,
    DiaryPreviewTopBarMode? topBar,
    DiaryPreviewTopBarTitle? topBarTitle,
    bool? showTypographyButton,
    bool? showEditButton,
    bool? showShareButton,
    DiaryPreviewProgress? progress,
    bool? backToTop,
  }) {
    return DiaryPreviewPageStyle(
      colorSeed: colorSeed ?? this.colorSeed,
      seedColor: seedColor == null ? this.seedColor : seedColor(),
      seedIntensity: seedIntensity ?? this.seedIntensity,
      seedFallback: seedFallback ?? this.seedFallback,
      paper: paper ?? this.paper,
      tintPaper: tintPaper ?? this.tintPaper,
      tintScrim: tintScrim ?? this.tintScrim,
      paperLight: paperLight == null ? this.paperLight : paperLight(),
      paperDark: paperDark == null ? this.paperDark : paperDark(),
      textLight: textLight == null ? this.textLight : textLight(),
      textDark: textDark == null ? this.textDark : textDark(),
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      limitWidth: limitWidth ?? this.limitWidth,
      contentWidth: contentWidth ?? this.contentWidth,
      topBar: topBar ?? this.topBar,
      topBarTitle: topBarTitle ?? this.topBarTitle,
      showTypographyButton: showTypographyButton ?? this.showTypographyButton,
      showEditButton: showEditButton ?? this.showEditButton,
      showShareButton: showShareButton ?? this.showShareButton,
      progress: progress ?? this.progress,
      backToTop: backToTop ?? this.backToTop,
    );
  }

  static DiaryPreviewPageStyle _fromJson(Object? raw) {
    const d = DiaryPreviewPageStyle();
    final json = StyleJson.map(raw);
    if (json == null) {
      return d;
    }
    return DiaryPreviewPageStyle(
      colorSeed: StyleJson.enumByName(
        DiaryPreviewColorSeed.values,
        json['colorSeed'],
        d.colorSeed,
      ),
      seedColor: StyleJson.argb(json['seedColor']),
      seedIntensity: StyleJson.enumByName(
        DiaryPreviewSeedIntensity.values,
        json['seedIntensity'],
        d.seedIntensity,
      ),
      seedFallback: StyleJson.enumByName(
        DiaryPreviewSeedFallback.values,
        json['seedFallback'],
        d.seedFallback,
      ),
      paper: StyleJson.enumByName(
        DiaryPreviewPaper.values,
        json['paper'],
        d.paper,
      ),
      tintPaper: StyleJson.boolean(json['tintPaper'], d.tintPaper),
      tintScrim: StyleJson.boolean(json['tintScrim'], d.tintScrim),
      paperLight: StyleJson.argb(json['paperLight']),
      paperDark: StyleJson.argb(json['paperDark']),
      textLight: StyleJson.argb(json['textLight']),
      textDark: StyleJson.argb(json['textDark']),
      horizontalPadding: StyleJson.number(
        json['horizontalPadding'],
        d.horizontalPadding,
        DiaryPreviewStyleLimits.horizontalPadding,
      ),
      limitWidth: StyleJson.boolean(json['limitWidth'], d.limitWidth),
      contentWidth: StyleJson.number(
        json['contentWidth'],
        d.contentWidth,
        DiaryPreviewStyleLimits.contentWidth,
      ),
      topBar: StyleJson.enumByName(
        DiaryPreviewTopBarMode.values,
        json['topBar'],
        d.topBar,
      ),
      topBarTitle: StyleJson.enumByName(
        DiaryPreviewTopBarTitle.values,
        json['topBarTitle'],
        d.topBarTitle,
      ),
      showTypographyButton: StyleJson.boolean(
        json['showTypographyButton'],
        d.showTypographyButton,
      ),
      showEditButton: StyleJson.boolean(
        json['showEditButton'],
        d.showEditButton,
      ),
      showShareButton: StyleJson.boolean(
        json['showShareButton'],
        d.showShareButton,
      ),
      progress: StyleJson.enumByName(
        DiaryPreviewProgress.values,
        json['progress'],
        d.progress,
      ),
      backToTop: StyleJson.boolean(json['backToTop'], d.backToTop),
    );
  }

  Map<String, Object> _toJson() {
    const d = DiaryPreviewPageStyle();
    final json = <String, Object>{};
    StyleJson.putEnum(json, 'colorSeed', colorSeed, d.colorSeed);
    StyleJson.putColor(json, 'seedColor', seedColor, d.seedColor);
    StyleJson.putEnum(json, 'seedIntensity', seedIntensity, d.seedIntensity);
    StyleJson.putEnum(json, 'seedFallback', seedFallback, d.seedFallback);
    StyleJson.putEnum(json, 'paper', paper, d.paper);
    StyleJson.put(json, 'tintPaper', tintPaper, d.tintPaper);
    StyleJson.put(json, 'tintScrim', tintScrim, d.tintScrim);
    StyleJson.putColor(json, 'paperLight', paperLight, d.paperLight);
    StyleJson.putColor(json, 'paperDark', paperDark, d.paperDark);
    StyleJson.putColor(json, 'textLight', textLight, d.textLight);
    StyleJson.putColor(json, 'textDark', textDark, d.textDark);
    StyleJson.put(
      json,
      'horizontalPadding',
      horizontalPadding,
      d.horizontalPadding,
    );
    StyleJson.put(json, 'limitWidth', limitWidth, d.limitWidth);
    StyleJson.put(json, 'contentWidth', contentWidth, d.contentWidth);
    StyleJson.putEnum(json, 'topBar', topBar, d.topBar);
    StyleJson.putEnum(json, 'topBarTitle', topBarTitle, d.topBarTitle);
    StyleJson.put(
      json,
      'showTypographyButton',
      showTypographyButton,
      d.showTypographyButton,
    );
    StyleJson.put(json, 'showEditButton', showEditButton, d.showEditButton);
    StyleJson.put(json, 'showShareButton', showShareButton, d.showShareButton);
    StyleJson.putEnum(json, 'progress', progress, d.progress);
    StyleJson.put(json, 'backToTop', backToTop, d.backToTop);
    return json;
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryPreviewPageStyle &&
        other.colorSeed == colorSeed &&
        other.seedColor == seedColor &&
        other.seedIntensity == seedIntensity &&
        other.seedFallback == seedFallback &&
        other.paper == paper &&
        other.tintPaper == tintPaper &&
        other.tintScrim == tintScrim &&
        other.paperLight == paperLight &&
        other.paperDark == paperDark &&
        other.textLight == textLight &&
        other.textDark == textDark &&
        other.horizontalPadding == horizontalPadding &&
        other.limitWidth == limitWidth &&
        other.contentWidth == contentWidth &&
        other.topBar == topBar &&
        other.topBarTitle == topBarTitle &&
        other.showTypographyButton == showTypographyButton &&
        other.showEditButton == showEditButton &&
        other.showShareButton == showShareButton &&
        other.progress == progress &&
        other.backToTop == backToTop;
  }

  @override
  // 字段超过 Object.hash 的 20 个参数上限，改用 hashAll。
  int get hashCode => Object.hashAll(<Object?>[
    colorSeed,
    seedColor,
    seedIntensity,
    seedFallback,
    paper,
    tintPaper,
    tintScrim,
    paperLight,
    paperDark,
    textLight,
    textDark,
    horizontalPadding,
    limitWidth,
    contentWidth,
    topBar,
    topBarTitle,
    showTypographyButton,
    showEditButton,
    showShareButton,
    progress,
    backToTop,
  ]);
}
