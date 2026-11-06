import 'dart:ui';

/// 应用界面支持的语言（设置 → 语言）。
///
/// 这是“界面语言”的唯一清单：设置存储的语言代码、首次启动按系统语言挑选、
/// 语言选择对话框的选项都从这里取。新增语言时在这里加一项，并在
/// `lib/l10n/` 补一份与 `app_en.arb` 键集合一致的 ARB（`tool/check_arb.dart`
/// 与 `app_languages_test.dart` 兜底两边一致）。
///
/// [nativeName] 是该语言的自称（“日本語”“Русский”），在任何界面语言下
/// 都按原文显示，方便看不懂当前界面语言的用户找到自己的语言，所以不进 ARB。
class AppLanguage {
  const AppLanguage(this.code, this.nativeName);

  /// 存储与 [Locale.languageCode] 使用的语言代码（不带地区）。
  final String code;

  /// 语言的自称。
  final String nativeName;

  Locale get locale => Locale(code);
}

/// 语言选择里的顺序即此顺序。
const List<AppLanguage> appLanguages = <AppLanguage>[
  AppLanguage('zh', '中文'),
  AppLanguage('en', 'English'),
  AppLanguage('ja', '日本語'),
  AppLanguage('ru', 'Русский'),
];

/// 不认识的语言一律回落到英文。
const String appFallbackLanguageCode = 'en';

/// 把系统或存储里的语言标记（`zh`、`zh_Hans_CN`、`ja-JP`、` RU `）归一为
/// [appLanguages] 里的语言代码；不支持的语言、空值返回 null，由调用方决定
/// 是继续看下一个系统语言还是回落到 [appFallbackLanguageCode]。
String? normalizeAppLanguageCode(String? raw) {
  final code = raw?.trim().toLowerCase();
  if (code == null || code.isEmpty) {
    return null;
  }
  final language = code.split(RegExp('[-_]')).first;
  for (final entry in appLanguages) {
    if (entry.code == language) {
      return entry.code;
    }
  }
  return null;
}
