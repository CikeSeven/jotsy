import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_languages.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the language picker offers exactly the languages that have an ARB', () {
    expect(
      appLanguages.map((language) => language.code).toList(),
      unorderedEquals(
        AppLocalizations.supportedLocales.map((locale) => locale.languageCode),
      ),
    );
    expect(
      appLanguages.map((language) => language.code),
      contains(appFallbackLanguageCode),
    );
  });

  test('system and stored language tags normalize to a supported code', () {
    expect(normalizeAppLanguageCode('zh_Hans_CN'), 'zh');
    expect(normalizeAppLanguageCode('zh-TW'), 'zh');
    expect(normalizeAppLanguageCode('en_US'), 'en');
    expect(normalizeAppLanguageCode('ja-JP'), 'ja');
    expect(normalizeAppLanguageCode(' RU '), 'ru');
    expect(normalizeAppLanguageCode('fr'), isNull);
    expect(normalizeAppLanguageCode('jav'), isNull);
    expect(normalizeAppLanguageCode(''), isNull);
    expect(normalizeAppLanguageCode(null), isNull);
  });

  group('SettingsService app language', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('stores Japanese and Russian, unknown languages fall back to '
        'English', () async {
      final settings = await SettingsService.create();

      await settings.setAppLocaleCode('ja');
      expect(settings.appLocaleCode, 'ja');
      expect(settings.localeNotifier.value, const Locale('ja'));

      await settings.setAppLocaleCode('ru_RU');
      expect(settings.appLocaleCode, 'ru');
      expect(settings.localeNotifier.value, const Locale('ru'));

      await settings.setAppLocaleCode('fr');
      expect(settings.appLocaleCode, 'en');
    });

    test('a stored Russian locale survives a restart', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app.settings.locale_code': 'ru',
      });
      final settings = await SettingsService.create();
      expect(settings.appLocaleCode, 'ru');
      expect(settings.localeNotifier.value, const Locale('ru'));
    });
  });
}
