import '../../../l10n/app_localizations.dart';

/// 专注时长与倒计时的写法。
abstract final class TodoFocusFormat {
  /// 倒计时：`25:00`，一小时起 `1:05:00`（等宽数字由调用方的字体特性给）。
  static String clock(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final hours = s ~/ 3600;
    final minutes = (s % 3600) ~/ 60;
    final rest = s % 60;
    String two(int value) => value.toString().padLeft(2, '0');
    return hours > 0
        ? '$hours:${two(minutes)}:${two(rest)}'
        : '${two(minutes)}:${two(rest)}';
  }

  /// 累计时长：不到一小时写“N 分钟”，否则“H 小时 M 分”（不到一分钟按 0）。
  static String duration(AppLocalizations l10n, int seconds) {
    final minutes = (seconds < 0 ? 0 : seconds) ~/ 60;
    if (minutes < 60) return l10n.todoFocusMinutes(minutes);
    return l10n.todoFocusHoursMinutes(minutes ~/ 60, minutes % 60);
  }
}
