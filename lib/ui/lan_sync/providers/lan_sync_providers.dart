import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/inert_lan_sync_ui_controller.dart';
import '../models/lan_sync_ui_controller.dart';

/// 局域网同步界面的控制器（应用生命周期内一份）。
///
/// 目前返回不联网的 [InertLanSyncUiController]：没有已配对与附近的设备，开关
/// 只改内存。真正的同步控制器（发现、配对、会话与自动同步）由后续任务在这里
/// 接入；界面只依赖 [LanSyncUiController] 接口，届时不需要改动。测试经
/// `overrideWithValue` 换成可驱动的假控制器。
final lanSyncControllerProvider = Provider<LanSyncUiController>((Ref ref) {
  final controller = InertLanSyncUiController();
  ref.onDispose(controller.dispose);
  return controller;
});
