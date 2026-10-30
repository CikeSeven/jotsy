import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/lan_sync/controllers/engine_lan_sync_ui_controller.dart';
import 'package:node_diary/ui/lan_sync/controllers/inert_lan_sync_ui_controller.dart';
import 'package:node_diary/ui/lan_sync/providers/lan_sync_providers.dart';

/// 控制器的装配：不支持局域网同步的平台给不联网的空实现，支持的平台给
/// 包着引擎的真控制器（引擎在后台启动，测试环境里没有数据目录时启动失败、
/// 控制器保持初始状态且不抛出）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('iOS 不支持局域网同步：给不联网的空实现', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(lanSyncControllerProvider),
      isA<InertLanSyncUiController>(),
    );
  });

  test('Linux 支持局域网同步：同步给出真控制器，初始状态可读', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(lanSyncControllerProvider);
    expect(controller, isA<EngineLanSyncUiController>());
    expect(controller.state.value.peers, isEmpty);
    expect(controller.state.value.local.name, isEmpty);
  });
}
