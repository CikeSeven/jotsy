import 'package:flutter/material.dart';

import '../../../app/theme/expressive_surfaces.dart';
import '../../diaries/viewmodels/diary_card_colors.dart';
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
///
/// [hasBackground] 与 [wantsBackground] 的区别：前者是“此刻画没画”，图片
/// 解码完成那一刻才变 true；后者是“设置要不要画”，打开页面的第一帧就定了。
/// 会影响布局的判断（如首页顶部间距）只看 [wantsBackground]，否则解码回来时
/// 内容会跳一下；颜色类的判断照旧看 [hasBackground] 与各颜色字段。
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
    bool? wantsBackground,
  }) : wantsBackground = wantsBackground ?? hasBackground;

  /// 没有背景时的值（与接入前的页面颜色相同）。
  ///
  /// [wantsBackground] 为 true 表示设置要求画背景、只是还没画出来（图片在
  /// 解码，或文件缺失 / 解码失败）：颜色仍与无背景时相同。
  factory AppPageBackdrop.plain(
    ColorScheme scheme, {
    AppBackgroundArea? area,
    BackdropKey? contentBackdropKey,
    bool wantsBackground = false,
  }) {
    return AppPageBackdrop(
      area: area,
      hasBackground: false,
      wantsBackground: wantsBackground,
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

  /// 设置是否要求这个区域画背景（与解码进度无关：图片还在解码、文件缺失
  /// 或解码失败时也为 true；换成“无背景”后的淡出过程中已为 false）。没有
  /// 给出时等于 [hasBackground]。
  final bool wantsBackground;

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

  /// 小字的最低对比度（WCAG AA）。
  static const double _minTextContrast = 4.5;

  /// 直接画在页面背景上（不在卡片 / 栏 / 面板里）的文字与图标的可读性
  /// 兜底：分组标题、脚注、空状态等。
  ///
  /// - 页面没有背景图（经典或纯色背景）时原样返回 [style]：纯色背景由用户
  ///   挑的颜色决定，文字照旧，界面与接入背景前逐像素一致；
  /// - 有背景图时：图片局部可能很花，遮罩之后的 [estimatedColor] 只是均值，
  ///   于是一方面在文字色对估计色的对比度不足 4.5 时，换成 onSurface /
  ///   surface 中对比度更高的一个（与玻璃前景兜底同一组候选，一深一浅总有
  ///   一个看得清）；另一方面给文字加一圈与它反差最大的柔和光晕（通常即
  ///   surface 色）：光晕在字形周围垫出一小片底色，局部的亮斑 / 暗斑也盖得住，
  ///   又不像整块底板那样改变版面。只改颜色与 shadows，不碰字号、字重与布局。
  ///
  /// [style] 没有颜色时取 DefaultTextStyle 的颜色（再没有取 onSurface）作为
  /// 判断依据，并把结果写回返回的 style——调用方原本靠默认色的文字也能
  /// 得到兜底。图标经 `Icon(color: s.color, shadows: s.shadows)` 套用同一份结果。
  static TextStyle? onBackgroundTextStyle(
    BuildContext context,
    TextStyle? style,
  ) {
    final backdrop = of(context);
    if (!backdrop.hasImage) return style;
    final scheme = Theme.of(context).colorScheme;
    final base = style ?? const TextStyle();
    final preferred =
        base.color ??
        DefaultTextStyle.of(context).style.color ??
        scheme.onSurface;
    // 估计色理论上不透明，仍先垫在 surface 上：对比度只对不透明色有意义；
    // 半透明的文字色（如 onSurfaceVariant 带透明度）同样先叠上去再比较。
    final under = Color.alphaBlend(backdrop.estimatedColor, scheme.surface);
    final color =
        DiaryCardColors.contrastOver(preferred, under) >= _minTextContrast
        ? preferred
        : DiaryCardColors.bestContrast(<Color>[
            scheme.onSurface,
            scheme.surface,
          ], under);
    // 光晕取 surface / onSurface 中与文字反差更大的一个：主题文字色本就与
    // surface 成对，所以通常是 surface；只有上面换成了 surface 色文字（底图
    // 偏暗而遮罩很弱）时光晕才反过来用 onSurface。
    final halo = DiaryCardColors.bestContrast(<Color>[
      scheme.surface,
      scheme.onSurface,
    ], Color.alphaBlend(color, under));
    return base.copyWith(
      color: color,
      shadows: <Shadow>[...?base.shadows, ...haloShadows(halo)],
    );
  }

  /// [onBackgroundTextStyle] 用的两层光晕：外层（模糊 8）铺开一片柔和的底，
  /// 内层（模糊 3）贴着笔画把轮廓描清。浅色光晕在花哨的图上容易被稀释，
  /// 不透明度给足；深色光晕本身就压得住，略低一些，免得字周围出现一团
  /// “脏影”。按光晕本身的明暗而不是主题明暗区分：浅色主题里换成浅色文字时
  /// 光晕是深色的。
  @visibleForTesting
  static List<Shadow> haloShadows(Color halo) {
    final lightHalo = halo.computeLuminance() > 0.5;
    return <Shadow>[
      Shadow(
        color: halo.withValues(alpha: lightHalo ? 1 : 0.85),
        blurRadius: 8,
      ),
      Shadow(
        color: halo.withValues(alpha: lightHalo ? 0.9 : 0.7),
        blurRadius: 3,
      ),
    ];
  }

  @override
  bool operator ==(Object other) {
    return other is AppPageBackdrop &&
        other.area == area &&
        other.hasBackground == hasBackground &&
        other.wantsBackground == wantsBackground &&
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
    wantsBackground,
    hasImage,
    pageColor,
    solidBarColor,
    estimatedColor,
    contentBackdropKey,
  );

  @override
  String toString() =>
      'AppPageBackdrop($area, background: $hasBackground, '
      'wants: $wantsBackground, image: $hasImage, '
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
