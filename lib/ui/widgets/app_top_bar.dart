import 'package:flutter/material.dart';

/// 全局统一 AppBar（Material 原生风格）。
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

  @override
  Size get preferredSize {
    final resolvedToolbarHeight = toolbarHeight ?? kToolbarHeight;
    final bottomHeight = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(resolvedToolbarHeight + bottomHeight);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedForeground = foregroundColor ?? colorScheme.onSurface;
    final resolvedBackground = backgroundColor ?? colorScheme.surface;

    return AppBar(
      title: title,
      leading: leading,
      actions: actions,
      centerTitle: centerTitle,
      automaticallyImplyLeading: automaticallyImplyLeading,
      foregroundColor: resolvedForeground,
      backgroundColor: resolvedBackground,
      toolbarHeight: toolbarHeight,
      bottom: bottom,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
    );
  }
}
