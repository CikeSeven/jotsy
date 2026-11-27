import 'dart:convert';

import 'package:crypto/crypto.dart';
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
    this.androidExact,
  });

  final PlannedReminder reminder;
  final String body;

  /// 界面语言：后台 isolate 处理“稍后提醒”时按它取文案（那里没有设置）。
  final String languageCode;
  final int snoozeMinutes;
  final bool hideOnLockScreen;

  /// Android 闹钟模式，随 payload 保存，权限变化后可以补排系统撤下的闹钟。
  final bool? androidExact;

  int get id => reminder.id;

  /// 写进通知的 payload：待办与这一次（见 [encodeTodoReminderPayload]），
  /// 外加语言、锁屏隐藏与内容指纹——标题、正文或外观变了，同一个 id 的通知
  /// 要重排，对账时按指纹判断。
  String get payload => payloadForAlarmMode(androidExact);

  String payloadForAlarmMode(bool? exact) {
    final extra = jsonEncode(<String, Object?>{
      'l': languageCode,
      if (hideOnLockScreen) 'h': 1,
      if (exact != null) 'a': exact ? 1 : 0,
      'c': _contentHash,
    });
    return '${reminder.payload}|$extra';
  }

  // 指纹跨进程持久化，Object.hash 的随机种子会让重启后的对账全部重排。
  String get _contentHash {
    final content = jsonEncode(<Object?>[
      reminder.title,
      body,
      reminder.fireAt.millisecondsSinceEpoch,
      snoozeMinutes,
    ]);
    return sha256.convert(utf8.encode(content)).toString().substring(0, 16);
  }
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

/// 专注计时通知的 payload 前缀：提醒的对账（`pending` 只认
/// [kTodoReminderPayloadPrefix]）与旧版清理都不碰它。
const String kTodoFocusPayloadPrefix = 'todo-focus:';

/// 专注的倒计时与结束提醒用固定的通知 id：同一时间只有一段计时，再排一次
/// 即替换。提醒的 id 是 31 位哈希，与这两个撞上的概率可以忽略。
const int kTodoFocusCountdownId = 0x7ffffff0;
const int kTodoFocusEndId = 0x7ffffff1;

/// 一段专注 / 休息的通知：倒计时（只在 Android，系统自己走秒）与走完时的
/// 一次提醒。文案由调用方按界面语言给出。
@immutable
class TodoFocusNotice {
  const TodoFocusNotice({
    required this.title,
    required this.endsAt,
    required this.endTitle,
    required this.endBody,
    required this.channelName,
    required this.channelDescription,
  });

  /// 倒计时通知的标题（“专注中 · 写报告”）。
  final String title;

  /// 走完的时刻。
  final DateTime endsAt;
  final String endTitle;
  final String endBody;
  final String channelName;
  final String channelDescription;
}

/// 系统通知的统一接口：手机交给系统定时（[PluginTodoNotificationGateway]），
/// 桌面在进程里计时（[DesktopTodoNotificationGateway]），测试换成假实现。
///
/// 只碰带待办 payload 前缀的通知（[kTodoReminderPayloadPrefix]），不动别的
/// 通知。初始化、读取队列和排程操作的失败由调度器处理，以便保留已有通知
/// 并重试；权限检查的结果直接供设置页显示。
abstract class TodoNotificationGateway {
  /// 初始化插件和通知渠道；[onEvent] 收到点开与按钮（应用在运行时）。
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

  /// 专注计时：Android 常驻一条倒计时通知（系统按 chronometer 走秒，到点
  /// 自己收起），各平台在 [TodoFocusNotice.endsAt] 弹一次“结束了”（手机交给
  /// 系统定时，桌面只在应用运行时）。再调一次即替换。
  Future<void> showFocus(TodoFocusNotice notice);

  /// 撤下专注的倒计时与还没弹出的结束提醒（暂停、提前结束时）。
  Future<void> cancelFocus();
}
