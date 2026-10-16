part of 'diary_card_style.dart';

/// 卡片容器的外观：圆角、底色、渐变、描边、强调条与阴影。两种布局共用。
///
/// 默认值即 DESIGN.md §5.1 的经典样式：圆角 24、主题卡片表面、0.8dp 主题
/// 描边、置顶淡主色着色与改版前的多层投影。
@immutable
class DiaryCardSurfaceStyle {
  const DiaryCardSurfaceStyle({
    this.cornerRadius = 24,
    this.background = const DiaryCardColorSpec(),
    this.opacity = 1,
    this.gradient = false,
    this.gradientEnd = _defaultGradientEnd,
    this.gradientDirection = DiaryCardGradientDirection.diagonal,
    this.pinnedTint = true,
    this.borderWidth = 0.8,
    this.borderColor = _defaultBorderColor,
    this.accentBar = DiaryCardAccentBar.none,
    this.accentWidth = 4,
    this.accentColor = _defaultAccentColor,
    this.shadow = DiaryCardShadowStyle.themed,
    this.shadowElevation = 8,
    this.shadowColor = _defaultShadowColor,
  });

  static const _defaultGradientEnd = DiaryCardColorSpec(
    source: DiaryCardColorSource.tertiary,
  );
  static const _defaultBorderColor = DiaryCardColorSpec(strength: 0.5);
  static const _defaultAccentColor = DiaryCardColorSpec(
    source: DiaryCardColorSource.primary,
    strength: 1,
  );
  static const _defaultShadowColor = DiaryCardColorSpec(strength: 0.18);

  final double cornerRadius;
  final DiaryCardColorSpec background;

  /// 卡片表面的不透明度；小于 1 时页面底色会透出来。
  final double opacity;

  /// 两色线性渐变：起点为 [background] 解析出的底色，终点为 [gradientEnd]。
  final bool gradient;
  final DiaryCardColorSpec gradientEnd;
  final DiaryCardGradientDirection gradientDirection;

  /// 置顶卡片的主色着色（淡主色底、主色描边与眉线日期、主色辉光）。
  final bool pinnedTint;
  final double borderWidth;
  final DiaryCardColorSpec borderColor;
  final DiaryCardAccentBar accentBar;
  final double accentWidth;
  final DiaryCardColorSpec accentColor;
  final DiaryCardShadowStyle shadow;

  /// 自定义阴影的高度，决定模糊半径与下偏移。
  final double shadowElevation;
  final DiaryCardColorSpec shadowColor;

  DiaryCardSurfaceStyle copyWith({
    double? cornerRadius,
    DiaryCardColorSpec? background,
    double? opacity,
    bool? gradient,
    DiaryCardColorSpec? gradientEnd,
    DiaryCardGradientDirection? gradientDirection,
    bool? pinnedTint,
    double? borderWidth,
    DiaryCardColorSpec? borderColor,
    DiaryCardAccentBar? accentBar,
    double? accentWidth,
    DiaryCardColorSpec? accentColor,
    DiaryCardShadowStyle? shadow,
    double? shadowElevation,
    DiaryCardColorSpec? shadowColor,
  }) {
    return DiaryCardSurfaceStyle(
      cornerRadius: cornerRadius ?? this.cornerRadius,
      background: background ?? this.background,
      opacity: opacity ?? this.opacity,
      gradient: gradient ?? this.gradient,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      gradientDirection: gradientDirection ?? this.gradientDirection,
      pinnedTint: pinnedTint ?? this.pinnedTint,
      borderWidth: borderWidth ?? this.borderWidth,
      borderColor: borderColor ?? this.borderColor,
      accentBar: accentBar ?? this.accentBar,
      accentWidth: accentWidth ?? this.accentWidth,
      accentColor: accentColor ?? this.accentColor,
      shadow: shadow ?? this.shadow,
      shadowElevation: shadowElevation ?? this.shadowElevation,
      shadowColor: shadowColor ?? this.shadowColor,
    );
  }

  static DiaryCardSurfaceStyle _fromJson(Object? raw) {
    const d = DiaryCardSurfaceStyle();
    final json = _map(raw);
    if (json == null) {
      return d;
    }
    return DiaryCardSurfaceStyle(
      cornerRadius: _double(
        json['cornerRadius'],
        d.cornerRadius,
        DiaryCardStyleLimits.cornerRadius,
      ),
      background: DiaryCardColorSpec._fromJson(
        json['background'],
        d.background,
      ),
      opacity: _double(
        json['opacity'],
        d.opacity,
        DiaryCardStyleLimits.opacity,
      ),
      gradient: _bool(json['gradient'], d.gradient),
      gradientEnd: DiaryCardColorSpec._fromJson(
        json['gradientEnd'],
        d.gradientEnd,
      ),
      gradientDirection: _enumByName(
        DiaryCardGradientDirection.values,
        json['gradientDirection'],
        d.gradientDirection,
      ),
      pinnedTint: _bool(json['pinnedTint'], d.pinnedTint),
      borderWidth: _double(
        json['borderWidth'],
        d.borderWidth,
        DiaryCardStyleLimits.borderWidth,
      ),
      borderColor: DiaryCardColorSpec._fromJson(
        json['borderColor'],
        d.borderColor,
      ),
      accentBar: _enumByName(
        DiaryCardAccentBar.values,
        json['accentBar'],
        d.accentBar,
      ),
      accentWidth: _double(
        json['accentWidth'],
        d.accentWidth,
        DiaryCardStyleLimits.accentWidth,
      ),
      accentColor: DiaryCardColorSpec._fromJson(
        json['accentColor'],
        d.accentColor,
      ),
      shadow: _enumByName(
        DiaryCardShadowStyle.values,
        json['shadow'],
        d.shadow,
      ),
      shadowElevation: _double(
        json['shadowElevation'],
        d.shadowElevation,
        DiaryCardStyleLimits.shadowElevation,
      ),
      shadowColor: DiaryCardColorSpec._fromJson(
        json['shadowColor'],
        d.shadowColor,
      ),
    );
  }

  Map<String, Object> _toJson() {
    const d = DiaryCardSurfaceStyle();
    final json = <String, Object>{};
    _put(json, 'cornerRadius', cornerRadius, d.cornerRadius);
    _putObject(json, 'background', background._toJson(d.background));
    _put(json, 'opacity', opacity, d.opacity);
    _put(json, 'gradient', gradient, d.gradient);
    _putObject(json, 'gradientEnd', gradientEnd._toJson(d.gradientEnd));
    _putEnum(json, 'gradientDirection', gradientDirection, d.gradientDirection);
    _put(json, 'pinnedTint', pinnedTint, d.pinnedTint);
    _put(json, 'borderWidth', borderWidth, d.borderWidth);
    _putObject(json, 'borderColor', borderColor._toJson(d.borderColor));
    _putEnum(json, 'accentBar', accentBar, d.accentBar);
    _put(json, 'accentWidth', accentWidth, d.accentWidth);
    _putObject(json, 'accentColor', accentColor._toJson(d.accentColor));
    _putEnum(json, 'shadow', shadow, d.shadow);
    _put(json, 'shadowElevation', shadowElevation, d.shadowElevation);
    _putObject(json, 'shadowColor', shadowColor._toJson(d.shadowColor));
    return json;
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryCardSurfaceStyle &&
        other.cornerRadius == cornerRadius &&
        other.background == background &&
        other.opacity == opacity &&
        other.gradient == gradient &&
        other.gradientEnd == gradientEnd &&
        other.gradientDirection == gradientDirection &&
        other.pinnedTint == pinnedTint &&
        other.borderWidth == borderWidth &&
        other.borderColor == borderColor &&
        other.accentBar == accentBar &&
        other.accentWidth == accentWidth &&
        other.accentColor == accentColor &&
        other.shadow == shadow &&
        other.shadowElevation == shadowElevation &&
        other.shadowColor == shadowColor;
  }

  @override
  int get hashCode => Object.hash(
    cornerRadius,
    background,
    opacity,
    gradient,
    gradientEnd,
    gradientDirection,
    pinnedTint,
    borderWidth,
    borderColor,
    accentBar,
    accentWidth,
    accentColor,
    shadow,
    shadowElevation,
    shadowColor,
  );
}
