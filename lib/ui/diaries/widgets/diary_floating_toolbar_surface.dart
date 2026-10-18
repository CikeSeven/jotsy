import 'package:flutter/material.dart';

/// 悬浮工具栏的卡片外壳：表面色、18dp 圆角与浮起阴影，并固定图标尺寸。
///
/// 工具按 40dp 一格排布（`resolveDiaryToolbarLayout`），系统字号放大会把
/// 「更多」面板里的说明文字撑出格子，所以卡片内关闭文字缩放。日记编辑页与
/// 模板编辑页共用这一层，两处的工具栏外观一致。
class DiaryFloatingToolbarSurface extends StatelessWidget {
  const DiaryFloatingToolbarSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: IconTheme(data: const IconThemeData(size: 16), child: child),
      ),
    );
  }
}
