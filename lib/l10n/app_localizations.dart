import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'app_localizations_gen.dart';

export 'app_localizations_gen.dart';

/// BuildContext 到本地化实例的快捷扩展。
///
/// 统一在 UI 层使用 `context.l10n` 读取文案，避免各处重复调用
/// `AppLocalizations.of(context)` 并减少空值判断样板代码。
extension BuildContextL10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// 项目级本地化工具扩展。
///
/// 这些方法属于“视图层格式化能力”，用于保持各页面时间与文案回退策略一致。
extension AppLocalizationsProjectX on AppLocalizations {
  /// 是否当前为中文语言环境。
  bool get isZh => localeName.toLowerCase().startsWith('zh');

  /// 精确到分钟的日期时间（发布时间、胶囊解封时间等）。
  ///
  /// 格式模板来自 ARB（`dateTimeMinutePattern`），新增语言只需补文案。
  /// 中文示例：`2026年03月12日 09:05`；英文示例：`2026-03-12 09:05`
  String formatDateTimeMinute(DateTime value) =>
      DateFormat(dateTimeMinutePattern, localeName).format(value.toLocal());

  /// 同年日期显示（用于相对时间回退）。
  ///
  /// 中文示例：`3月12日`；英文示例：`Mar 12`；其他语言按 intl 的 `MMMd`
  /// 骨架（日文 `3月12日`、俄文 `12 мар.`），不手写图案，字段顺序由各语言
  /// 自己决定。
  String formatMonthDay(DateTime value) {
    final local = value.toLocal();
    if (isZh) {
      return '${local.month}月${local.day}日';
    }
    return DateFormat.MMMd(localeName).format(local);
  }

  /// 跨年日期显示（用于相对时间回退）。
  ///
  /// 中文示例：`2026年3月12日`
  /// 英文示例：`Mar 12, 2026`
  String formatFullDate(DateTime value) {
    final local = value.toLocal();
    if (isZh) {
      return '${local.year}年${local.month}月${local.day}日';
    }
    return DateFormat.yMMMd(localeName).format(local);
  }

  /// 精确到分钟的时间格式（用于“最后编辑于”）。
  ///
  /// 规则：
  /// - 同一天：`HH:mm`
  /// - 同年不同天：中文 `M月d日 HH:mm`，其他语言 `MMMd` 骨架 + `HH:mm`
  /// - 跨年：中文 `yyyy年M月d日 HH:mm`，英文 `yMMMd HH:mm`
  String formatPreciseDateTime(DateTime target, DateTime now) {
    final localTarget = target.toLocal();
    final localNow = now.toLocal();
    final timePart = DateFormat('HH:mm', localeName).format(localTarget);

    final isSameDay =
        localTarget.year == localNow.year &&
        localTarget.month == localNow.month &&
        localTarget.day == localNow.day;
    if (isSameDay) {
      return timePart;
    }

    final isSameYear = localTarget.year == localNow.year;
    if (isSameYear) {
      if (isZh) {
        return '${localTarget.month}月${localTarget.day}日 $timePart';
      }
      return '${DateFormat.MMMd(localeName).format(localTarget)} $timePart';
    }

    if (isZh) {
      return '${localTarget.year}年${localTarget.month}月${localTarget.day}日 $timePart';
    }
    return '${DateFormat.yMMMd(localeName).format(localTarget)} $timePart';
  }

  /// 文件大小（1024 进制，最多一位小数）：`512 B`、`49 MB`、`1.5 GB`。
  String formatByteSize(num bytes) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${NumberFormat('0.#', localeName).format(value)} ${units[unit]}';
  }

  /// 杂志眉线日期格式化（如：10月5日 · 周一 / Oct 5 · Mon / 10月5日 · 月）。
  ///
  /// 非中文按 intl 骨架拼：日期取 `MMMd` / `yMMMd`（英文与改版前的
  /// `MMM d` / `MMM d, yyyy` 一致），星期取缩写 `E`，中间固定 ` · `。
  String formatEyebrowDate(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final isSameYear = local.year == now.year;
    if (isZh) {
      final weekdayStr = switch (local.weekday) {
        DateTime.monday => '周一',
        DateTime.tuesday => '周二',
        DateTime.wednesday => '周三',
        DateTime.thursday => '周四',
        DateTime.friday => '周五',
        DateTime.saturday => '周六',
        DateTime.sunday => '周日',
        _ => '',
      };
      if (isSameYear) {
        return '${local.month}月${local.day}日 · $weekdayStr';
      }
      return '${local.year}年${local.month}月${local.day}日 · $weekdayStr';
    }
    final date = isSameYear
        ? DateFormat.MMMd(localeName).format(local)
        : DateFormat.yMMMd(localeName).format(local);
    return '$date · ${DateFormat.E(localeName).format(local)}';
  }
}
