part of 'qweather_weather_service.dart';

/// 和风天气配置。
class QWeatherConfig {
  const QWeatherConfig({
    required this.apiKey,
    this.credentialId,
    this.apiHost,
  });

  final String apiKey;
  final String? credentialId;
  final String? apiHost;

  String? get resolvedHost {
    final normalizedHost = _normalize(apiHost);
    if (normalizedHost != null) {
      return normalizedHost;
    }
    final normalizedCredentialId = _normalize(credentialId);
    if (normalizedCredentialId == null) {
      return null;
    }
    // 兼容仅提供 Credential ID 的场景，优先尝试常见 Host 形式。
    return '${normalizedCredentialId.toLowerCase()}.qweatherapi.com';
  }

  bool get isValid => _normalize(apiKey) != null && resolvedHost != null;

  static String? _normalize(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

/// 实时天气结果。
class QWeatherNow {
  const QWeatherNow({
    required this.weatherText,
    required this.temperatureCelsius,
  });

  final String weatherText;
  final String temperatureCelsius;

  String get displayText => '$weatherText $temperatureCelsius℃';
}

enum QWeatherErrorType {
  missingConfig,
  invalidHost,
  network,
  apiError,
  parseError,
}

class QWeatherException implements Exception {
  const QWeatherException({
    required this.type,
    required this.message,
    this.cause,
  });

  final QWeatherErrorType type;
  final String message;
  final Object? cause;

  String get userMessage => message;
}
