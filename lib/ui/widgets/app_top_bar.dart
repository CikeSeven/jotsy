import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../app/theme/app_breakpoints.dart';

/// Expressive 紧凑标题栏；统一 64dp 高度和默认返回图标，业务动作由页面注入。
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = colorScheme.brightness == Brightness.light;
    final resolvedForeground = foregroundColor ?? colorScheme.onSurface;
    final resolvedBackground = backgroundColor ?? colorScheme.surface;
    final resolvedOverlay =
        systemOverlayStyle ??
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

    final appBar = AppBar(
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
      foregroundColor: resolvedForeground,
      backgroundColor: resolvedBackground,
      systemOverlayStyle: resolvedOverlay,
      toolbarHeight: toolbarHeight ?? 64,
      bottom: bottom,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
    );
    final maxWidth = contentMaxWidth;
    if (maxWidth == null) {
      return appBar;
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.hasBoundedWidth) {
          return appBar;
        }
        final inset =
            AppContentWidth.gutter(constraints.maxWidth, maxWidth) - 16;
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
}
