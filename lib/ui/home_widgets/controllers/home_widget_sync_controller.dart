// 桌面小组件的同步（由 `NodeDiaryApp` 常驻监听，整个应用生命周期只有一份）。
//
// 输入：库表变化（drift `tableUpdates`：本机编辑、局域网同步与导入都会
// 推过来）、功能开关、小组件设置、界面语言、主题色、应用锁，以及应用回到
// 前台（日期可能已经翻过、桌面上的实例可能增删）。每次输入变化防抖
// [_syncDelay] 后跑一次 [_sync]：
//
// 1. 读桌面上的实例，与设置对账（删掉已移除实例的配置、让新实例领走
//    “添加到桌面”时暂存的配置），有变化就写回设置；
// 2. 桌面上没有任何小组件、小组件页也没开着时到此为止——没用小组件的人
//    不付任何代价；
// 3. 构建快照，与上一份比较，相同就不写入、不刷新（编辑日记时每次自动保存
//    都会推表变化，大多不改变小组件上的内容）；不同则写入，并只让用到变化那几节
//    的种类重画（`homeWidgetKindsToRefresh`）；
// 4. 每天第一次同步时为桌面上的种类排好之后 [kHomeWidgetDayHorizon] 个零点的
//    刷新（快速记录另加问候换时段的整点，见 [homeWidgetRedrawTimes]），应用不在
//    运行时日期也照样翻页（原生按本机日期挑快照里的那一天）。
//
// 另外每次同步都顺带发布启动器列表里的生成预览（`HomeWidgetPreviewPublisher`，口径
// 不变就什么都不做），在第 2 步之前，桌面上没有小组件也照常发布。
//
// 同步串行执行：新的输入在上一次同步结束后再跑，不会两次交错写快照。

import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show TableUpdate, TableUpdateQuery;
import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_features.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/home_widgets/home_widget_action.dart';
import '../../../core/services/home_widgets/home_widget_content.dart';
import '../../../core/services/home_widgets/home_widget_gateway.dart';
import '../../../core/services/home_widgets/home_widget_kind.dart';
import '../../../core/services/home_widgets/home_widget_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations_gen.dart';
import '../../calendar/models/calendar_display_options.dart';
import '../../settings/providers/app_features_provider.dart';
import '../providers/home_widget_providers.dart';
import '../viewmodels/home_widget_data_source.dart';
import '../viewmodels/home_widget_snapshot_builder.dart';
import '../viewmodels/home_widget_today_section.dart';
import 'home_widget_actions.dart';
import 'home_widget_preview_publisher.dart';
import 'home_widget_refresh_plan.dart';

/// 防抖（非动画计时）：一次编辑常连着写好几张表。
const Duration _syncDelay = Duration(milliseconds: 800);

final homeWidgetSyncControllerProvider = Provider<HomeWidgetSyncController?>((
  Ref ref,
) {
  final gateway = ref.watch(homeWidgetGatewayProvider);
  final settingsService = ref.watch(settingsServiceProvider).asData?.value;
  if (gateway == null || settingsService == null) return null;
  final database = ref.read(appDatabaseProvider);
  final controller = HomeWidgetSyncController(
    gateway: gateway,
    settingsService: settingsService,
    database: database,
    builder: HomeWidgetSnapshotBuilder(DatabaseHomeWidgetDataSource(database)),
    readFeatures: () => ref.read(appFeaturesProvider),
    readSettings: () => ref.read(homeWidgetSettingsProvider),
    previewing: () => ref.read(homeWidgetPreviewDemandProvider) > 0,
    previewContents: () => <HomeWidgetContent>[
      ?ref.read(homeWidgetPreviewContentProvider),
    ],
    onInstalledChanged: () => ref.invalidate(installedHomeWidgetsProvider),
  );
  ref.onDispose(controller.dispose);
  ref.listen<AppFeatures>(appFeaturesProvider, (_, _) => controller.schedule());
  ref.listen<HomeWidgetSettings>(
    homeWidgetSettingsProvider,
    (_, _) => controller.schedule(),
  );
  ref.listen<HomeWidgetContent?>(
    homeWidgetPreviewContentProvider,
    (_, _) => controller.schedule(),
  );
  ref.listen<int>(homeWidgetPreviewDemandProvider, (int? previous, int next) {
    // 打开小组件页时立即补上全部种类的数据，预览不必等防抖。
    if ((previous ?? 0) == 0 && next > 0) controller.syncNow();
  });
  controller.start();
  return controller;
});

class HomeWidgetSyncController {
  HomeWidgetSyncController({
    required this.gateway,
    required this.settingsService,
    required this.database,
    required this.builder,
    required this.readFeatures,
    required this.readSettings,
    required this.previewing,
    required this.onInstalledChanged,
    this.previewContents = _noContents,
    this.now = DateTime.now,
  });

  static List<HomeWidgetContent> _noContents() => const <HomeWidgetContent>[];

  final HomeWidgetGateway gateway;
  final SettingsService settingsService;
  final AppDatabase database;
  final HomeWidgetSnapshotBuilder builder;
  final AppFeatures Function() readFeatures;
  final HomeWidgetSettings Function() readSettings;
  final bool Function() previewing;
  final VoidCallback onInstalledChanged;

  /// 工作室草稿的内容（见 `homeWidgetPreviewContentProvider`）。
  final List<HomeWidgetContent> Function() previewContents;

  /// 只供测试注入的时钟。
  final DateTime Function() now;

  Timer? _debounce;
  StreamSubscription<Set<TableUpdate>>? _tables;
  AppLifecycleListener? _lifecycle;
  HomeWidgetActionPort? _actions;
  bool _disposed = false;
  bool _dirty = false;
  Future<void> _running = Future<void>.value();

  /// 上一次写入的快照按顶层字段拆开的编码（不含构建时刻），相同就跳过，不同时据此
  /// 决定重画哪些种类。
  Map<String, String>? _lastParts;

  late final HomeWidgetPreviewPublisher _previews = HomeWidgetPreviewPublisher(
    gateway,
  );

  /// 上一次桌面上的实例，变了才通知小组件页重读。
  Set<InstalledHomeWidget> _lastInstalled = const <InstalledHomeWidget>{};

  /// 已经为哪一天、哪些种类排过零点刷新。
  String? _scheduledFor;

  void start() {
    _tables = database
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            database.diaries,
            database.notebooks,
            database.diaryNotebooks,
            // 最近日记可以按标签取。
            database.tags,
            database.diaryTags,
            database.anniversaries,
            database.dayMoods,
            database.todoLists,
            database.todos,
          ]),
        )
        .listen((_) => schedule());
    for (final notifier in _inputs) {
      notifier.addListener(schedule);
    }
    _lifecycle = AppLifecycleListener(onResume: syncNow);
    // 桌面上的操作（点心情脸等）：应用在运行时由后台引擎转回这里，用这条连接
    // 写库；回调本身每次启动都登记一遍（home_widget 只记下句柄，开销很小）。
    _actions = HomeWidgetActionPort(
      (HomeWidgetAction action) => applyHomeWidgetAction(database, action),
    )..open();
    unawaited(
      gateway
          .registerBackgroundCallback(homeWidgetBackgroundCallback)
          .catchError((Object error) {
            debugPrint('home widgets: callback registration failed: $error');
          }),
    );
    schedule();
  }

  /// 会改变快照内容的设置：界面语言、主题色、应用锁、心情符号（月历的平均
  /// 心情）、日历显示选项（一周从哪天开始）。
  List<Listenable> get _inputs => <Listenable>[
    settingsService.localeNotifier,
    settingsService.themeSeedColorNotifier,
    settingsService.appLockEnabledNotifier,
    settingsService.moodOptionsRawNotifier,
    settingsService.calendarDisplayOptionsRawNotifier,
  ];

  /// 防抖后同步。
  void schedule() {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(_syncDelay, syncNow);
  }

  /// 立即同步（排在正在进行的那次之后）。
  Future<void> syncNow() {
    _debounce?.cancel();
    if (_disposed) return Future<void>.value();
    if (_dirty) return _running;
    _dirty = true;
    return _running = _running.then((_) async {
      _dirty = false;
      if (_disposed) return;
      try {
        await _sync();
      } catch (error, stack) {
        debugPrint('home widgets: sync failed: $error\n$stack');
      }
    });
  }

  Future<void> _sync() async {
    final installed = await gateway.installed();
    final installedSet = installed.toSet();
    if (!_sameSet(installedSet, _lastInstalled)) {
      _lastInstalled = installedSet;
      onInstalledChanged();
    }
    final current = now();
    var settings = readSettings();
    final reconciled = settings.reconcile(<int, HomeWidgetKind>{
      for (final widget in installed) widget.widgetId: widget.kind,
    }, current);
    if (reconciled != null) {
      settings = reconciled;
      // 写回后设置 provider 会再触发一次同步，内容相同时被快照比较挡掉。
      await settingsService.setHomeWidgetsRaw(reconciled.encode());
    }
    final l10n = lookupAppLocalizations(settingsService.localeNotifier.value);
    final appSeed = settingsService.themeSeedColorNotifier.value;
    final weekStart = CalendarDisplayOptions.decode(
      settingsService.calendarDisplayOptionsRaw,
    ).weekStart;
    await _previews.publish(
      now: current,
      l10n: l10n,
      appSeed: appSeed,
      weekStart: weekStart,
    );
    final preview = previewing();
    if (installed.isEmpty && !preview) return;

    final kinds = preview
        ? HomeWidgetKind.values.toSet()
        : <HomeWidgetKind>{for (final widget in installed) widget.kind};
    final snapshot = await builder.build(
      HomeWidgetSnapshotInput(
        now: current,
        l10n: l10n,
        appSeed: appSeed,
        features: readFeatures(),
        appLocked: settingsService.isAppLockEnabled,
        settings: settings,
        installed: installed,
        kinds: kinds,
        moodOptions: settingsService.moodOptions,
        weekStart: weekStart,
        previewContents: preview
            ? previewContents()
            : const <HomeWidgetContent>[],
      ),
    );
    if (_disposed) return;
    final parts = homeWidgetSnapshotParts(snapshot);
    final installedKinds = <HomeWidgetKind>{
      for (final widget in installed) widget.kind,
    };
    final previous = _lastParts;
    if (previous == null || !mapEquals(previous, parts)) {
      await gateway.saveSnapshot(
        jsonEncode(<String, Object?>{
          ...snapshot,
          'builtAt': current.millisecondsSinceEpoch,
        }),
      );
      _lastParts = parts;
      for (final kind in homeWidgetKindsToRefresh(
        previous,
        parts,
        installedKinds,
      )) {
        await gateway.refresh(kind);
      }
    }
    await _scheduleRedraws(current, installedKinds);
  }

  Future<void> _scheduleRedraws(
    DateTime current,
    Set<HomeWidgetKind> kinds,
  ) async {
    final names = kinds.map((kind) => kind.id).toList()..sort();
    final key = '${homeWidgetDayKey(current)}|${names.join(',')}';
    if (key == _scheduledFor) return;
    _scheduledFor = key;
    for (final kind in kinds) {
      await gateway.scheduleRefreshes(
        kind,
        homeWidgetRedrawTimes(kind, current),
      );
    }
  }

  void dispose() {
    // 可以重复调用（后台刷新与 provider 销毁各自收尾时都会调）。
    if (_disposed) return;
    _disposed = true;
    _debounce?.cancel();
    unawaited(_tables?.cancel());
    for (final notifier in _inputs) {
      notifier.removeListener(schedule);
    }
    _lifecycle?.dispose();
    _actions?.close();
  }
}

bool _sameSet<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);
