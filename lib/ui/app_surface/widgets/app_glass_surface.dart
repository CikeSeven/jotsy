import 'package:flutter/material.dart';

import '../../widgets/glass/glass_surface.dart';
import 'app_glass_scope.dart';
import 'app_page_backdrop.dart';

/// 一块玻璃要不要模糊它下面的东西。
///
/// 模糊是整块表面最贵的部分（读回背景 + 高斯模糊），只在模糊得出效果时才开。
enum AppGlassBlur {
  /// 只在页面背景是图片时模糊：内容玻璃（卡片、分组）与顶栏下面只有页面
  /// 背景，纯色或无背景时模糊看不出任何差别，白耗 GPU。
  auto,

  /// 总是模糊：叠在内容之上的玻璃（编辑器工具栏、底部面板、对话框），下面
  /// 是文字与图片，模糊才能让玻璃上的内容可读。
  always,

  /// 不模糊、只要半透明底色：叠在另一块玻璃上的小控件（按钮组、输入框等）。
  /// 同一区域禁止叠两层模糊（AGENTS.md §6），上面那层只透出下面那层。
  none,
}

/// 应用材质设置下的“玻璃版”表面：底色、模糊、描边、投影都取自
/// [AppGlass.of]，画法交给共用的 [GlassSurface]。
///
/// 只负责玻璃的画法——调用方先用
/// `AppGlass.of(context).isGlass(component)` 判断，是玻璃时用本组件，否则
/// 照旧画经典样式。卡片与分组直接用封装好两种分支的 `AppCardSurface`。
///
/// 行为：
/// - 模糊：按 [blur] 与页面背景决定（见 [AppGlassBlur]）；高对比度时一律
///   不模糊、底色不透明（[AppGlassResolved.fill] 已是 solidFill）。模糊开关
///   只切 `BackdropFilter.enabled`，节点始终在树里，背景图淡入淡出时内容
///   不会重建；
/// - 共享背景读取：[backdropKey] 缺省时，内容玻璃（[AppGlassComponent.cards]）
///   取页面的 `AppPageBackdrop.contentBackdropKey`——同一页的所有卡片都只
///   叠在页面背景上，共用一次背景读取；其他组件不分组（它们下面是各不相同
///   的内容）；
/// - 前景兜底：自定义底色时，按“底色叠在页面估计色上”的结果检查主题前景
///   的对比度，不够时子树的 onSurface / onSurfaceVariant（含文字、图标与
///   ListTile、AppBar 主题）换成可读色。自定义底色下始终插入同一组主题
///   节点（够看时数据与外层相同），不随对比度结果增删节点，背景图淡入、
///   均色到达时子树不会被重新挂载；非自定义底色不插入任何节点。
///
/// 约束：与 [GlassSurface] 相同——禁止放进 `Opacity` / `FadeTransition`，
/// 需要淡入时用 [progress]。
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    super.key,
    required this.component,
    this.borderRadius = BorderRadius.zero,
    this.progress = 1,
    this.blur = AppGlassBlur.auto,
    this.shadow = false,
    this.showBorder = true,
    this.bottomHairline,
    this.backdropKey,
    required this.child,
  });

  /// 这块玻璃属于哪类组件（决定默认的共享背景键）。
  final AppGlassComponent component;
  final BorderRadius borderRadius;

  /// 显现进度（0 透明、1 完全显现），见 [GlassSurface.progress]。
  final double progress;
  final AppGlassBlur blur;

  /// 是否画外侧投影（颜色取 [AppGlassResolved.shadowColor]）。
  final bool shadow;

  /// 是否画四周描边（设置关闭描边时本来就不画）。铺满整宽的顶栏传 false，
  /// 改用 [bottomHairline]。
  final bool showBorder;

  /// 底部细线颜色，通常传 `AppGlass.of(context).hairline`（设置关闭描边时
  /// 为 null）；null 不画。只适合直角表面。
  final Color? bottomHairline;

  /// 共享背景读取的键；缺省规则见类注释。
  final BackdropKey? backdropKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glass = AppGlass.of(context);
    final backdrop = AppPageBackdrop.of(context);
    final wantsBlur = switch (blur) {
      AppGlassBlur.auto => backdrop.hasImage,
      AppGlassBlur.always => true,
      AppGlassBlur.none => false,
    };
    final key =
        backdropKey ??
        (component == AppGlassComponent.cards
            ? backdrop.contentBackdropKey
            : null);
    Widget content = child;
    if (glass.customTint) {
      content = AppGlassForegroundTheme(
        foreground: glass.foregroundFor(backdrop.estimatedColor),
        child: content,
      );
    }
    return GlassSurface(
      borderRadius: borderRadius,
      fill: glass.fill,
      blurSigma: glass.blurSigma,
      blur: wantsBlur && glass.canBlur,
      border: showBorder ? glass.border : null,
      bottomHairline: bottomHairline,
      shadowColor: shadow ? glass.shadowColor : null,
      progress: progress,
      backdropKey: key,
      child: content,
    );
  }
}

/// 把玻璃上的前景色换成 [foreground]（为 null 时保持外层的值不变）。
///
/// 结构恒定：不论是否换色都是 Theme → IconTheme → DefaultTextStyle 三层，
/// 换色与否只改数据，子树不会因对比度结果变化被重新挂载（会丢焦点、开关
/// 动画与展开状态）。外层的 IconTheme / DefaultTextStyle 先取出再放回：
/// [Theme] 自己会把 IconTheme 重置为主题的 iconTheme。
class AppGlassForegroundTheme extends StatelessWidget {
  const AppGlassForegroundTheme({
    super.key,
    required this.foreground,
    required this.child,
  });

  final AppGlassForeground? foreground;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconTheme = IconTheme.of(context);
    final textStyle = DefaultTextStyle.of(context);
    final fg = foreground;
    if (fg == null) {
      return Theme(
        data: theme,
        child: IconTheme(
          data: iconTheme,
          child: DefaultTextStyle(
            style: textStyle.style,
            textAlign: textStyle.textAlign,
            softWrap: textStyle.softWrap,
            overflow: textStyle.overflow,
            maxLines: textStyle.maxLines,
            textWidthBasis: textStyle.textWidthBasis,
            textHeightBehavior: textStyle.textHeightBehavior,
            child: child,
          ),
        ),
      );
    }
    final on = fg.onSurface;
    final variant = fg.onSurfaceVariant;
    final listTile = theme.listTileTheme;
    final appBar = theme.appBarTheme;
    final data = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        onSurface: on,
        onSurfaceVariant: variant,
      ),
      textTheme: theme.textTheme.apply(bodyColor: on, displayColor: on),
      iconTheme: theme.iconTheme.copyWith(color: variant),
      // 主题里这几处把 onSurface / onSurfaceVariant 直接烤进了样式（见
      // ExpressiveSurfaces.apply），只换 colorScheme 不会生效。
      listTileTheme: listTile.copyWith(
        iconColor: variant,
        textColor: on,
        titleTextStyle: listTile.titleTextStyle?.copyWith(color: on),
        subtitleTextStyle: listTile.subtitleTextStyle?.copyWith(color: variant),
      ),
      appBarTheme: appBar.copyWith(
        foregroundColor: on,
        titleTextStyle: appBar.titleTextStyle?.copyWith(color: on),
      ),
    );
    return Theme(
      data: data,
      child: IconTheme(
        data: iconTheme.copyWith(color: variant),
        child: DefaultTextStyle(
          style: textStyle.style.copyWith(color: on),
          textAlign: textStyle.textAlign,
          softWrap: textStyle.softWrap,
          overflow: textStyle.overflow,
          maxLines: textStyle.maxLines,
          textWidthBasis: textStyle.textWidthBasis,
          textHeightBehavior: textStyle.textHeightBehavior,
          child: child,
        ),
      ),
    );
  }
}
