part of 'diary_preview_style.dart';

/// 头图：显示方式、高度、适配、圆角（内嵌时）、滚动淡出，以及没有封面时是否
/// 用正文第一张图。
@immutable
class DiaryPreviewCoverStyle {
  const DiaryPreviewCoverStyle({
    this.mode = DiaryPreviewCoverMode.banner,
    this.height = 420,
    this.fit = DiaryPreviewCoverFit.contain,
    this.radius = 16,
    this.fadeOnScroll = true,
    this.useFirstImage = true,
  });

  final DiaryPreviewCoverMode mode;

  /// 头图框高度；渲染时最高为屏高的 [DiaryPreviewStyleLimits.coverMaxScreenFraction]。
  final double height;
  final DiaryPreviewCoverFit fit;

  /// 内嵌模式的圆角（通栏时不用）。
  final double radius;

  /// 上滑时头图淡出并轻微缩小（改版前的样子）；关闭后头图随页面平移。
  final bool fadeOnScroll;

  /// 没有封面时用正文第一张图作头图（改版前的样子）。
  final bool useFirstImage;

  DiaryPreviewCoverStyle copyWith({
    DiaryPreviewCoverMode? mode,
    double? height,
    DiaryPreviewCoverFit? fit,
    double? radius,
    bool? fadeOnScroll,
    bool? useFirstImage,
  }) {
    return DiaryPreviewCoverStyle(
      mode: mode ?? this.mode,
      height: height ?? this.height,
      fit: fit ?? this.fit,
      radius: radius ?? this.radius,
      fadeOnScroll: fadeOnScroll ?? this.fadeOnScroll,
      useFirstImage: useFirstImage ?? this.useFirstImage,
    );
  }

  static DiaryPreviewCoverStyle _fromJson(Object? raw) {
    const d = DiaryPreviewCoverStyle();
    final json = StyleJson.map(raw);
    if (json == null) {
      return d;
    }
    return DiaryPreviewCoverStyle(
      mode: StyleJson.enumByName(
        DiaryPreviewCoverMode.values,
        json['mode'],
        d.mode,
      ),
      height: StyleJson.number(
        json['height'],
        d.height,
        DiaryPreviewStyleLimits.coverHeight,
      ),
      fit: StyleJson.enumByName(
        DiaryPreviewCoverFit.values,
        json['fit'],
        d.fit,
      ),
      radius: StyleJson.number(
        json['radius'],
        d.radius,
        DiaryPreviewStyleLimits.coverRadius,
      ),
      fadeOnScroll: StyleJson.boolean(json['fadeOnScroll'], d.fadeOnScroll),
      useFirstImage: StyleJson.boolean(json['useFirstImage'], d.useFirstImage),
    );
  }

  Map<String, Object> _toJson() {
    const d = DiaryPreviewCoverStyle();
    final json = <String, Object>{};
    StyleJson.putEnum(json, 'mode', mode, d.mode);
    StyleJson.put(json, 'height', height, d.height);
    StyleJson.putEnum(json, 'fit', fit, d.fit);
    StyleJson.put(json, 'radius', radius, d.radius);
    StyleJson.put(json, 'fadeOnScroll', fadeOnScroll, d.fadeOnScroll);
    StyleJson.put(json, 'useFirstImage', useFirstImage, d.useFirstImage);
    return json;
  }

  @override
  bool operator ==(Object other) {
    return other is DiaryPreviewCoverStyle &&
        other.mode == mode &&
        other.height == height &&
        other.fit == fit &&
        other.radius == radius &&
        other.fadeOnScroll == fadeOnScroll &&
        other.useFirstImage == useFirstImage;
  }

  @override
  int get hashCode =>
      Object.hash(mode, height, fit, radius, fadeOnScroll, useFirstImage);
}
