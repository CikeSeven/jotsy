import 'package:flutter/material.dart';

import '../../../app_surface/models/app_surface_enums.dart';
import '../../../app_surface/widgets/app_page_backdrop.dart';
import '../../models/diary_preview_style/diary_preview_style.dart';
import '../../viewmodels/diary_preview_resolved_style.dart';
import 'diary_preview_host.dart';
import 'diary_preview_overlays.dart';

/// 预览页底色与实色顶栏底色（“背景与材质”接入后的取值）。
///
/// 只在纸张“跟随主题”（[DiaryPreviewResolvedStyle.paperFollowsTheme]）且
/// 上方确实画了背景时让位给背景，其余情况都是原来的 [DiaryPreviewResolvedStyle.background]，
/// 所以默认设置下与接入前逐像素一致。背景来自：
/// - 独立预览页：`DiaryPreviewPage` 包的预览区域背景；
/// - 设置页“预览页样式”的实时预览：预览自己包了同一个预览区域背景
///   （`StylePreviewBackground`），按同一规则让位，调样式时看到的就是
///   正式页面的样子；
/// - 宽窗口双栏的右栏（[DiaryPreviewHostScope]）：自己不画背景，透出宿主
///   日记页的背景；
/// - 其他位置（处在别的区域背景之下）不让位。
///
/// 背景是图片时顶栏保持不透明（纸色 / 主题 surface，含配色基调换的主题），
/// 纯色背景时顶栏与页面同色，与无背景时“顶栏 = 页面色”的观感一致。
///
/// 背景把图片遮罩交给页面画时（“背景遮罩随基调染色”，见
/// [diaryPreviewScaffoldColor]）这里的 page 仍是透明：遮罩只由页面 Scaffold
/// 画一次，头图框等按 page 取底色的地方不再叠一层。
({Color page, Color bar}) diaryPreviewPageColors(
  BuildContext context,
  DiaryPreviewResolvedStyle resolved,
) {
  final backdrop = _yieldingBackdrop(context, resolved);
  if (backdrop == null) {
    return (page: resolved.background, bar: resolved.background);
  }
  return (
    page: backdrop.deferredScrim != null
        ? Colors.transparent
        : backdrop.pageColor,
    bar: backdrop.hasImage ? resolved.background : backdrop.solidBarColor,
  );
}

/// 预览页 Scaffold 的底色：通常与 [diaryPreviewPageColors] 的 page 相同。
///
/// 背景交出了图片遮罩时（[AppPageBackdrop.deferredScrim]，预览页开了“背景
/// 遮罩随基调染色”）由 Scaffold 画遮罩：这篇取到了基调颜色时换成染过的
/// 颜色（[DiaryPreviewResolvedStyle.scrimTint]），不透明度沿用背景设置里的
/// 遮罩，深浅不变；取不到时就是背景原来的中性遮罩。遮罩画在每一篇自己的
/// 页面里，左右翻页时各篇的颜色随页面滑动，背景图本身不动。
Color diaryPreviewScaffoldColor(
  BuildContext context,
  DiaryPreviewResolvedStyle resolved,
) {
  final backdrop = _yieldingBackdrop(context, resolved);
  if (backdrop == null) {
    return resolved.background;
  }
  final scrim = backdrop.deferredScrim;
  if (scrim == null) {
    return backdrop.pageColor;
  }
  final tint = resolved.scrimTint;
  return tint == null ? scrim : tint.withValues(alpha: scrim.a);
}

/// 预览页让位给的页面背景；不让位（选了纸色、上方没画背景、处在别的区域
/// 背景之下）时为 null。
AppPageBackdrop? _yieldingBackdrop(
  BuildContext context,
  DiaryPreviewResolvedStyle resolved,
) {
  if (!resolved.paperFollowsTheme) {
    return null;
  }
  final backdrop = AppPageBackdrop.maybeOf(context);
  if (backdrop == null || !backdrop.hasBackground) {
    return null;
  }
  final applies =
      backdrop.area == AppBackgroundArea.preview ||
      DiaryPreviewHostScope.isEmbedded(context);
  return applies ? backdrop : null;
}

/// 一篇预览的页面外壳：纸色底（或让位给页面背景，见 [diaryPreviewPageColors]）
/// 的 Scaffold、整页主题（配色基调或纸张深浅
/// 不同时），以及叠在内容上的阅读进度线、回到顶部与可选的遮罩（导出时的
/// 加载遮罩）。正式页面与设置页的实时预览共用，两处的外观因此一致。
class DiaryPreviewSurface extends StatelessWidget {
  const DiaryPreviewSurface({
    super.key,
    required this.resolved,
    required this.scrollController,
    required this.content,
    this.overlay,
  });

  final DiaryPreviewResolvedStyle resolved;
  final ScrollController scrollController;
  final Widget content;

  /// 铺满整页的最上层（不拦截时应自行 IgnorePointer）。
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final page = resolved.style.page;
    final overlay = this.overlay;
    final scaffold = Scaffold(
      backgroundColor: diaryPreviewScaffoldColor(context, resolved),
      body: SafeArea(
        top: false,
        child: Stack(
          children: <Widget>[
            content,
            // 叠层带 key：开关某一层时其余层的状态不会错位复用。
            if (page.progress == DiaryPreviewProgress.line)
              Positioned(
                key: const ValueKey<String>('progress'),
                top: MediaQuery.paddingOf(context).top,
                left: 0,
                right: 0,
                child: DiaryPreviewProgressLine(controller: scrollController),
              ),
            if (page.backToTop)
              PositionedDirectional(
                key: const ValueKey<String>('backToTop'),
                end: 16,
                bottom: 16,
                child: DiaryPreviewBackToTop(controller: scrollController),
              ),
            if (overlay != null)
              Positioned.fill(
                key: const ValueKey<String>('overlay'),
                child: overlay,
              ),
          ],
        ),
      ),
    );
    // 换了配色基调或纸张深浅时整页换一套主题（见 DiaryPreviewResolvedStyle），
    // 默认样式时 resolved.theme 就是应用主题。始终包这一层：主题在两种之间
    // 切换时组件树结构不变，页面状态（滚动位置、正文控制器）得以保留。
    return Theme(data: resolved.theme, child: scaffold);
  }
}
