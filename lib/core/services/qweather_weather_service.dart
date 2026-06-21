import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';

part 'qweather_models.dart';

/// 和风天气实时天气查询服务。
class QWeatherWeatherService {
  const QWeatherWeatherService({required this.config});

  final QWeatherConfig config;
  static const Duration _timeout = Duration(seconds: 10);
  static const Duration _cacheTtl = Duration(minutes: 5);
  static const double _coordinatePrecision = 1000;

  static final Map<_QWeatherCacheKey, _QWeatherCacheEntry> _cache =
      <_QWeatherCacheKey, _QWeatherCacheEntry>{};
  static final Map<_QWeatherCacheKey, Future<QWeatherNow>> _pendingFetches =
      <_QWeatherCacheKey, Future<QWeatherNow>>{};

  @visibleForTesting
  static void debugClearCache() {
    _cache.clear();
    _pendingFetches.clear();
  }

  Future<QWeatherNow> fetchNow({
    required double latitude,
    required double longitude,
    String languageCode = 'zh',
  }) async {
    final host = config.resolvedHost;
    final key = config.apiKey.trim();
    if (host == null || key.isEmpty) {
      throw const QWeatherException(
        type: QWeatherErrorType.missingConfig,
        message: '未配置和风天气参数，请检查 qweather.api_key / qweather.api_host',
      );
    }

    final normalizedLanguage =
        languageCode.toLowerCase().startsWith('zh') ? 'zh' : 'en';
    final cacheKey = _QWeatherCacheKey(
      host: host,
      apiKey: key,
      latitude: latitude,
      longitude: longitude,
      languageCode: normalizedLanguage,
    );
    _evictExpiredCacheEntries();
    final cached = _cache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.now;
    }

    final pending = _pendingFetches[cacheKey];
    if (pending != null) {
      return pending;
    }

    final fetch = _fetchNowFromNetwork(
      host: host,
      key: key,
      normalizedLanguage: normalizedLanguage,
      cacheKey: cacheKey,
    );
    _pendingFetches[cacheKey] = fetch;
    try {
      return await fetch;
    } finally {
      _pendingFetches.remove(cacheKey);
    }
  }

  Future<QWeatherNow> _fetchNowFromNetwork({
    required String host,
    required String key,
    required String normalizedLanguage,
    required _QWeatherCacheKey cacheKey,
  }) async {
    final uri = Uri.https(host, '/v7/weather/now', <String, String>{
      'location': '${cacheKey.longitudeValue},${cacheKey.latitudeValue}',
      'lang': normalizedLanguage,
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
      final weatherIconCode = now['icon']?.toString().trim();
      if (weatherText == null ||
          weatherText.isEmpty ||
          temp == null ||
          temp.isEmpty) {
        throw const QWeatherException(
          type: QWeatherErrorType.parseError,
          message: '天气数据缺少关键字段',
        );
      }

      final result = QWeatherNow(
        weatherText: weatherText,
        temperatureCelsius: temp,
        iconCode:
            (weatherIconCode == null || weatherIconCode.isEmpty)
                ? null
                : weatherIconCode,
      );
      _cache[cacheKey] = _QWeatherCacheEntry(
        now: result,
        expiresAt: DateTime.now().add(_cacheTtl),
      );
      return result;
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

  void _evictExpiredCacheEntries() {
    _cache.removeWhere((_, entry) => entry.isExpired);
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
      for (final entry in decoded.entries) entry.key.toString(): entry.value,
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

class _QWeatherCacheKey {
  _QWeatherCacheKey({
    required this.host,
    required this.apiKey,
    required double latitude,
    required double longitude,
    required this.languageCode,
  }) : latitudeValue =
           (latitude * QWeatherWeatherService._coordinatePrecision).round() /
           QWeatherWeatherService._coordinatePrecision,
       longitudeValue =
           (longitude * QWeatherWeatherService._coordinatePrecision).round() /
           QWeatherWeatherService._coordinatePrecision;

  final String host;
  final String apiKey;
  final double latitudeValue;
  final double longitudeValue;
  final String languageCode;

  @override
  bool operator ==(Object other) {
    return other is _QWeatherCacheKey &&
        other.host == host &&
        other.apiKey == apiKey &&
        other.latitudeValue == latitudeValue &&
        other.longitudeValue == longitudeValue &&
        other.languageCode == languageCode;
  }

  @override
  int get hashCode =>
      Object.hash(host, apiKey, latitudeValue, longitudeValue, languageCode);
}

class _QWeatherCacheEntry {
  const _QWeatherCacheEntry({required this.now, required this.expiresAt});

  final QWeatherNow now;
  final DateTime expiresAt;

  bool get isExpired => !DateTime.now().isBefore(expiresAt);
}
