import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// 轻量本地化实现（中英文）。
///
/// 当前项目未使用 ARB 代码生成，改为手写映射以减少首版复杂度。
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[Locale('en'), Locale('zh')];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(
      context,
      AppLocalizations,
    );
    return localizations!;
  }

  /// 当前是否为中文环境。
  bool get _isZh => locale.languageCode == 'zh';

  String get appTitle => 'Jotsy';

  String updatedAtLabel(String value) =>
      _isZh ? '更新于 $value' : 'Updated $value';
  String get timeJustNow => _isZh ? '刚刚' : 'Just now';
  String timeMinutesAgo(int minutes) =>
      _isZh ? '$minutes分钟前' : '$minutes min ago';
  String timeHoursAgo(int hours) => _isZh ? '$hours小时前' : '$hours hr ago';
  String timeDaysAgo(int days) => _isZh ? '$days天前' : '$days days ago';
  String formatMonthDay(DateTime dateTime) {
    final local = dateTime.toLocal();
    return _isZh
        ? DateFormat('M月d日', 'zh').format(local)
        : DateFormat('MMM d', 'en').format(local);
  }
  String formatFullDate(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd').format(dateTime.toLocal());
  }
  
}
/// 本地化委托。
class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return locale.languageCode == 'en' || locale.languageCode == 'zh';
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// BuildContext 快捷扩展。
extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
