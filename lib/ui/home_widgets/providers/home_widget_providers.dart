import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/home_widgets/home_widget_gateway.dart';
import '../../../core/services/home_widgets/home_widget_gateway_plugin.dart';
import '../../../core/services/home_widgets/home_widget_launch.dart';
import '../../../core/services/home_widgets/home_widget_settings.dart';
import '../../../core/services/settings_service.dart';

/// 与系统桌面小组件打交道的网关；不支持的平台为 null（所有入口与同步都
/// 跟着不出现）。测试换成假实现。
final homeWidgetGatewayProvider = Provider<HomeWidgetGateway?>((Ref ref) {
  if (!AppPlatform.supportsHomeWidgets) return null;
  return PluginHomeWidgetGateway();
});

/// 小组件设置。同步 Notifier：设置就绪前为空设置；小组件页与工作室写入后
/// 经 raw notifier 推过来，按编码结果去重。
final homeWidgetSettingsProvider =
    NotifierProvider<HomeWidgetSettingsNotifier, HomeWidgetSettings>(
      HomeWidgetSettingsNotifier.new,
    );

class HomeWidgetSettingsNotifier extends Notifier<HomeWidgetSettings> {
  String? _raw;

  @override
  HomeWidgetSettings build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) return HomeWidgetSettings.empty;
    final rawNotifier = settings.homeWidgetsRawNotifier;
    void listener() {
      if (rawNotifier.value == _raw) return;
      _raw = rawNotifier.value;
      state = HomeWidgetSettings.decode(_raw);
    }

    rawNotifier.addListener(listener);
    ref.onDispose(() => rawNotifier.removeListener(listener));
    _raw = rawNotifier.value;
    return HomeWidgetSettings.decode(_raw);
  }
}

/// 保存小组件设置（整份写入）。
Future<void> saveHomeWidgetSettings(
  SettingsService settings,
  HomeWidgetSettings value,
) => settings.setHomeWidgetsRaw(value.encode());

/// 桌面上现有的实例。启动器不会主动通知增删，小组件页打开时、回到前台时
/// 由同步控制器 `invalidate` 重新读取。
final installedHomeWidgetsProvider = FutureProvider<List<InstalledHomeWidget>>((
  Ref ref,
) async {
  final gateway = ref.watch(homeWidgetGatewayProvider);
  if (gateway == null) return const <InstalledHomeWidget>[];
  try {
    return await gateway.installed();
  } catch (_) {
    // 读不到（插件异常）就当桌面上没有，小组件页照常显示组件库。
    return const <InstalledHomeWidget>[];
  }
});

/// 点小组件要打开的目标；首页消费后置回 null（冷启动时请求先于首页到达，
/// 首页经 `fireImmediately` 接住，同待办通知）。
final homeWidgetLaunchRequestProvider =
    NotifierProvider<HomeWidgetLaunchRequest, HomeWidgetLaunch?>(
      HomeWidgetLaunchRequest.new,
    );

class HomeWidgetLaunchRequest extends Notifier<HomeWidgetLaunch?> {
  @override
  HomeWidgetLaunch? build() => null;

  void request(HomeWidgetLaunch launch) => state = launch;

  void consume() => state = null;
}

/// 小组件页 / 工作室打开着的层数。大于 0 时快照为全部种类计算数据节，
/// 预览里还没放到桌面上的种类也有真实数据可画。
final homeWidgetPreviewDemandProvider =
    NotifierProvider<HomeWidgetPreviewDemand, int>(HomeWidgetPreviewDemand.new);

class HomeWidgetPreviewDemand extends Notifier<int> {
  @override
  int build() => 0;

  // 进出页面的调用挪到了帧回调里（见 HomeWidgetPreviewDemandMixin），那时整个
  // ProviderScope 可能已经随应用退出销毁：已销毁就什么也不做。
  void open() {
    if (ref.mounted) state++;
  }

  void close() {
    if (ref.mounted && state > 0) state--;
  }
}
