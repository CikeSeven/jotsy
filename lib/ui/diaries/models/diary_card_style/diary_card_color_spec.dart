part of 'diary_card_style.dart';

/// 卡片上一个颜色位（底色、渐变终点、描边、强调条、阴影、文字）的配置。
///
/// - [source] 为 theme 时沿用该颜色位原本的主题语义色；
/// - custom 时取 [light] / [dark]：深色主题优先用 [dark]，未设时由渲染层按
///   色相自动推导，保证只设了一个颜色也能在暗色模式下读得清；
/// - [strength] 是着色强度：底色与渐变为叠在卡片表面上的不透明度（1 即
///   纯色），描边、强调条与阴影为颜色本身的不透明度。文字颜色不使用强度。
@immutable
class DiaryCardColorSpec {
  const DiaryCardColorSpec({
    this.source = DiaryCardColorSource.theme,
    this.light,
    this.dark,
    this.strength = 0.14,
  });

  final DiaryCardColorSource source;

  /// 浅色主题下的自定义色（不透明 ARGB）。
  final int? light;

  /// 深色主题下的自定义色；null 表示自动推导。
  final int? dark;
  final double strength;

  /// 是否真正改变了外观：自定义来源却没有颜色时按主题色处理。
  bool get isThemed =>
      source == DiaryCardColorSource.theme ||
      (source == DiaryCardColorSource.custom && light == null);

  DiaryCardColorSpec copyWith({
    DiaryCardColorSource? source,
    int? light,
    int? dark,
    double? strength,
    bool clearDark = false,
  }) {
    return DiaryCardColorSpec(
      source: source ?? this.source,
      light: light ?? this.light,
      dark: clearDark ? null : (dark ?? this.dark),
      strength: strength ?? this.strength,
    );
  }

  static DiaryCardColorSpec _fromJson(
    Object? raw,
    DiaryCardColorSpec defaults,
  ) {
    final json = _map(raw);
    if (json == null) {
      return defaults;
    }
    return DiaryCardColorSpec(
      source: _enumByName(
        DiaryCardColorSource.values,
        json['source'],
        defaults.source,
      ),
      light: json.containsKey('light') ? _argb(json['light']) : defaults.light,
      dark: json.containsKey('dark') ? _argb(json['dark']) : defaults.dark,
      strength: _double(
        json['strength'],
        defaults.strength,
        DiaryCardStyleLimits.strength,
      ),
    );
  }

  Map<String, Object> _toJson(DiaryCardColorSpec defaults) {
    final json = <String, Object>{};
    _putEnum(json, 'source', source, defaults.source);
    final light = this.light;
    if (light != null && light != defaults.light) {
      json['light'] = _hex(light);
    }
    final dark = this.dark;
    if (dark != null && dark != defaults.dark) {
      json['dark'] = _hex(dark);
    }
    _put(json, 'strength', strength, defaults.strength);
    return json;
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryCardColorSpec &&
        other.source == source &&
        other.light == light &&
        other.dark == dark &&
        other.strength == strength;
  }

  @override
  int get hashCode => Object.hash(source, light, dark, strength);
}
