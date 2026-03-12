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

  /// 同年日期显示（用于相对时间回退）。
  ///
  /// 中文示例：`3月12日`
  /// 英文示例：`Mar 12`
  String formatMonthDay(DateTime value) {
    final local = value.toLocal();
    if (isZh) {
      return '${local.month}月${local.day}日';
    }
    return DateFormat('MMM d', localeName).format(local);
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
  /// - 同年不同天：中文 `M月d日 HH:mm`，英文 `MMM d HH:mm`
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
      return '${DateFormat('MMM d', localeName).format(localTarget)} $timePart';
    }

    if (isZh) {
      return '${localTarget.year}年${localTarget.month}月${localTarget.day}日 $timePart';
    }
    return '${DateFormat.yMMMd(localeName).format(localTarget)} $timePart';
  }
}
