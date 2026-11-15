// 桌面小组件上不打开应用就完成的操作（如今日小组件上点心情脸）。
//
// 原生点按后先改界面（乐观更新），再经 home_widget 的后台回调把
// `jotsy://widget-action/...` 交给 [homeWidgetBackgroundCallback]。两条路径：
// 1. 应用在运行（主 isolate 活着）：经 [IsolateNameServer] 找到主 isolate 登记的
//    端口（[HomeWidgetActionPort]，由同步控制器打开），转交给它用自己的数据库
//    连接写库——Drift 的查询流照常刷新，库表变化随即触发快照重建，两个连接不会
//    同时写库；
// 2. 应用没在运行（或主 isolate 在 [_forwardTimeout] 内没应答）：后台引擎自己
//    打开数据库写入，再按同一套口径重建快照、刷新桌面上的小组件，然后关闭连接。
//
// 写库的口径只有 [applyHomeWidgetAction]；与待办通知的按钮同一种做法
// （`todo_notification_actions.dart`）。

import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_features.dart';
import '../../../core/services/home_widgets/home_widget_action.dart';
import '../../../core/services/home_widgets/home_widget_gateway_plugin.dart';
import '../../../core/services/home_widgets/home_widget_settings.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/todo_reminders/todo_notification_actions.dart';
import '../viewmodels/home_widget_data_source.dart';
import '../viewmodels/home_widget_snapshot_builder.dart';
import 'home_widget_sync_controller.dart';

/// 主 isolate 登记接收端口用的名字。
const String kHomeWidgetActionPortName = 'jotsy.home_widget_actions';

/// 后台引擎等主 isolate 应答的时长（非动画计时）：端口可能是上次进程留下的
/// 死端口，等不到就自己处理。
const Duration _forwardTimeout = Duration(seconds: 3);

/// 主 isolate 一侧：登记接收端口，收到后台转来的操作就交给 [onAction] 并应答。
class HomeWidgetActionPort {
  HomeWidgetActionPort(this.onAction);

  final Future<void> Function(HomeWidgetAction action) onAction;
  ReceivePort? _port;

  void open() {
    if (_port != null) return;
    final port = ReceivePort();
    // 上次进程异常退出可能留下同名登记：先移除再登记。
    IsolateNameServer.removePortNameMapping(kHomeWidgetActionPortName);
    IsolateNameServer.registerPortWithName(
      port.sendPort,
      kHomeWidgetActionPortName,
    );
    port.listen((Object? message) async {
      // [应答端口, 链接原文]，见 _forwardToMainIsolate。
      if (message is! List || message.length != 2) return;
      final reply = message[0];
      final action = HomeWidgetAction.parse(Uri.tryParse('${message[1]}'));
      if (action != null) {
        try {
          await onAction(action);
        } catch (error) {
          debugPrint('home widgets: action failed: $error');
        }
      }
      if (reply is SendPort) reply.send(true);
    });
    _port = port;
  }

  void close() {
    IsolateNameServer.removePortNameMapping(kHomeWidgetActionPortName);
    _port?.close();
    _port = null;
  }
}

/// 后台回调入口（home_widget 在后台引擎里调用）。必须是顶层函数并标
/// `vm:entry-point`，否则 release 构建会被摇树摇掉。
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  final action = HomeWidgetAction.parse(uri);
  if (action == null || uri == null) return;
  if (await _forwardToMainIsolate(uri)) return;

  // 后台引擎里调用别的插件（path_provider、shared_preferences、home_widget）
  // 之前要先注册。
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final database = AppDatabase();
  try {
    final wrote = await applyHomeWidgetAction(database, action);
    // 应用没在运行，提醒调度器不在：完成的这一次剩下的提醒由这里取消（与通知
    // 上的“完成”同一做法）。应用下次运行时调度器再按库里的数据对账。
    if (wrote && action is HomeWidgetCompleteTodoAction) {
      try {
        await cancelTodoOccurrenceNotifications(
          FlutterLocalNotificationsPlugin(),
          todoId: action.todoId,
          occurrence: action.occurrence,
        );
      } catch (error) {
        debugPrint('home widgets: cancelling reminders failed: $error');
      }
    }
    await _refreshFromBackground(database);
  } catch (error, stack) {
    debugPrint('home widgets: background action failed: $error\n$stack');
  } finally {
    await database.close();
  }
}

/// 转交给主 isolate；它在 [_forwardTimeout] 内应答才算交出去了。
Future<bool> _forwardToMainIsolate(Uri uri) async {
  final port = IsolateNameServer.lookupPortByName(kHomeWidgetActionPortName);
  if (port == null) return false;
  final reply = ReceivePort();
  try {
    port.send(<Object?>[reply.sendPort, uri.toString()]);
    return await reply.first.timeout(_forwardTimeout, onTimeout: () => false) ==
        true;
  } finally {
    reply.close();
  }
}

/// 后台写库之后按同一套口径重建快照并刷新桌面上的小组件（应用没在运行，没有
/// 常驻的同步控制器）。
Future<void> _refreshFromBackground(AppDatabase database) async {
  final settings = await SettingsService.create();
  final controller = HomeWidgetSyncController(
    gateway: PluginHomeWidgetGateway(),
    settingsService: settings,
    database: database,
    builder: HomeWidgetSnapshotBuilder(DatabaseHomeWidgetDataSource(database)),
    readFeatures: () =>
        AppFeatures.decode(settings.appFeaturesRawNotifier.value),
    readSettings: () =>
        HomeWidgetSettings.decode(settings.homeWidgetsRawNotifier.value),
    previewing: () => false,
    onInstalledChanged: () {},
  );
  try {
    await controller.syncNow();
  } finally {
    controller.dispose();
  }
}
