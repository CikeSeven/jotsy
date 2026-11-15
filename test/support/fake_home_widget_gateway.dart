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

  /// 登记的后台回调；测试可直接调它模拟桌面上的点按。
  FutureOr<void> Function(Uri? uri)? backgroundCallback;

  @override
  Future<void> registerBackgroundCallback(
    FutureOr<void> Function(Uri? uri) callback,
  ) async => backgroundCallback = callback;

  /// 发布过的生成预览：(示例快照, 口径)。
  final List<(String, String)> publishedPreviews = <(String, String)>[];

  /// 发布生成预览的结果（测试可改成限流或不支持）。
  HomeWidgetPreviewPublish previewOutcome = HomeWidgetPreviewPublish.done;

  @override
  Future<HomeWidgetPreviewPublish> publishPreviews(
    String sample,
    String key,
  ) async {
    publishedPreviews.add((sample, key));
    return previewOutcome;
  }
}
