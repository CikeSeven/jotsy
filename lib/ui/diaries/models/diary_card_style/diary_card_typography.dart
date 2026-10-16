part of 'diary_card_style.dart';

/// 卡片文字：字号缩放、标题字重、摘要行高、对齐与文字颜色。两种布局共用。
///
/// 缩放乘在各模式的基础字号上（列表标题 18.5、瀑布流标题 16.5，摘要取主题
/// bodyMedium/bodySmall），再叠加系统字号设置；为 1 时渲染层不改写字号，
/// 与改版前完全一致。
@immutable
class DiaryCardTypography {
  const DiaryCardTypography({
    this.titleScale = 1,
    this.titleWeight = DiaryCardTitleWeight.bold,
    this.previewScale = 1,
    this.lineHeight = DiaryCardLineHeight.standard,
    this.metaScale = 1,
    this.textAlign = DiaryCardTextAlign.start,
    this.titleColor = _defaultTextColor,
    this.bodyColor = _defaultTextColor,
    this.ensureContrast = true,
  });

  static const _defaultTextColor = DiaryCardColorSpec(strength: 1);

  final double titleScale;
  final DiaryCardTitleWeight titleWeight;
  final double previewScale;
  final DiaryCardLineHeight lineHeight;

  /// 眉线日期、底栏时间、标签与印章等辅助文字的缩放。
  final double metaScale;
  final DiaryCardTextAlign textAlign;
  final DiaryCardColorSpec titleColor;

  /// 摘要、眉线与底栏的文字颜色（各自保留改版前的透明度层次）。
  final DiaryCardColorSpec bodyColor;

  /// 自定义文字颜色与卡片底色对比度过低时自动改用可读的颜色。
  final bool ensureContrast;

  DiaryCardTypography copyWith({
    double? titleScale,
    DiaryCardTitleWeight? titleWeight,
    double? previewScale,
    DiaryCardLineHeight? lineHeight,
    double? metaScale,
    DiaryCardTextAlign? textAlign,
    DiaryCardColorSpec? titleColor,
    DiaryCardColorSpec? bodyColor,
    bool? ensureContrast,
  }) {
    return DiaryCardTypography(
      titleScale: titleScale ?? this.titleScale,
      titleWeight: titleWeight ?? this.titleWeight,
      previewScale: previewScale ?? this.previewScale,
      lineHeight: lineHeight ?? this.lineHeight,
      metaScale: metaScale ?? this.metaScale,
      textAlign: textAlign ?? this.textAlign,
      titleColor: titleColor ?? this.titleColor,
      bodyColor: bodyColor ?? this.bodyColor,
      ensureContrast: ensureContrast ?? this.ensureContrast,
    );
  }

  static DiaryCardTypography _fromJson(Object? raw) {
    const d = DiaryCardTypography();
    final json = _map(raw);
    if (json == null) {
      return d;
    }
    return DiaryCardTypography(
      titleScale: _double(
        json['titleScale'],
        d.titleScale,
        DiaryCardStyleLimits.titleScale,
      ),
      titleWeight: _enumByName(
        DiaryCardTitleWeight.values,
        json['titleWeight'],
        d.titleWeight,
      ),
      previewScale: _double(
        json['previewScale'],
        d.previewScale,
        DiaryCardStyleLimits.previewScale,
      ),
      lineHeight: _enumByName(
        DiaryCardLineHeight.values,
        json['lineHeight'],
        d.lineHeight,
      ),
      metaScale: _double(
        json['metaScale'],
        d.metaScale,
        DiaryCardStyleLimits.metaScale,
      ),
      textAlign: _enumByName(
        DiaryCardTextAlign.values,
        json['textAlign'],
        d.textAlign,
      ),
      titleColor: DiaryCardColorSpec._fromJson(
        json['titleColor'],
        d.titleColor,
      ),
      bodyColor: DiaryCardColorSpec._fromJson(json['bodyColor'], d.bodyColor),
      ensureContrast: _bool(json['ensureContrast'], d.ensureContrast),
    );
  }

  Map<String, Object> _toJson() {
    const d = DiaryCardTypography();
    final json = <String, Object>{};
    _put(json, 'titleScale', titleScale, d.titleScale);
    _putEnum(json, 'titleWeight', titleWeight, d.titleWeight);
    _put(json, 'previewScale', previewScale, d.previewScale);
    _putEnum(json, 'lineHeight', lineHeight, d.lineHeight);
    _put(json, 'metaScale', metaScale, d.metaScale);
    _putEnum(json, 'textAlign', textAlign, d.textAlign);
    _putObject(json, 'titleColor', titleColor._toJson(d.titleColor));
    _putObject(json, 'bodyColor', bodyColor._toJson(d.bodyColor));
    _put(json, 'ensureContrast', ensureContrast, d.ensureContrast);
    return json;
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryCardTypography &&
        other.titleScale == titleScale &&
        other.titleWeight == titleWeight &&
        other.previewScale == previewScale &&
        other.lineHeight == lineHeight &&
        other.metaScale == metaScale &&
        other.textAlign == textAlign &&
        other.titleColor == titleColor &&
        other.bodyColor == bodyColor &&
        other.ensureContrast == ensureContrast;
  }

  @override
  int get hashCode => Object.hash(
    titleScale,
    titleWeight,
    previewScale,
    lineHeight,
    metaScale,
    textAlign,
    titleColor,
    bodyColor,
    ensureContrast,
  );
}
