// 带数量的文案交给原生时的复数形式。
//
// 纪念日的天数要由原生按本机日期现算（应用不在运行时日子照样过），文案却只有
// ARB 里有。这里用每种复数类别的一个代表数去调 ARB 的消息，导出“类别 → 文案”
// 表；原生用 `android.icu.text.PluralRules` 按界面语言给天数挑类别、取文案
// （`WidgetStrings.plural`），数字本身单独绘制或代入 `%d`。
//
// 代表数取自 CLDR 的整数规则；新增界面语言时必须在 [_samples] 登记（测试兜底）。

import '../../../l10n/app_localizations.dart';

/// 每种语言的复数类别 → 一个落在该类别里的整数。俄语没有整数落在 other，
/// 但仍导出 other（取 many 的写法），原生找不到类别时退回它。
const Map<String, Map<String, int>> _samples = <String, Map<String, int>>{
  'en': <String, int>{'one': 1, 'other': 2},
  'ru': <String, int>{'one': 1, 'few': 2, 'many': 5, 'other': 5},
  'zh': <String, int>{'other': 2},
  'ja': <String, int>{'other': 2},
};

/// 已登记复数代表数的语言（测试核对与 `appLanguages` 一致）。
Iterable<String> get homeWidgetPluralLanguages => _samples.keys;

/// 按界面语言导出 [message] 的各复数形式；数量出现在文案里的位置写成 `%d`。
Map<String, String> homeWidgetPluralForms(
  AppLocalizations l10n,
  String Function(int count) message,
) {
  final language = l10n.localeName.split('_').first;
  final samples = _samples[language] ?? const <String, int>{'other': 2};
  return <String, String>{
    for (final entry in samples.entries)
      entry.key: message(entry.value).replaceFirst('${entry.value}', '%d'),
  };
}

/// 原生要用的复数文案（键名与 `WidgetStrings.kt` 一致）。
Map<String, Object?> homeWidgetPluralsOf(
  AppLocalizations l10n,
) => <String, Object?>{
  // 大号数字下方的单位：“天后”“天前”。
  'daysToGo': homeWidgetPluralForms(l10n, l10n.anniversaryDaysToGo),
  'daysAgo': homeWidgetPluralForms(l10n, l10n.anniversaryDaysAgo),
  // 列表行尾的一句话：“还有 12 天”“已经 300 天”。
  'daysLeft': homeWidgetPluralForms(l10n, l10n.anniversaryDaysLeft),
  'daysSince': homeWidgetPluralForms(l10n, l10n.anniversaryDaysSince),
  // 写作统计：连续天数大数字下的单位，热力图下的“最近 N 周”。
  'streakUnit': homeWidgetPluralForms(l10n, l10n.homeWidgetStreakUnit),
  'recentWeeks': homeWidgetPluralForms(l10n, l10n.homeWidgetStatsRecentWeeks),
};
