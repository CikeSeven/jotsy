import 'package:node_diary/l10n/app_localizations.dart';

/// 精确到分钟的时间格式化工具（用于更新时间展示）。
///
/// 规则：
/// - 同一天：`HH:mm`（示例：`12:22`）
/// - 同一年不同天：`M月d日 HH:mm`（示例：`3月11日 21:30`）
/// - 跨年：`yyyy年 M月d日 HH:mm`（示例：`2013年 3月23日 12:13`）
class PreciseTimeFormatter {
  const PreciseTimeFormatter._();

  static String format({
    required DateTime target,
    required DateTime now,
    required AppLocalizations l10n,
  }) {
    return l10n.formatPreciseDateTime(target, now);
  }
}
