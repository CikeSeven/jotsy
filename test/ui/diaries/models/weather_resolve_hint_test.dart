import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/qweather_weather_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/weather_resolve_hint.dart';

void main() {
  final cjk = RegExp(r'[一-鿿]');

  test('every weather error has its own English hint', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final hints = {
      for (final type in QWeatherErrorType.values)
        type: weatherResolveHint(l10n, type),
    };
    expect(hints[QWeatherErrorType.missingConfig], l10n.autoT0205);
    expect(hints.values.toSet(), hasLength(QWeatherErrorType.values.length));
    // 服务层的诊断消息是中文：英文界面不能再出现中文。
    for (final hint in hints.values) {
      expect(hint, isNot(contains(cjk)));
    }
  });

  test('Chinese hints stay Chinese', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    for (final type in QWeatherErrorType.values) {
      expect(weatherResolveHint(l10n, type), contains(cjk));
    }
  });
}
