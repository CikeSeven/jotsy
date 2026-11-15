// home_widget 插件的网关实现（只在 Android 上创建，见
// `homeWidgetGatewayProvider`）。
//
// 快照存进插件的 SharedPreferences（`HomeWidgetPreferences`），原生经
// `HomeWidgetGlanceStateDefinition` 读取；键名与原生 `WidgetSnapshot.KEY`
// 一致，改动须两端同步。
//
// 运行时平台判断留在原生通道旁（AppPlatform 的约定）：widget 测试的目标平台
// 默认是 Android，但宿主上没有这个插件，各方法在那里是空操作。

import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import 'home_widget_gateway.dart';
import 'home_widget_kind.dart';

/// 快照在 `HomeWidgetPreferences` 里的键（原生 `WidgetSnapshot.KEY`）。
const String kHomeWidgetSnapshotKey = 'jotsy.widgets.snapshot';

/// 应用内预览与生成预览的通道（原生 `WidgetPreviewFactory.CHANNEL`）。
const MethodChannel _previewChannel = MethodChannel(
  'com.jotsy.diary/home_widget_preview',
);

class PluginHomeWidgetGateway implements HomeWidgetGateway {
  /// 插件只在真机的 Android 工程里注册。
  static bool get _available => !kIsWeb && Platform.isAndroid;

  @override
  Future<List<InstalledHomeWidget>> installed() async {
    if (!_available) return const <InstalledHomeWidget>[];
    final infos = await HomeWidget.getInstalledWidgets();
    return <InstalledHomeWidget>[
      for (final info in infos)
        if (info.androidWidgetId != null &&
            HomeWidgetKind.byAndroidClassName(info.androidClassName) != null)
          InstalledHomeWidget(
            widgetId: info.androidWidgetId!,
            kind: HomeWidgetKind.byAndroidClassName(info.androidClassName)!,
          ),
    ];
  }

  @override
  Future<void> saveSnapshot(String json) async {
    if (!_available) return;
    await HomeWidget.saveWidgetData<String>(kHomeWidgetSnapshotKey, json);
  }

  @override
  Future<void> refresh(HomeWidgetKind kind) async {
    if (!_available) return;
    await HomeWidget.updateWidget(
      qualifiedAndroidName: kind.qualifiedAndroidName,
    );
  }

  @override
  Future<void> scheduleRefreshes(
    HomeWidgetKind kind,
    List<DateTime> times,
  ) async {
    if (!_available) return;
    await HomeWidget.scheduleWidgetUpdates(
      times,
      qualifiedAndroidName: kind.qualifiedAndroidName,
    );
  }

  @override
  Future<bool> canRequestPin() async {
    if (!_available) return false;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (error) {
      debugPrint('home widgets: pin support check failed: $error');
      return false;
    }
  }

  @override
  Future<void> requestPin(HomeWidgetKind kind) async {
    if (!_available) return;
    await HomeWidget.requestPinWidget(
      qualifiedAndroidName: kind.qualifiedAndroidName,
    );
  }

  @override
  Future<Uri?> initialLaunch() async {
    if (!_available) return null;
    return HomeWidget.initiallyLaunchedFromHomeWidget();
  }

  @override
  Future<void> registerBackgroundCallback(
    FutureOr<void> Function(Uri? uri) callback,
  ) async {
    if (!_available) return;
    await HomeWidget.registerInteractivityCallback(callback);
  }

  @override
  Stream<Uri> get launches => _available
      ? HomeWidget.widgetClicked.where((Uri? uri) => uri != null).cast<Uri>()
      : const Stream<Uri>.empty();

  @override
  Future<HomeWidgetPreviewPublish> publishPreviews(
    String sample,
    String key,
  ) async {
    if (!_available) return HomeWidgetPreviewPublish.unsupported;
    final outcome = await _previewChannel.invokeMethod<String>(
      'publishPreviews',
      <String, Object?>{'sample': sample, 'key': key},
    );
    return switch (outcome) {
      'done' => HomeWidgetPreviewPublish.done,
      'pending' => HomeWidgetPreviewPublish.pending,
      _ => HomeWidgetPreviewPublish.unsupported,
    };
  }
}
