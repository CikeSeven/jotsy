import 'package:flutter/material.dart';

import '../../models/diary_preview_style/diary_preview_style.dart';
import '../../viewmodels/diary_preview_resolved_style.dart';
import 'diary_preview_overlays.dart';

/// 一篇预览的页面外壳：纸色底的 Scaffold、整页主题（配色基调或纸张深浅
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
      backgroundColor: resolved.background,
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
