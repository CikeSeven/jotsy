import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

/// 发表时间可选的最早日期，与日历页的可选范围一致。
final DateTime _earliestPublishDate = DateTime(2010, 1, 1);

/// 依次弹出日期、时间选择器，返回新的发表时间（精确到分钟）。
///
/// 发布页与编辑已发布日记共用，约束保持一致：
/// - 日期不能晚于今天；[current] 在未来时（如胶囊提前解封后仍保留原解封
///   时间）从今天开始选；
/// - 日期下限为 2010-01-01，但 [current] 更早（如导入的旧日记）时放宽到
///   [current] 当天，否则选择器初始日期越界会直接断言失败；
/// - 时间固定 24 小时制。
///
/// 任一步取消或 [context] 已卸载时返回 null。选回 [current] 所在的那一分钟
/// 时原样返回 [current]：选择器只到分钟，若换成整分值会抹掉原有秒数，让
/// 调用方把"打开后直接确认"误判为修改。
Future<DateTime?> showPublishTimePicker(
  BuildContext context, {
  required DateTime current,
}) async {
  final local = current.toLocal();
  final currentDate = DateUtils.dateOnly(local);
  final lastDate = DateUtils.dateOnly(DateTime.now());
  final firstDate = currentDate.isBefore(_earliestPublishDate)
      ? currentDate
      : _earliestPublishDate;

  final pickedDate = await showDatePicker(
    context: context,
    initialDate: currentDate.isAfter(lastDate) ? lastDate : currentDate,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: context.l10n.autoT0096,
  );
  if (pickedDate == null || !context.mounted) {
    return null;
  }

  final pickedTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: local.hour, minute: local.minute),
    helpText: context.l10n.autoT0097,
    builder: (BuildContext context, Widget? child) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      );
    },
  );
  if (pickedTime == null || !context.mounted) {
    return null;
  }

  final picked = DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    pickedTime.hour,
    pickedTime.minute,
  );
  final currentMinute = DateTime(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
  );
  return picked == currentMinute ? current : picked;
}
