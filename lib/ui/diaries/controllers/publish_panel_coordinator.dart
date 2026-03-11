import 'package:flutter/material.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

/// 发布面板状态协调器。
///
/// 负责 smooth_sheets 与内部分页状态同步，集中管理：
/// - 展开/收起吸附进度；
/// - 主页与标签页切换；
/// - 返回键场景下的内页回退与收起判断。
class PublishPanelCoordinator {
  PublishPanelCoordinator({
    required this.collapsedHeight,
    required this.mainExpandedHeight,
    required this.tagExpandedHeight,
  });

  final double collapsedHeight;
  final double mainExpandedHeight;
  final double tagExpandedHeight;

  final SheetController sheetController = SheetController();
  final PageController contentPageController = PageController();

  double progress = 0;
  int contentPageIndex = 0;

  double get activeExpandedHeight =>
      contentPageIndex == 1 ? tagExpandedHeight : mainExpandedHeight;

  double get collapsedFactor => collapsedHeight / activeExpandedHeight;
  bool get isExpandedForBackAction => progress > 0.06;
  bool get canPopInnerPage => contentPageIndex > 0;

  Future<void> collapseToMin() async {
    if (canPopInnerPage) {
      await popInnerPage(animated: false);
    }
    if (!sheetController.hasClient) {
      return;
    }
    await sheetController.animateTo(
      SheetOffset(collapsedFactor),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> openTagPage() async {
    if (contentPageIndex == 1 || !contentPageController.hasClients) {
      return;
    }
    await contentPageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<bool> popInnerPage({bool animated = true}) async {
    if (!canPopInnerPage || !contentPageController.hasClients) {
      return false;
    }
    if (animated) {
      await contentPageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return true;
    }
    contentPageController.jumpToPage(0);
    contentPageIndex = 0;
    return true;
  }

  bool setContentPageIndex(int index) {
    if (contentPageIndex == index) {
      return false;
    }
    contentPageIndex = index;
    return true;
  }

  bool syncProgressFromMetrics(SheetMetrics? metrics) {
    final nextProgress = resolveProgress(metrics);
    if ((nextProgress - progress).abs() < 0.0001) {
      return false;
    }
    progress = nextProgress;
    return true;
  }

  double resolveProgress(SheetMetrics? metrics) {
    if (metrics == null) {
      return 0;
    }
    final range = (metrics.maxOffset - metrics.minOffset).abs();
    if (range <= 0) {
      return 0;
    }
    final raw = (metrics.offset - metrics.minOffset) / range;
    return raw.clamp(0.0, 1.0).toDouble();
  }

  void dispose() {
    sheetController.dispose();
    contentPageController.dispose();
  }
}
