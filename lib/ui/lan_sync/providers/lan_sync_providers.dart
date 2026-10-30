import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../diaries/controllers/diary_open_flow.dart';
import '../controllers/engine_lan_sync_ui_controller.dart';
import '../controllers/inert_lan_sync_ui_controller.dart';
import '../models/lan_sync_ui_controller.dart';
import 'lan_sync_engine_assembly.dart';

/// 局域网同步界面的控制器（应用生命周期内一份）。
///
/// - 支持局域网同步的平台（`AppPlatform.supportsLanSync`）：
///   [EngineLanSyncUiController] 包着真正的同步引擎（装配见
///   lan_sync_engine_assembly.dart）。provider 同步返回控制器，引擎在后台
///   启动（等设置服务、解析目录、读身份），启动完成之前的行为见控制器文件
///   头注释。应用根组件在启动时就读取它（`NodeDiaryApp`），自动同步与对方的
///   手动同步不依赖用户打开同步页；引擎自己决定什么时候碰网络（没有已配对
///   设备时只在同步页打开期间，docs/lan_sync.md §9）。
/// - 应用前后台：这里挂一个 [AppLifecycleListener]，resumed → 前台，
///   paused / hidden / detached → 后台（[lanSyncForegroundOf]），与控制器
///   同生共死；初值取当前的生命周期（未知时按前台）。
/// - 其他平台（iOS）：不联网的 [InertLanSyncUiController]。
///
/// 测试经 `overrideWithValue` 换成可驱动的假控制器。
final lanSyncControllerProvider = Provider<LanSyncUiController>((Ref ref) {
  if (!AppPlatform.supportsLanSync) {
    final controller = InertLanSyncUiController();
    ref.onDispose(controller.dispose);
    return controller;
  }
  final database = ref.watch(appDatabaseProvider);
  final settings = ref.watch(settingsServiceProvider.future);
  final binding = WidgetsBinding.instance;
  final controller = EngineLanSyncUiController(
    createService: () async =>
        createAppLanSyncService(database: database, settings: await settings),
    platform: currentLanSyncPlatform(),
    foreground: lanSyncForegroundOf(binding.lifecycleState) ?? true,
  );
  final lifecycle = AppLifecycleListener(
    binding: binding,
    onStateChange: (AppLifecycleState state) {
      final foreground = lanSyncForegroundOf(state);
      if (foreground != null) controller.setForeground(foreground);
    },
  );
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(controller.dispose());
  });
  return controller;
});

/// 从同步界面打开一篇日记（完成摘要里的冲突副本）。
typedef LanSyncOpenDiary =
    Future<void> Function(BuildContext context, WidgetRef ref, String diaryId);

/// 打开日记的入口：一律经 `openDiaryPage`（AGENTS.md §6）。做成 provider 只为
/// 测试能换成记录调用的桩，不必真的推入预览页、打开数据库。
final lanSyncOpenDiaryProvider = Provider<LanSyncOpenDiary>(
  (Ref ref) =>
      (BuildContext context, WidgetRef ref, String diaryId) =>
          openDiaryPage(context, ref, diaryId: diaryId),
);
