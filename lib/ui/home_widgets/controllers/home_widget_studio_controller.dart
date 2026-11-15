// 小组件工作室的编辑状态。
//
// 两种用法：
// - 编辑桌面上已有的实例（[widgetId] 不为空）：每次改动立即更新预览，并在
//   [_saveDelay] 防抖后写回设置——同步控制器随即重建快照，桌面上的小组件
//   跟着变（滑杆拖动期间只改预览，松手才写，见 [commit]）；
// - 设计一个新的（[widgetId] 为空）：只改草稿，点“添加到桌面”时暂存为
//   待领取的配置并请求系统固定（[requestPin]）。
//
// 预览的尺寸与明暗只是看的方式，不写进配置。

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../core/services/home_widgets/home_widget_gateway.dart';
import '../../../core/services/home_widgets/home_widget_settings.dart';
import '../../../core/services/home_widgets/home_widget_style.dart';
import '../../../core/services/settings_service.dart';
import '../models/home_widget_cell_size.dart';
import '../providers/home_widget_providers.dart';

/// 写回设置的防抖（非动画计时）：连续点几个选项只写一次。
const Duration _saveDelay = Duration(milliseconds: 350);

/// 请求固定的结果。
enum HomeWidgetPinResult { requested, unsupported, failed }

class HomeWidgetStudioController extends ChangeNotifier {
  HomeWidgetStudioController({
    required this.settingsService,
    required this.readSettings,
    required HomeWidgetInstance initial,
    this.widgetId,
    this.now = DateTime.now,
  }) : _instance = initial,
       _size = HomeWidgetCellSize.sizesOf(initial.kind).first;

  final SettingsService settingsService;

  /// 读最新的整份设置（写回时只替换自己这一项，不覆盖别处的改动）。
  final HomeWidgetSettings Function() readSettings;

  /// 桌面上的实例 id；为 null 时是在设计一个新的。
  final int? widgetId;

  /// 只供测试注入的时钟。
  final DateTime Function() now;

  HomeWidgetInstance _instance;
  HomeWidgetCellSize _size;
  bool? _previewDark;
  Timer? _save;
  bool _disposed = false;

  HomeWidgetInstance get instance => _instance;
  HomeWidgetStyle get style => _instance.style;
  HomeWidgetContent get content => _instance.content;
  HomeWidgetCellSize get size => _size;
  bool get isNew => widgetId == null;

  /// 预览明暗：null 跟随应用当前的明暗。
  bool? get previewDark => _previewDark;

  bool get isDefault =>
      _instance == HomeWidgetInstance.defaultsFor(_instance.kind);

  set size(HomeWidgetCellSize value) {
    if (value == _size) return;
    _size = value;
    notifyListeners();
  }

  set previewDark(bool? value) {
    if (value == _previewDark) return;
    _previewDark = value;
    notifyListeners();
  }

  /// 改外观。[commit] 为 false 时只改预览（滑杆拖动中）。
  void updateStyle(HomeWidgetStyle style, {bool commit = true}) =>
      _apply(_instance.copyWith(style: style), commit: commit);

  void updateContent(HomeWidgetContent content) =>
      _apply(_instance.copyWith(content: content), commit: true);

  /// 把草稿的当前值写回（滑杆松手时调用）。
  void commit() => _scheduleSave();

  /// 回到该种类的默认配置；返回之前的配置，供撤销。
  HomeWidgetInstance reset() {
    final previous = _instance;
    _apply(HomeWidgetInstance.defaultsFor(_instance.kind), commit: true);
    return previous;
  }

  void restore(HomeWidgetInstance instance) => _apply(instance, commit: true);

  void _apply(HomeWidgetInstance next, {required bool commit}) {
    if (next == _instance) {
      if (commit) _scheduleSave();
      return;
    }
    _instance = next;
    notifyListeners();
    if (commit) _scheduleSave();
  }

  void _scheduleSave() {
    if (widgetId == null || _disposed) return;
    _save?.cancel();
    _save = Timer(_saveDelay, () => unawaited(_flush()));
  }

  Future<void> _flush() async {
    _save?.cancel();
    _save = null;
    final id = widgetId;
    if (id == null) return;
    final settings = readSettings();
    if (settings.instances[id] == _instance) return;
    await saveHomeWidgetSettings(
      settingsService,
      settings.withInstance(id, _instance),
    );
  }

  /// 暂存当前设计并请求系统把小组件添加到桌面。启动器不支持时同样暂存：
  /// 用户照提示手动添加的同类小组件在有效期内领走这份设计。
  Future<HomeWidgetPinResult> requestPin(HomeWidgetGateway gateway) async {
    await saveHomeWidgetSettings(
      settingsService,
      readSettings().withPending(_instance, now()),
    );
    try {
      if (!await gateway.canRequestPin()) {
        return HomeWidgetPinResult.unsupported;
      }
      await gateway.requestPin(_instance.kind);
      return HomeWidgetPinResult.requested;
    } catch (error) {
      debugPrint('home widgets: pin request failed: $error');
      return HomeWidgetPinResult.failed;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    // 离开页面时把还在防抖中的改动写掉，不丢最后一下。
    if (_save != null) unawaited(_flush());
    super.dispose();
  }
}
