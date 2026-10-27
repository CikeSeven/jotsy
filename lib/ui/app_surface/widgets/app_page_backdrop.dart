import 'package:flutter/material.dart';

import '../../../app/theme/expressive_surfaces.dart';
import '../models/app_surface_settings.dart';

/// 页面背景向子树交代的信息：页面底色、实色栏底色、内容实际叠在什么颜色
/// 上，以及留给内容玻璃的共享背景键。
///
/// 由 `AppPageBackground`（普通页面）或 `AppPagedBackground` /
/// `AppAreaBackdrop`（首页各 Tab）提供，页面与组件只经 [of] 及其便捷方法读。
/// 没有祖先（尚未接入背景的页面、单独测试的组件）时得到 [AppPageBackdrop.plain]
/// ——与接入前完全相同的颜色，所以组件可以无条件改读这里。
///
/// 字段口径：
/// - [pageColor]：页面 Scaffold / 页面底色 ColoredBox 用。实际画了背景时
///   透明（露出背景），否则为 `ExpressiveSurfaces.pageBackground`；
/// - [solidBarColor]：实色顶栏 / 侧栏的底。无背景为 surface；纯色背景为该
///   颜色（整页仍是同一片颜色，与无背景时“栏色 = 页面色”的观感一致）；
///   图片背景为 surface（实色栏保持不透明，不让图片从栏下透出）；
/// - [estimatedColor]：内容实际叠在的颜色，供对比度兜底。无背景为 surface，
///   纯色为该颜色，图片为遮罩叠在均色上（均色未出时叠在 surface 上）。
@immutable
class AppPageBackdrop {
  const AppPageBackdrop({
    required this.area,
    required this.hasBackground,
    required this.hasImage,
    required this.pageColor,
    required this.solidBarColor,
    required this.estimatedColor,
    this.contentBackdropKey,
  });

  /// 没有背景时的值（与接入前的页面颜色相同）。
  factory AppPageBackdrop.plain(
    ColorScheme scheme, {
    AppBackgroundArea? area,
    BackdropKey? contentBackdropKey,
  }) {
    return AppPageBackdrop(
      area: area,
      hasBackground: false,
      hasImage: false,
      pageColor: ExpressiveSurfaces.pageBackground(scheme),
      solidBarColor: scheme.surface,
      estimatedColor: scheme.surface,
      contentBackdropKey: contentBackdropKey,
    );
  }

  /// 所在区域；没有祖先时为 null。
  final AppBackgroundArea? area;

  /// 此刻是否实际画了颜色或图片（交叉淡入过程中也算）。图片仍在解码、
  /// 文件缺失或解码失败时为 false。
  final bool hasBackground;

  /// 此刻显示（或正在淡入）的是否是图片。
  final bool hasImage;

  final Color pageColor;
  final Color solidBarColor;
  final Color estimatedColor;

  /// 页面背景持有的共享背景键：后续“内容玻璃”（卡片、分组）经
  /// `BackdropFilter(backdropGroupKey: …)` 共用一次背景读取。没有祖先时为
  /// null（按各自独立模糊处理）。
  final BackdropKey? contentBackdropKey;

  /// 最近的页面背景信息；没有祖先时按当前主题给 [AppPageBackdrop.plain]。
  static AppPageBackdrop of(BuildContext context) {
    return maybeOf(context) ??
        AppPageBackdrop.plain(Theme.of(context).colorScheme);
  }

  /// 最近的页面背景信息；没有祖先时为 null。
  static AppPageBackdrop? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AppPageBackdropScope>()
      ?.backdrop;

  /// 页面 Scaffold / 页面底色用的颜色。
  static Color pageColorOf(BuildContext context) => of(context).pageColor;

  /// 实色顶栏 / 侧栏的底色。
  static Color solidBarColorOf(BuildContext context) =>
      of(context).solidBarColor;

  /// 内容实际叠在的颜色（对比度兜底用）。
  static Color estimatedColorOf(BuildContext context) =>
      of(context).estimatedColor;

  @override
  bool operator ==(Object other) {
    return other is AppPageBackdrop &&
        other.area == area &&
        other.hasBackground == hasBackground &&
        other.hasImage == hasImage &&
        other.pageColor == pageColor &&
        other.solidBarColor == solidBarColor &&
        other.estimatedColor == estimatedColor &&
        other.contentBackdropKey == contentBackdropKey;
  }

  @override
  int get hashCode => Object.hash(
    area,
    hasBackground,
    hasImage,
    pageColor,
    solidBarColor,
    estimatedColor,
    contentBackdropKey,
  );

  @override
  String toString() =>
      'AppPageBackdrop($area, background: $hasBackground, image: $hasImage, '
      'page: $pageColor, bar: $solidBarColor, estimated: $estimatedColor)';
}

/// 把 [AppPageBackdrop] 交给子树。只由页面背景组件插入，页面不要直接用；
/// 值不变时不通知依赖者。
class AppPageBackdropScope extends InheritedWidget {
  const AppPageBackdropScope({
    super.key,
    required this.backdrop,
    required super.child,
  });

  final AppPageBackdrop backdrop;

  @override
  bool updateShouldNotify(AppPageBackdropScope oldWidget) =>
      backdrop != oldWidget.backdrop;
}
