import 'dart:async';
import 'dart:convert';

import 'package:node_diary/core/services/home_widgets/home_widget_gateway.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_kind.dart';

/// 不碰插件的桌面小组件网关：桌面上有哪些实例由测试设定，记下写了什么快照、
/// 刷新了哪些种类、排了哪些定时刷新、请求固定了什么；可以模拟点小组件。
class FakeHomeWidgetGateway implements HomeWidgetGateway {
  FakeHomeWidgetGateway({List<InstalledHomeWidget>? installed})
    : installedWidgets = installed ?? <InstalledHomeWidget>[];

  List<InstalledHomeWidget> installedWidgets;
  final List<String> snapshots = <String>[];
  final List<HomeWidgetKind> refreshed = <HomeWidgetKind>[];
  final Map<HomeWidgetKind, List<DateTime>> scheduled =
      <HomeWidgetKind, List<DateTime>>{};
  final List<HomeWidgetKind> pinRequests = <HomeWidgetKind>[];
  bool pinSupported = true;
  Uri? launchUri;
  final StreamController<Uri> _launches = StreamController<Uri>.broadcast();

  /// 最近一次写入的快照（已解码）。
  Map<String, Object?>? get lastSnapshot => snapshots.isEmpty
      ? null
      : (jsonDecode(snapshots.last) as Map).cast<String, Object?>();

  /// 模拟应用在运行时点了小组件。
  void tap(Uri uri) => _launches.add(uri);

  @override
  Future<List<InstalledHomeWidget>> installed() async =>
      List<InstalledHomeWidget>.of(installedWidgets);

  @override
  Future<void> saveSnapshot(String json) async => snapshots.add(json);

  @override
  Future<void> refresh(HomeWidgetKind kind) async => refreshed.add(kind);

  @override
  Future<void> scheduleRefreshes(
    HomeWidgetKind kind,
    List<DateTime> times,
  ) async => scheduled[kind] = times;

  @override
  Future<bool> canRequestPin() async => pinSupported;

  @override
  Future<void> requestPin(HomeWidgetKind kind) async => pinRequests.add(kind);

  @override
  Future<Uri?> initialLaunch() async {
    final uri = launchUri;
    launchUri = null;
    return uri;
  }

  @override
  Stream<Uri> get launches => _launches.stream;
}
