// 与系统桌面小组件打交道的网关：Dart 侧只经它读写，测试换成假实现
// （`test/support/fake_home_widget_gateway.dart`）。
//
// 插件实现见 `home_widget_gateway_plugin.dart`（home_widget，只在 Android
// 上有意义，见 `AppPlatform.supportsHomeWidgets`）。

import 'home_widget_kind.dart';

/// 桌面上的一个实例。
class InstalledHomeWidget {
  const InstalledHomeWidget({required this.widgetId, required this.kind});

  /// 启动器分配的 appWidgetId，在这台设备上唯一。
  final int widgetId;
  final HomeWidgetKind kind;

  @override
  bool operator ==(Object other) =>
      other is InstalledHomeWidget &&
      other.widgetId == widgetId &&
      other.kind == kind;

  @override
  int get hashCode => Object.hash(widgetId, kind);
}

abstract class HomeWidgetGateway {
  /// 桌面上现有的实例；认不出种类的实例（旧版本留下的接收器）不在其中。
  Future<List<InstalledHomeWidget>> installed();

  /// 写入快照（JSON 原文）。原生每次绘制时读最新的一份。
  Future<void> saveSnapshot(String json);

  /// 让某个种类的全部实例按最新快照重画。
  Future<void> refresh(HomeWidgetKind kind);

  /// 在这些时刻（通常是之后几天的零点）让某个种类重画一次：应用没在运行时
  /// 日期也照样翻页。传空列表取消。
  Future<void> scheduleRefreshes(HomeWidgetKind kind, List<DateTime> times);

  /// 启动器是否支持从应用里“添加到桌面”（Android 8+，且取决于启动器）。
  Future<bool> canRequestPin();

  /// 请求把一个种类的小组件添加到桌面；系统弹确认框，结果不会回传。
  Future<void> requestPin(HomeWidgetKind kind);

  /// 冷启动时点的是哪个小组件链接（没有则为 null）；只在首次调用时有值。
  Future<Uri?> initialLaunch();

  /// 应用已在运行时点小组件带来的链接。
  Stream<Uri> get launches;
}
