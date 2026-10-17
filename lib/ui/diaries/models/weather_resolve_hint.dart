import 'package:node_diary/core/services/qweather_weather_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';

/// 天气服务的异常消息是写给开发者的中文诊断，界面只展示当前语言下可操作
/// 的提示（同 locationResolveHint）。
String weatherResolveHint(AppLocalizations l10n, QWeatherErrorType type) =>
    switch (type) {
      QWeatherErrorType.missingConfig => l10n.autoT0205,
      QWeatherErrorType.invalidHost => l10n.weatherInvalidHost,
      QWeatherErrorType.network => l10n.weatherNetworkError,
      QWeatherErrorType.apiError => l10n.weatherApiError,
      QWeatherErrorType.parseError => l10n.weatherParseError,
    };
