import 'dart:convert';

import 'package:meta/meta.dart';

import 'todo_reminder_planner.dart';

/// 通知上的操作。
enum TodoNotificationAction {
  /// 点开通知本身：打开这条待办。
  open,

  /// “完成”按钮。
  complete,

  /// “稍后提醒”按钮。
  snooze,
}

/// 用户对一条待办通知做了什么（点开或按了按钮）。
@immutable
class TodoNotificationEvent {
  const TodoNotificationEvent({
    required this.action,
    required this.todoId,
    required this.occurrence,
    this.snoozeMinutes = 10,
  });

  final TodoNotificationAction action;
  final String todoId;

  /// 这条通知对应的那一次（截止日 `YYYY-MM-DD`）。
  final String occurrence;

  /// “稍后提醒”的时长（排通知时写进按钮 id，见 [todoNotificationActionId]）。
  final int snoozeMinutes;

  /// 由通知的按钮 id 与 payload 还原；不是待办通知时为 null。
  static TodoNotificationEvent? fromResponse({
    required String? actionId,
    required String? payload,
  }) {
    final decoded = decodeTodoReminderPayload(payload);
    if (decoded == null) return null;
    final action = actionId == null || actionId.isEmpty
        ? TodoNotificationAction.open
        : actionId == kTodoCompleteActionId
        ? TodoNotificationAction.complete
        : actionId.startsWith(kTodoSnoozeActionPrefix)
        ? TodoNotificationAction.snooze
        : TodoNotificationAction.open;
    final minutes = action == TodoNotificationAction.snooze
        ? int.tryParse(actionId!.substring(kTodoSnoozeActionPrefix.length))
        : null;
    return TodoNotificationEvent(
      action: action,
      todoId: decoded.todoId,
      occurrence: decoded.occurrence,
      snoozeMinutes: minutes == null || minutes <= 0 ? 10 : minutes,
    );
  }
}

/// 通知按钮 id。“稍后提醒”把时长写进 id：后台 isolate 处理按钮时不必再去读
/// 设置。
const String kTodoCompleteActionId = 'todo.complete';
const String kTodoSnoozeActionPrefix = 'todo.snooze.';

String todoNotificationActionId(int snoozeMinutes) =>
    '$kTodoSnoozeActionPrefix$snoozeMinutes';

/// 通知里的文案（渠道名、按钮），由调用方按界面语言给出。
@immutable
class TodoNotificationTexts {
  const TodoNotificationTexts({
    required this.channelName,
    required this.channelDescription,
    required this.complete,
    required this.snooze,
    required this.open,
  });

  final String channelName;
  final String channelDescription;
  final String complete;
  final String snooze;

  /// Linux 通知的默认动作名（点按通知本身）。
  final String open;
}

/// 一条要弹出的通知：排好的提醒 + 正文 + 外观选项。
@immutable
class TodoNotificationRequest {
  const TodoNotificationRequest({
    required this.reminder,
    required this.body,
    required this.languageCode,
    required this.snoozeMinutes,
    required this.hideOnLockScreen,
  });

  final PlannedReminder reminder;
  final String body;

  /// 界面语言：后台 isolate 处理“稍后提醒”时按它取文案（那里没有设置）。
  final String languageCode;
  final int snoozeMinutes;
  final bool hideOnLockScreen;

  int get id => reminder.id;

  /// 写进通知的 payload：待办与这一次（见 [encodeTodoReminderPayload]），
  /// 外加语言、锁屏隐藏与内容指纹——标题、正文或外观变了，同一个 id 的通知
  /// 要重排，对账时按指纹判断。
  String get payload {
    final base = reminder.payload;
    final extra = jsonEncode(<String, Object?>{
      'l': languageCode,
      if (hideOnLockScreen) 'h': 1,
      'c': contentHash,
    });
    return '$base|$extra';
  }

  int get contentHash =>
      Object.hash(
        reminder.title,
        body,
        reminder.fireAt.millisecondsSinceEpoch,
        snoozeMinutes,
        hideOnLockScreen,
        languageCode,
      ) &
      0x7fffffff;
}

/// payload 里 [TodoNotificationRequest.payload] 追加的部分。
({String? languageCode, bool hide})? decodeTodoNotificationExtras(
  String? payload,
) {
  if (payload == null) return null;
  final bar = payload.lastIndexOf('|');
  if (bar < 0) return null;
  try {
    final node = jsonDecode(payload.substring(bar + 1));
    if (node is! Map) return null;
    final language = node['l'];
    return (
      languageCode: language is String ? language : null,
      hide: node['h'] == 1,
    );
  } on FormatException {
    return null;
  }
}

/// 系统通知的统一接口：手机交给系统定时（[PluginTodoNotificationGateway]），
/// 桌面在进程里计时（[DesktopTodoNotificationGateway]），测试换成假实现。
///
/// 只碰带待办 payload 前缀的通知（[kTodoReminderPayloadPrefix]），不动别的
/// 通知。所有方法在不支持的平台或插件出错时都不抛出，失败按“没有”处理：
/// 提醒是锦上添花，不能让它把页面或同步带崩。
abstract class TodoNotificationGateway {
  /// 初始化插件、渠道与时区；[onEvent] 收到点开与按钮（应用在运行时）。
  Future<void> initialize({
    required TodoNotificationTexts texts,
    required void Function(TodoNotificationEvent event) onEvent,
  });

  /// 冷启动时是不是点通知打开的应用；是则返回那次点开（只取一次）。
  Future<TodoNotificationEvent?> takeLaunchEvent();

  /// 系统是否允许本应用发通知。
  Future<bool> notificationsEnabled();

  /// 请求发通知的权限（Android 13+ / iOS）；返回是否已允许。
  Future<bool> requestPermission();

  /// 系统是否允许准时的闹钟（Android 12+）；不允许时提醒可能晚几分钟。
  Future<bool> exactAlarmsAllowed();

  /// 已排好的待办通知：id → payload。
  Future<Map<int, String>> pending();

  /// 排一条（同一个 id 已排过则替换）。
  Future<void> schedule(TodoNotificationRequest request);

  Future<void> cancel(int id);
}
