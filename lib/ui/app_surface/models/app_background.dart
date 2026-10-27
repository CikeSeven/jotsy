import 'package:flutter/foundation.dart';

import '../../../core/services/app_background_storage_service.dart';
import '../../diaries/models/style_library/style_json.dart';
import 'app_surface_enums.dart';
import 'app_surface_limits.dart';

/// 一块背景（全局背景或某个区域自己的背景）。
///
/// 输入：已解码的 JSON（`AppSurfaceSettings` 里的 `global` 或区域的
/// `background`）；输出：不可变的背景描述。无副作用，不依赖 Flutter 的
/// `Color` / `Alignment`——颜色是 ARGB 整数，图片只是托管目录里的文件名，
/// 解析成颜色、路径、遮罩由渲染层负责。
///
/// 三种字段各自保留、互不清除：从图片切到纯色再切回来，图片与焦点都还在。
/// 兼容策略同其他样式模型：解码逐字段容错（类型不符、未知枚举名回落默认，
/// 越界数值夹到边界，不合法的文件名按没有图片处理），编码稀疏。
@immutable
class AppBackground {
  const AppBackground({
    this.kind = AppBackgroundKind.none,
    this.colorLight,
    this.colorDark,
    this.image,
    this.alignX = 0,
    this.alignY = 0,
    this.blur = 0,
    this.scrimLight = 0.25,
    this.scrimDark = 0.5,
  });

  static const AppBackground defaults = AppBackground();

  /// 从已解码的 JSON 构造；不是对象时返回默认（无背景）。
  factory AppBackground.fromJson(Object? raw) {
    final json = StyleJson.map(raw);
    if (json == null) return defaults;
    const d = defaults;
    final image = json['image'];
    return AppBackground(
      kind: StyleJson.enumByName(
        AppBackgroundKind.values,
        json['kind'],
        d.kind,
      ),
      // 与其他样式一致：接受 ARGB 整数或 `#RRGGBB`，一律存为不透明色——
      // 背景压暗 / 提亮只由遮罩表达，避免两处透明度叠乘。
      colorLight: StyleJson.argb(json['colorLight']),
      colorDark: StyleJson.argb(json['colorDark']),
      // 文件名会拼到托管目录下：带路径分隔符或 `..` 的（手改的备份）按没有
      // 图片处理，不能让它指向托管目录以外的文件。
      image: image is String && AppBackgroundStorageService.isValidName(image)
          ? image
          : null,
      alignX: StyleJson.number(
        json['alignX'],
        d.alignX,
        AppSurfaceLimits.align,
      ),
      alignY: StyleJson.number(
        json['alignY'],
        d.alignY,
        AppSurfaceLimits.align,
      ),
      blur: StyleJson.number(json['blur'], d.blur, AppSurfaceLimits.blur),
      scrimLight: StyleJson.number(
        json['scrimLight'],
        d.scrimLight,
        AppSurfaceLimits.scrim,
      ),
      scrimDark: StyleJson.number(
        json['scrimDark'],
        d.scrimDark,
        AppSurfaceLimits.scrim,
      ),
    );
  }

  final AppBackgroundKind kind;

  /// 浅色主题的背景色（不透明 ARGB）；[kind] 不是 color 时保留不用。
  final int? colorLight;

  /// 深色主题的背景色；为 null 时由 [colorLight] 推导（推导在渲染层）。
  final int? colorDark;

  /// 托管目录 `app_backgrounds/` 里的文件名（只存文件名、不存路径）。
  final String? image;

  /// 图片焦点（对应 `Alignment(alignX, alignY)`），-1..1。
  final double alignX;
  final double alignY;

  /// 图片模糊半径（sigma），只对图片生效。
  final double blur;

  /// 浅色 / 深色主题下叠在背景上的遮罩不透明度，保证上层文字可读。
  final double scrimLight;
  final double scrimDark;

  bool get isDefault => this == defaults;

  /// 这块背景是否真的会画出东西：纯色要有浅色值，图片要有文件名。图片
  /// 文件是否还在由渲染层解析时再判断。
  bool get isVisible => switch (kind) {
    AppBackgroundKind.none => false,
    AppBackgroundKind.color => colorLight != null,
    AppBackgroundKind.image => image != null && image!.isNotEmpty,
  };

  /// 稀疏 JSON：默认背景编码为空对象。
  Map<String, Object> toJson() {
    const d = defaults;
    final json = <String, Object>{};
    StyleJson.putEnum(json, 'kind', kind, d.kind);
    StyleJson.putColor(json, 'colorLight', colorLight, d.colorLight);
    StyleJson.putColor(json, 'colorDark', colorDark, d.colorDark);
    final name = image;
    if (name != null && name.isNotEmpty) json['image'] = name;
    StyleJson.put(json, 'alignX', alignX, d.alignX);
    StyleJson.put(json, 'alignY', alignY, d.alignY);
    StyleJson.put(json, 'blur', blur, d.blur);
    StyleJson.put(json, 'scrimLight', scrimLight, d.scrimLight);
    StyleJson.put(json, 'scrimDark', scrimDark, d.scrimDark);
    return json;
  }

  /// 可空字段用 [ValueGetter] 传入，才能区分“不改”（不传）与“清除”
  /// （`() => null`）。
  AppBackground copyWith({
    AppBackgroundKind? kind,
    ValueGetter<int?>? colorLight,
    ValueGetter<int?>? colorDark,
    ValueGetter<String?>? image,
    double? alignX,
    double? alignY,
    double? blur,
    double? scrimLight,
    double? scrimDark,
  }) {
    return AppBackground(
      kind: kind ?? this.kind,
      colorLight: colorLight == null ? this.colorLight : colorLight(),
      colorDark: colorDark == null ? this.colorDark : colorDark(),
      image: image == null ? this.image : image(),
      alignX: alignX ?? this.alignX,
      alignY: alignY ?? this.alignY,
      blur: blur ?? this.blur,
      scrimLight: scrimLight ?? this.scrimLight,
      scrimDark: scrimDark ?? this.scrimDark,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AppBackground &&
        other.kind == kind &&
        other.colorLight == colorLight &&
        other.colorDark == colorDark &&
        other.image == image &&
        other.alignX == alignX &&
        other.alignY == alignY &&
        other.blur == blur &&
        other.scrimLight == scrimLight &&
        other.scrimDark == scrimDark;
  }

  @override
  int get hashCode => Object.hash(
    kind,
    colorLight,
    colorDark,
    image,
    alignX,
    alignY,
    blur,
    scrimLight,
    scrimDark,
  );
}
