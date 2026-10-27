import 'package:flutter/material.dart';

import '../../app/theme/app_breakpoints.dart';
import '../../app/theme/app_spacing.dart';
import '../app_surface/widgets/app_page_backdrop.dart';
import '../home/widgets/home_bar/home_top_bar_surface.dart';

/// 探索与设置页的顶栏：铺到状态栏的标题栏，作为页面 Stack 的直接子项叠在
/// 内容之上（因此根节点必须是 [Positioned]）。
///
/// 底由 [HomeTopBarSurface] 画：实色时与原来的 surface 色块完全一致；首页
/// 顶栏用玻璃时换成玻璃，下方滚动的内容从顶栏后透出并被模糊。
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.contentMaxWidth});

  // 与日记列表页头部体感高度对齐，避免 Explore/Settings 看起来偏高。
  static const double contentHeight = 64;

  final String title;

  /// 页面内容列的最大宽度（如 `AppContentWidth.form`）。给出时标题的左右
  /// 留白改为 `AppContentWidth.gutter(宽度, contentMaxWidth)`，与居中的内容
  /// 列左缘对齐；不够宽时就是原来的 16。为 null（默认）时与原来完全一致。
  final double? contentMaxWidth;

  @override
  Widget build(BuildContext context) {
    final topSafeInset = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: HomeTopBarSurface(
        // 实色顶栏：区域设了纯色背景时与背景同色，图片背景时仍是 surface。
        solidColor: AppPageBackdrop.solidBarColorOf(context),
        child: Column(
          children: [
            SizedBox(height: topSafeInset),
            SizedBox(
              height: contentHeight,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final maxWidth = contentMaxWidth;
                  final side = maxWidth == null
                      ? AppSpacing.l
                      : AppContentWidth.gutter(
                          constraints.maxWidth,
                          maxWidth,
                          minGutter: AppSpacing.l,
                        );
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      side,
                      AppSpacing.xs,
                      side,
                      AppSpacing.s,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
