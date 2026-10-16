part of 'diary_preview_style.dart';

/// 标题：显隐、“无标题”占位、字号缩放、字重、对齐与颜色。字体跟随正文字体
/// 设置（`DiaryTypography`），这里不另设。
@immutable
class DiaryPreviewTitleStyle {
  const DiaryPreviewTitleStyle({
    this.visible = true,
    this.showUntitled = true,
    this.scale = 1,
    this.weight = DiaryPreviewTitleWeight.heavy,
    this.align = DiaryPreviewAlign.start,
    this.colorLight,
    this.colorDark,
  });

  final bool visible;

  /// 没写标题时显示“无标题”；关闭后这类日记不显示标题行。
  final bool showUntitled;

  /// 相对 headlineSmall 的字号缩放。
  final double scale;
  final DiaryPreviewTitleWeight weight;
  final DiaryPreviewAlign align;

  /// 自定义标题颜色（浅色 / 深色）；浅色为 null 表示自动。
  final int? colorLight;
  final int? colorDark;

  DiaryPreviewTitleStyle copyWith({
    bool? visible,
    bool? showUntitled,
    double? scale,
    DiaryPreviewTitleWeight? weight,
    DiaryPreviewAlign? align,
    ValueGetter<int?>? colorLight,
    ValueGetter<int?>? colorDark,
  }) {
    return DiaryPreviewTitleStyle(
      visible: visible ?? this.visible,
      showUntitled: showUntitled ?? this.showUntitled,
      scale: scale ?? this.scale,
      weight: weight ?? this.weight,
      align: align ?? this.align,
      colorLight: colorLight == null ? this.colorLight : colorLight(),
      colorDark: colorDark == null ? this.colorDark : colorDark(),
    );
  }

  static DiaryPreviewTitleStyle _fromJson(Object? raw) {
    const d = DiaryPreviewTitleStyle();
    final json = StyleJson.map(raw);
    if (json == null) {
      return d;
    }
    return DiaryPreviewTitleStyle(
      visible: StyleJson.boolean(json['visible'], d.visible),
      showUntitled: StyleJson.boolean(json['showUntitled'], d.showUntitled),
      scale: StyleJson.number(
        json['scale'],
        d.scale,
        DiaryPreviewStyleLimits.titleScale,
      ),
      weight: StyleJson.enumByName(
        DiaryPreviewTitleWeight.values,
        json['weight'],
        d.weight,
      ),
      align: StyleJson.enumByName(
        DiaryPreviewAlign.values,
        json['align'],
        d.align,
      ),
      colorLight: StyleJson.argb(json['colorLight']),
      colorDark: StyleJson.argb(json['colorDark']),
    );
  }

  Map<String, Object> _toJson() {
    const d = DiaryPreviewTitleStyle();
    final json = <String, Object>{};
    StyleJson.put(json, 'visible', visible, d.visible);
    StyleJson.put(json, 'showUntitled', showUntitled, d.showUntitled);
    StyleJson.put(json, 'scale', scale, d.scale);
    StyleJson.putEnum(json, 'weight', weight, d.weight);
    StyleJson.putEnum(json, 'align', align, d.align);
    StyleJson.putColor(json, 'colorLight', colorLight, d.colorLight);
    StyleJson.putColor(json, 'colorDark', colorDark, d.colorDark);
    return json;
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryPreviewTitleStyle &&
        other.visible == visible &&
        other.showUntitled == showUntitled &&
        other.scale == scale &&
        other.weight == weight &&
        other.align == align &&
        other.colorLight == colorLight &&
        other.colorDark == colorDark;
  }

  @override
  int get hashCode => Object.hash(
    visible,
    showUntitled,
    scale,
    weight,
    align,
    colorLight,
    colorDark,
  );
}
