import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app/theme/app_breakpoints.dart';
import '../app_surface/widgets/app_glass_scope.dart';
import '../app_surface/widgets/app_glass_surface.dart';
import '../app_surface/widgets/app_page_backdrop.dart';

/// Expressive 紧凑标题栏；统一 64dp 高度和默认返回图标，业务动作由页面注入。
///
/// 材质：组件材质设置里顶栏（`AppGlassComponent.topBars`）为玻璃、且调用方
/// 没有指定 [backgroundColor] 时，整条栏（含状态栏区域，以及
/// [contentMaxWidth] 两侧的留白）是一片玻璃，底缘一条细线（描边开时）；
/// 栏的位置与高度不变，不延伸到正文后面（Scaffold 的
/// `extendBodyBehindAppBar` 照旧），所以下面只有页面背景——模糊按
/// `AppGlassBlur.auto`，只在背景是图片时才开。首页四个 Tab 的顶栏由导航栏
/// 样式控制，不经本组件。
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle,
    this.automaticallyImplyLeading = true,
    this.foregroundColor,
    this.backgroundColor,
    this.toolbarHeight,
    this.bottom,
    this.systemOverlayStyle,
    this.contentMaxWidth,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool? centerTitle;
  final bool automaticallyImplyLeading;
  final Color? foregroundColor;

  /// 指定底色。给出时一律画经典实色、不跟随玻璃：传底色的页面（纸色、
  /// 特殊色）是要栏与某块内容同色，换成半透明玻璃会破坏这种衔接。
  final Color? backgroundColor;
  final double? toolbarHeight;
  final PreferredSizeWidget? bottom;
  final SystemUiOverlayStyle? systemOverlayStyle;

  /// 页面内容列的最大宽度（如 `AppContentWidth.form`）。给出且标题栏宽于
  /// `contentMaxWidth + 32` 时，工具栏两侧各缩进 `gutter − 16`，返回键与标题
  /// 对齐居中的内容列、动作贴内容列右缘；底色仍铺满整栏。为 null（默认）
  /// 或标题栏不够宽时与原来完全一致。
  final double? contentMaxWidth;

  @override
  Size get preferredSize {
    final resolvedToolbarHeight = toolbarHeight ?? 64;
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(resolvedToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final glass =
        backgroundColor == null &&
        AppGlass.of(context).isGlass(AppGlassComponent.topBars);
    if (glass) {
      return _buildGlass(context);
    }
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final resolvedForeground = foregroundColor ?? colorScheme.onSurface;
    // 未指定底色时取所在页面背景的实色栏底色：没有背景（或页面尚未接入
    // 背景）时就是 surface，与原来一致；纯色背景时与页面同色，图片背景时
    // 保持不透明的 surface。
    final resolvedBackground =
        backgroundColor ?? AppPageBackdrop.solidBarColorOf(context);
    final resolvedOverlay = _overlayStyle(theme);

    final appBar = _buildAppBar(
      context,
      foreground: resolvedForeground,
      background: resolvedBackground,
      overlay: resolvedOverlay,
    );
    final maxWidth = contentMaxWidth;
    if (maxWidth == null) {
      return appBar;
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final inset = _contentInset(constraints, maxWidth);
        if (inset <= 0) {
          return appBar;
        }
        // 两侧留白用同一底色补齐，看起来仍是一整条标题栏。
        return ColoredBox(
          color: resolvedBackground,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: inset),
            child: appBar,
          ),
        );
      },
    );
  }

  /// 玻璃顶栏：AppBar 本身透明，玻璃铺满整条栏（[AppGlassSurface] 包在
  /// 内缩的 Padding 外面，两侧留白同样是玻璃，不再补实色）。前景在玻璃
  /// 之内读主题：自定义底色需要换前景时，玻璃表面已在子树里换好颜色。
  Widget _buildGlass(BuildContext context) {
    final glass = AppGlass.of(context);
    final maxWidth = contentMaxWidth;
    Widget bar = Builder(
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return _buildAppBar(
          context,
          foreground: foregroundColor ?? theme.colorScheme.onSurface,
          background: Colors.transparent,
          overlay: _overlayStyle(theme),
        );
      },
    );
    if (maxWidth != null) {
      final appBar = bar;
      bar = LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final inset = _contentInset(constraints, maxWidth);
          // 内缩与否都保留 Padding 节点（inset 为 0 时不缩），跨过阈值时
          // AppBar 不会被重新挂载。
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: inset > 0 ? inset : 0),
            child: appBar,
          );
        },
      );
    }
    return AppGlassSurface(
      component: AppGlassComponent.topBars,
      showBorder: false,
      bottomHairline: glass.hairline,
      child: bar,
    );
  }

  /// [contentMaxWidth] 对应的两侧缩进；标题栏不够宽（或宽度无界）时 ≤ 0。
  static double _contentInset(BoxConstraints constraints, double maxWidth) {
    if (!constraints.hasBoundedWidth) {
      return 0;
    }
    return AppContentWidth.gutter(constraints.maxWidth, maxWidth) - 16;
  }

  SystemUiOverlayStyle _overlayStyle(ThemeData theme) {
    final isLight = theme.colorScheme.brightness == Brightness.light;
    return systemOverlayStyle ??
        theme.appBarTheme.systemOverlayStyle ??
        SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: isLight
              ? Brightness.dark
              : Brightness.light,
        );
  }

  AppBar _buildAppBar(
    BuildContext context, {
    required Color foreground,
    required Color background,
    required SystemUiOverlayStyle overlay,
  }) {
    return AppBar(
      title: title,
      leading:
          leading ??
          (automaticallyImplyLeading && Navigator.of(context).canPop()
              ? IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
                )
              : null),
      actions: actions,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      foregroundColor: foreground,
      backgroundColor: background,
      systemOverlayStyle: overlay,
      toolbarHeight: toolbarHeight ?? 64,
      bottom: bottom,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
    );
  }
}
