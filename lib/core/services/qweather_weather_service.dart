import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

/// 和风天气实时天气查询服务。
class QWeatherWeatherService {
  const QWeatherWeatherService({required this.config});

  final QWeatherConfig config;
  static const Duration _timeout = Duration(seconds: 10);

  Future<QWeatherNow> fetchNow({
    required double latitude,
    required double longitude,
  }) async {
    final host = config.resolvedHost;
    final key = config.apiKey.trim();
    if (host == null || key.isEmpty) {
      throw const QWeatherException(
        type: QWeatherErrorType.missingConfig,
        message: '未配置和风天气参数，请检查 qweather.api_key / qweather.api_host',
      );
    }

    final uri = Uri.https(host, '/v7/weather/now', <String, String>{
      'location': '$longitude,$latitude',
      'lang': 'zh',
      'key': key,
    });

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(_timeout);
      final response = await request.close().timeout(_timeout);
      final body = await response.transform(utf8.decoder).join();
      final decoded = _decodeJson(body);

      if (response.statusCode != HttpStatus.ok) {
        _throwHttpError(decoded, response.statusCode);
      }

      final code = decoded['code']?.toString();
      if (code != '200') {
        throw QWeatherException(
          type: QWeatherErrorType.apiError,
          message: '和风天气接口返回错误（code: ${code ?? 'unknown'}）',
        );
      }

      final now = decoded['now'];
      if (now is! Map) {
        throw const QWeatherException(
          type: QWeatherErrorType.parseError,
          message: '天气数据格式异常（缺少 now 字段）',
        );
      }

      final weatherText = now['text']?.toString().trim();
      final temp = now['temp']?.toString().trim();
      if (weatherText == null ||
          weatherText.isEmpty ||
          temp == null ||
          temp.isEmpty) {
        throw const QWeatherException(
          type: QWeatherErrorType.parseError,
          message: '天气数据缺少关键字段',
        );
      }

      return QWeatherNow(weatherText: weatherText, temperatureCelsius: temp);
    } on TimeoutException catch (error) {
      throw QWeatherException(
        type: QWeatherErrorType.network,
        message: '天气请求超时，请稍后重试',
        cause: error,
      );
    } on SocketException catch (error) {
      throw QWeatherException(
        type: QWeatherErrorType.network,
        message: '网络不可用，无法获取天气',
        cause: error,
      );
    } on FormatException catch (error) {
      throw QWeatherException(
        type: QWeatherErrorType.parseError,
        message: '天气响应无法解析',
        cause: error,
      );
    } finally {
      client.close(force: true);
    }
  }

  Map<String, Object?> _decodeJson(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const QWeatherException(
        type: QWeatherErrorType.parseError,
        message: '天气响应格式异常',
      );
    }
    return <String, Object?>{
      for (final entry in decoded.entries)
        entry.key.toString(): entry.value,
    };
  }

  Never _throwHttpError(Map<String, Object?> decoded, int statusCode) {
    final error = decoded['error'];
    if (error is Map) {
      final type = error['type']?.toString() ?? '';
      if (type.contains('invalid-host')) {
        throw const QWeatherException(
          type: QWeatherErrorType.invalidHost,
          message: '和风天气 API Host 无效，请在 local.properties 配置 qweather.api_host',
        );
      }
      final detail = error['detail']?.toString();
      if (detail != null && detail.trim().isNotEmpty) {
        throw QWeatherException(
          type: QWeatherErrorType.apiError,
          message: '和风天气请求失败：$detail',
        );
      }
    }
    throw QWeatherException(
      type: QWeatherErrorType.apiError,
      message: '和风天气请求失败（HTTP $statusCode）',
    );
  }
}
