import 'package:meta/meta.dart';

/// 日记本封面的版式，按 [Enum.name] 存在 payload 的 `coverStyle.layout`。
///
/// - [classic]：经典。有封面图时图片占上部、名称在下；没有时图标在左上、
///   名称在底部（改版前的唯一样式，也是默认值）；
/// - [fullBleed]：满版。封面图铺满整张封面，名称压在底部的实色条上；
/// - [spine]：书脊。起始侧一条深色书脊，其余同经典；
/// - [label]：标签。封面中央一块贴签，名称写在贴签上；
/// - [minimal]：极简。不画图标，名称放大靠上。
enum NotebookCoverLayout {
  classic,
  fullBleed,
  spine,
  label,
  minimal;

  /// 认不出的名字（更新版本写入的新版式）按经典显示。
  static NotebookCoverLayout fromName(Object? name) =>
      values.asNameMap()[name] ?? classic;
}

/// 封面底色上的纸张纹理，按 [Enum.name] 存在 payload 的
/// `coverStyle.texture`。只画在露出底色的部分，不盖在封面图上。
enum NotebookCoverTexture {
  none,
  dots,
  lines,
  grid,
  diagonal;

  /// 认不出的名字按无纹理。
  static NotebookCoverTexture fromName(Object? name) =>
      values.asNameMap()[name] ?? none;
}

/// 日记本封面的外观：版式、纹理与封面图的取景。
///
/// 取景只对封面图有意义：[focusX] / [focusY] 是 cover 裁切时的对齐点
/// （`Alignment(x, y)`，-1..1，0 为居中），[zoom] 是在 cover 基础上再放大的
/// 倍数（[minZoom]..[maxZoom]）。三者与显示框的宽高比无关，同一组取景在
/// 书架封面、小封面与头部卡片上看到的是同一块区域的不同裁法。换封面图时
/// 取景应重置（[withoutCrop]），旧图的取景对新图没有意义。
///
/// payload 里是 `"coverStyle":{"layout":"spine","texture":"dots","x":0.2,
/// "y":-0.4,"zoom":1.5}`，稀疏写入：默认值不写，全部默认时整个键都不写
/// （[isDefault]）。逐字段容错：认不出的版式 / 纹理按默认，数字不合法或越界
/// 时夹回范围或按默认。
@immutable
class NotebookCoverStyle {
  const NotebookCoverStyle._({
    this.layout = NotebookCoverLayout.classic,
    this.texture = NotebookCoverTexture.none,
    this.focusX = 0,
    this.focusY = 0,
    this.zoom = 1,
  });

  /// 数字统一夹到合法范围并取三位小数（编码前后相等）；NaN 按默认值。
  factory NotebookCoverStyle({
    NotebookCoverLayout layout = NotebookCoverLayout.classic,
    NotebookCoverTexture texture = NotebookCoverTexture.none,
    double focusX = 0,
    double focusY = 0,
    double zoom = 1,
  }) => NotebookCoverStyle._(
    layout: layout,
    texture: texture,
    focusX: _round(_clampOr(focusX, -1, 1, 0)),
    focusY: _round(_clampOr(focusY, -1, 1, 0)),
    zoom: _round(_clampOr(zoom, minZoom, maxZoom, 1)),
  );

  static const NotebookCoverStyle defaults = NotebookCoverStyle._();
  static const double minZoom = 1;
  static const double maxZoom = 4;

  final NotebookCoverLayout layout;
  final NotebookCoverTexture texture;
  final double focusX;
  final double focusY;
  final double zoom;

  bool get isDefault => this == defaults;

  /// 取景是否仍是默认（居中、不放大）。
  bool get hasDefaultCrop => focusX == 0 && focusY == 0 && zoom == 1;

  /// 去掉取景、保留版式与纹理：换封面图或移除封面图时用。
  NotebookCoverStyle withoutCrop() =>
      NotebookCoverStyle._(layout: layout, texture: texture);

  NotebookCoverStyle copyWith({
    NotebookCoverLayout? layout,
    NotebookCoverTexture? texture,
    double? focusX,
    double? focusY,
    double? zoom,
  }) => NotebookCoverStyle(
    layout: layout ?? this.layout,
    texture: texture ?? this.texture,
    focusX: focusX ?? this.focusX,
    focusY: focusY ?? this.focusY,
    zoom: zoom ?? this.zoom,
  );

  /// 解码 payload 里的 `coverStyle`；不是对象时为 [defaults]。
  static NotebookCoverStyle fromJson(Object? json) {
    if (json is! Map) return defaults;
    double number(Object? value, double fallback) =>
        value is num ? value.toDouble() : fallback;
    return NotebookCoverStyle(
      layout: NotebookCoverLayout.fromName(json['layout']),
      texture: NotebookCoverTexture.fromName(json['texture']),
      focusX: number(json['x'], 0),
      focusY: number(json['y'], 0),
      zoom: number(json['zoom'], 1),
    );
  }

  /// 稀疏 JSON；全部默认时为空对象（调用方据 [isDefault] 不写这个键）。
  Map<String, Object> toJson() => <String, Object>{
    if (layout != NotebookCoverLayout.classic) 'layout': layout.name,
    if (texture != NotebookCoverTexture.none) 'texture': texture.name,
    if (focusX != 0) 'x': focusX,
    if (focusY != 0) 'y': focusY,
    if (zoom != 1) 'zoom': zoom,
  };

  @override
  bool operator ==(Object other) =>
      other is NotebookCoverStyle &&
      other.layout == layout &&
      other.texture == texture &&
      other.focusX == focusX &&
      other.focusY == focusY &&
      other.zoom == zoom;

  @override
  int get hashCode => Object.hash(layout, texture, focusX, focusY, zoom);

  @override
  String toString() =>
      'NotebookCoverStyle(${layout.name}, ${texture.name}, '
      '$focusX, $focusY, ×$zoom)';
}

double _clampOr(double value, double min, double max, double fallback) {
  if (value.isNaN) return fallback;
  return value.clamp(min, max).toDouble();
}

/// 存三位小数：拖动取景得到的长尾小数没有意义，payload 也更短。
double _round(double value) => (value * 1000).roundToDouble() / 1000;
