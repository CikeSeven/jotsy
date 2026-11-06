import 'dart:math' as math;
import 'dart:ui' as ui show Image;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../widgets/image_viewer_hero.dart';
import '../../../widgets/long_image/long_image_cover_alignment.dart';
import '../../../widgets/long_image/long_image_policy.dart';
import '../../models/diary_preview_style/diary_preview_style.dart';
import '../../viewmodels/diary_preview_resolved_style.dart';
import '../../viewmodels/diary_text_appearance.dart';
import '../diary_image_source.dart';
import '../publish_diary_cover_sliver.dart';
import 'diary_preview_surface.dart';

/// 预览页头图（sliver）：通栏或内嵌的 [PublishDiaryCoverSliver]，是列表封面
/// 共享元素的落点。分享长图期间换成固定高度的静态头图，避免折叠动画在长图
/// 拼接处留下拖影。
class DiaryPreviewCover extends StatelessWidget {
  const DiaryPreviewCover({
    super.key,
    required this.heroTag,
    required this.source,
    required this.resolved,
    required this.staticCover,
    required this.onTap,
    this.placeholder,
  });

  /// 共享元素标签（列表封面飞入的落点、点按进看图页的起点）。
  final Object? heroTag;
  final String source;
  final DiaryPreviewResolvedStyle resolved;
  final bool staticCover;

  /// 列表封面抓取的画面：飞入的落点与解码前的占位。
  final ui.Image? placeholder;
  final ValueChanged<ImageViewerHero?> onTap;

  @override
  Widget build(BuildContext context) {
    if (resolved.coverInColumn) {
      return _buildInColumn(context);
    }
    final geometry = diaryPreviewCoverGeometry(resolved, 0);
    if (staticCover) {
      Widget image = SizedBox(
        width: double.infinity,
        height: resolved.coverHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(color: resolved.background),
          child: _StaticCoverImage(
            source: source,
            height: resolved.coverHeight,
            fill: geometry.fill,
          ),
        ),
      );
      // 内嵌模式（通栏时留边为零；内嵌的上边距总有 4，圆角可能为 0）。
      if (geometry.padding != EdgeInsets.zero) {
        image = Padding(
          padding: geometry.padding,
          child: ClipRRect(borderRadius: geometry.radius, child: image),
        );
      }
      return SliverToBoxAdapter(child: image);
    }
    return PublishDiaryCoverSliver(
      cover: source,
      maxExtentHeight: geometry.extent,
      padding: geometry.padding,
      borderRadius: geometry.radius,
      heroTag: heroTag,
      placeholder: placeholder,
      onTap: onTap,
      // 头图框底色与页面底同源：让位给页面背景时透明，不在背景上留色块。
      background: diaryPreviewPageColors(context, resolved).page,
      fillFrame: geometry.fill,
      collapseEffect: resolved.style.cover.fadeOnScroll,
    );
  }

  /// 宽窗口：头图是正文列里的圆角卡片，左右与标题、正文的文字对齐，铺满
  /// 卡片并裁掉超出部分（长图顶部对齐，规则同 [PublishDiaryCoverSliver] 的
  /// 铺满模式）。头图横跨整个视口宽度的 sliver，所以两侧留白里要算上正文列
  /// 居中后外侧的空白（见 [diaryPreviewCoverGeometry]）。
  Widget _buildInColumn(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (BuildContext context, SliverConstraints constraints) {
        final geometry = diaryPreviewCoverGeometry(
          resolved,
          constraints.crossAxisExtent,
        );
        final height = resolved.coverHeight;
        if (staticCover) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: geometry.padding,
              child: ClipRRect(
                borderRadius: geometry.radius,
                child: SizedBox(
                  width: double.infinity,
                  height: height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: resolved.background),
                    child: _StaticCoverImage(
                      source: source,
                      height: height,
                      fill: true,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
        return PublishDiaryCoverSliver(
          cover: source,
          maxExtentHeight: geometry.extent,
          padding: geometry.padding,
          borderRadius: geometry.radius,
          heroTag: heroTag,
          placeholder: placeholder,
          onTap: onTap,
          background: diaryPreviewPageColors(context, resolved).page,
          fillFrame: true,
          collapseEffect: resolved.style.cover.fadeOnScroll,
        );
      },
    );
  }
}

/// 头图在可用宽度 [width] 下的几何：画面外的留边、圆角、是否铺满裁切，以及
/// 头部总高（含上边距）。预览页的头图 sliver 与阅读式编辑页的头图共用。
///
/// - 手机（[DiaryPreviewResolvedStyle.coverInColumn] 为 false）：通栏贴边、
///   无圆角；内嵌时左右按正文边距、上留 4、按样式圆角。与宽度无关。
/// - 宽窗口：正文列里的圆角卡片，两侧留白算上正文列居中后外侧的空白，上留
///   [DiaryPreviewResolvedStyle.columnCoverTop]，总是铺满。
({EdgeInsets padding, BorderRadius radius, bool fill, double extent})
diaryPreviewCoverGeometry(DiaryPreviewResolvedStyle resolved, double width) {
  final cover = resolved.style.cover;
  if (resolved.coverInColumn) {
    final column = resolved.maxContentWidth ?? width;
    final side =
        math.max(0.0, (width - column) / 2) + resolved.horizontalPadding;
    const top = DiaryPreviewResolvedStyle.columnCoverTop;
    return (
      padding: EdgeInsets.fromLTRB(side, top, side, 0),
      radius: BorderRadius.circular(resolved.columnCoverRadius),
      fill: true,
      // 上边距包在头部高度里（与内嵌模式一致），画面本身仍是 coverHeight 高。
      extent: resolved.coverHeight + top,
    );
  }
  final inset = cover.mode == DiaryPreviewCoverMode.inset;
  return (
    padding: inset
        ? EdgeInsets.fromLTRB(
            resolved.horizontalPadding,
            4,
            resolved.horizontalPadding,
            0,
          )
        : EdgeInsets.zero,
    radius: inset ? BorderRadius.circular(cover.radius) : BorderRadius.zero,
    fill: cover.fit == DiaryPreviewCoverFit.cover,
    extent: resolved.coverHeight,
  );
}

/// 分享长图用的静态头图：不淡入（截图不等解码，淡入中途会截到半透明）。
class _StaticCoverImage extends StatelessWidget {
  const _StaticCoverImage({
    required this.source,
    required this.height,
    required this.fill,
  });

  final String source;
  final double height;
  final bool fill;

  @override
  Widget build(BuildContext context) {
    // 按头图框高度与设备像素比换算解码上限，避免把原图整张解码进内存
    // （多图日记内存峰值会明显升高）。
    // 长图与在线头图一样顶部对齐，长图截到的画面与屏幕上一致。
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final provider = boundedImageProvider(
      diaryImageProvider(source),
      height: (height * dpr).round(),
    );
    return LongImageCoverAlignment(
      image: provider,
      builder: (BuildContext context, AlignmentGeometry alignment) => Image(
        image: provider,
        fit: fill ? BoxFit.cover : BoxFit.contain,
        alignment: alignment,
        width: fill ? double.infinity : null,
        height: fill ? double.infinity : null,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// 预览页标题（sliver）：以 headlineSmall 为基准按样式缩放字号、设字重、
/// 对齐与颜色；字体跟随正文字体设置（[DiaryTextAppearance.titleStyle]）。
class DiaryPreviewTitle extends StatelessWidget {
  const DiaryPreviewTitle({
    super.key,
    required this.title,
    required this.appearance,
    required this.resolved,
    required this.topPadding,
  });

  final String title;
  final DiaryTextAppearance appearance;
  final DiaryPreviewResolvedStyle resolved;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return DiaryPreviewSection(
      resolved: resolved,
      top: topPadding,
      child: Text(
        title,
        textAlign: diaryPreviewTitleAlign(resolved.style.title),
        style: diaryPreviewTitleTextStyle(context, resolved, appearance),
      ),
    );
  }
}

/// 预览标题的文字样式：以 headlineSmall 为基准按样式缩放字号、设字重与
/// 颜色，字体跟随正文字体设置。预览页标题与阅读式编辑页的标题输入框共用，
/// 两处的标题因此一模一样。
TextStyle? diaryPreviewTitleTextStyle(
  BuildContext context,
  DiaryPreviewResolvedStyle resolved,
  DiaryTextAppearance appearance,
) {
  final style = resolved.style.title;
  final base = Theme.of(context).textTheme.headlineSmall;
  final weight = switch (style.weight) {
    DiaryPreviewTitleWeight.regular => FontWeight.w400,
    DiaryPreviewTitleWeight.medium => FontWeight.w500,
    DiaryPreviewTitleWeight.bold => FontWeight.w700,
    DiaryPreviewTitleWeight.heavy => FontWeight.w800,
  };
  final fontSize = base?.fontSize;
  final scaled = base?.copyWith(
    fontWeight: weight,
    fontSize: style.scale == 1 || fontSize == null
        ? null
        : fontSize * style.scale,
    color: resolved.titleColor,
  );
  return appearance.titleStyle(scaled);
}

/// 预览标题的对齐：居中时为 [TextAlign.center]，靠左时为 null（跟随书写
/// 方向）。
TextAlign? diaryPreviewTitleAlign(DiaryPreviewTitleStyle style) =>
    style.align == DiaryPreviewAlign.center ? TextAlign.center : null;

/// 标题区与正文之间的分隔线（sliver）：横跨正文列（左右边距与正文相同），
/// 粗 [thickness]，颜色见 [DiaryPreviewResolvedStyle.titleDividerColor]。上方
/// 留 [top]（标题区下缘到线），线到正文的距离由正文区的上边距给出。
class DiaryPreviewTitleDivider extends StatelessWidget {
  const DiaryPreviewTitleDivider({
    super.key,
    required this.resolved,
    required this.top,
  });

  /// 与正文里的分隔线块同粗（DESIGN §3.2 的 1dp 细线）。
  static const double thickness = 1;

  final DiaryPreviewResolvedStyle resolved;
  final double top;

  @override
  Widget build(BuildContext context) {
    return DiaryPreviewSection(
      resolved: resolved,
      top: top,
      child: line(resolved),
    );
  }

  /// 分隔线本身（不含留边），阅读式编辑页的页头也用它。
  static Widget line(DiaryPreviewResolvedStyle resolved) => SizedBox(
    width: double.infinity,
    height: thickness,
    child: ColoredBox(color: resolved.titleDividerColor),
  );
}

/// 预览页里的一段内容（sliver）：左右按样式留边，开启“限制正文宽度”时在
/// 宽屏上居中排到最大宽度。
class DiaryPreviewSection extends StatelessWidget {
  const DiaryPreviewSection({
    super.key,
    required this.resolved,
    required this.child,
    this.top = 0,
    this.bottom = 0,
  });

  final DiaryPreviewResolvedStyle resolved;
  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: DiaryPreviewColumn(
        resolved: resolved,
        top: top,
        bottom: bottom,
        child: child,
      ),
    );
  }
}

/// [DiaryPreviewSection] 的盒子版本：左右按样式留边，开启“限制正文宽度”
/// 时在宽屏上居中排到最大宽度。不在 sliver 里的阅读版式（阅读式编辑页的
/// 页头与页尾）用它与预览页对齐。
class DiaryPreviewColumn extends StatelessWidget {
  const DiaryPreviewColumn({
    super.key,
    required this.resolved,
    required this.child,
    this.top = 0,
    this.bottom = 0,
  });

  final DiaryPreviewResolvedStyle resolved;
  final Widget child;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final padded = Padding(
      padding: EdgeInsets.fromLTRB(
        resolved.horizontalPadding,
        top,
        resolved.horizontalPadding,
        bottom,
      ),
      child: child,
    );
    final maxWidth = resolved.maxContentWidth;
    return maxWidth == null
        ? padded
        // 定宽而不是只限最大宽度：Align 放松了约束，标题这类短内容会缩成
        // 自身宽度再被居中，不再与正文左对齐。maxContentWidth 只在比可用
        // 宽度窄时给出，定宽不会溢出。
        : Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: maxWidth, child: padded),
          );
  }
}
