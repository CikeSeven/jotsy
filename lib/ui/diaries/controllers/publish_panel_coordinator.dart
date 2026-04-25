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
    required this.capsuleExpandedHeight,
  });

  /// 收起态高度（面板最小可见高度）。
  final double collapsedHeight;

  /// 主页面展开高度。
  final double mainExpandedHeight;

  /// 标签子页展开高度（通常高于主页面）。
  final double tagExpandedHeight;

  /// 时间胶囊子页展开高度，承载日期滚轮与快捷选项。
  final double capsuleExpandedHeight;

  /// smooth_sheets 控制器：负责面板展开/收起吸附动画。
  final SheetController sheetController = SheetController();

  /// 内部分页控制器：主页面 / 标签管理页左右切换。
  final PageController contentPageController = PageController();

  /// 当前展开进度（0=收起，1=展开）。
  double progress = 0;

  /// 当前内页索引（0=主页面，1=标签页，2=时间胶囊页）。
  int contentPageIndex = 0;

  double get activeExpandedHeight {
    return switch (contentPageIndex) {
      1 => tagExpandedHeight,
      2 => capsuleExpandedHeight,
      _ => mainExpandedHeight,
    };
  }

  double get collapsedFactor => collapsedHeight / activeExpandedHeight;
  bool get isExpandedForBackAction => progress > 0.06;
  bool get canPopInnerPage => contentPageIndex > 0;

  /// 收起到最小状态。
  ///
  /// 如果当前在标签子页，会先回到主页面再执行收起。
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

  /// 展开到当前页面的最大状态。
  Future<void> expandToMax() async {
    if (!sheetController.hasClient) {
      return;
    }
    await sheetController.animateTo(
      const SheetOffset(1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  /// 打开标签管理子页。
  Future<void> openTagPage() async {
    await _openInnerPage(1);
  }

  /// 打开时间胶囊设置页。
  Future<void> openCapsulePage() async {
    await _openInnerPage(2);
  }

  Future<void> _openInnerPage(int index) async {
    if (contentPageIndex == index || !contentPageController.hasClients) {
      return;
    }
    await contentPageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  /// 处理内部“返回上一级页面”。
  ///
  /// 返回值为 true 表示已消费返回动作。
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

  /// 同步内页索引，返回值表示索引是否发生变化。
  bool setContentPageIndex(int index) {
    if (contentPageIndex == index) {
      return false;
    }
    contentPageIndex = index;
    return true;
  }

  /// 根据 sheet metrics 同步进度，返回值表示进度是否有变化。
  bool syncProgressFromMetrics(SheetMetrics? metrics) {
    final nextProgress = resolveProgress(metrics);
    if ((nextProgress - progress).abs() < 0.0001) {
      return false;
    }
    progress = nextProgress;
    return true;
  }

  /// 将 smooth_sheets 的因子转换为 0~1 的统一进度。
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

  /// 释放内部控制器资源。
  void dispose() {
    sheetController.dispose();
    contentPageController.dispose();
  }
}
