import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// 定位 + 逆地理解析结果。
class ResolvedLocation {
  const ResolvedLocation({
    required this.latitude,
    required this.longitude,
    required this.addressComponent,
    this.township,
    this.formattedAddress,
  });

  final double latitude;
  final double longitude;
  final String? township;
  final String? formattedAddress;
  final Map<String, Object?> addressComponent;
}

/// 定位异常类型，用于映射可读提示。
enum LocationResolveErrorType {
  unsupported,
  missingApiKey,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  networkError,
  apiError,
  parseError,
  unavailable,
}

/// 定位流程异常。
class LocationResolveException implements Exception {
  const LocationResolveException({
    required this.type,
    required this.message,
    this.cause,
  });

  final LocationResolveErrorType type;
  final String message;
  final Object? cause;

  String get userMessage => message;

  @override
  String toString() {
    if (cause == null) {
      return 'LocationResolveException($type): $message';
    }
    return 'LocationResolveException($type): $message, cause: $cause';
  }
}

/// 发布页定位服务：
/// 1) 获取设备经纬度；
/// 2) 调用高德逆地理编码返回地址组件。
class LocationResolverService {
  const LocationResolverService({required this.webApiKey});

  final String webApiKey;

  static const Duration _networkTimeout = Duration(seconds: 10);

  Future<ResolvedLocation> resolveCurrentLocation() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      throw const LocationResolveException(
        type: LocationResolveErrorType.unsupported,
        message: '当前平台暂不支持自动获取位置',
      );
    }

    if (webApiKey.trim().isEmpty) {
      throw const LocationResolveException(
        type: LocationResolveErrorType.missingApiKey,
        message: '未检测到高德 Web 服务 key，请先配置 amap.web.api.key',
      );
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationResolveException(
        type: LocationResolveErrorType.serviceDisabled,
        message: '定位服务未开启，请先在系统中开启定位',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationResolveException(
        type: LocationResolveErrorType.permissionDenied,
        message: '定位权限被拒绝，无法获取当前位置',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationResolveException(
        type: LocationResolveErrorType.permissionDeniedForever,
        message: '定位权限已被永久拒绝，请在系统设置中手动开启',
      );
    }

    final position = await _getCurrentPosition();
    final regeo = await _reverseGeocode(
      latitude: position.latitude,
      longitude: position.longitude,
    );

    return ResolvedLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      township: regeo.township,
      formattedAddress: regeo.formattedAddress,
      addressComponent: regeo.addressComponent,
    );
  }

  Future<Position> _getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (error) {
      throw LocationResolveException(
        type: LocationResolveErrorType.unavailable,
        message: '无法获取当前位置，请稍后重试',
        cause: error,
      );
    }
  }

  Future<_ReverseGeocodeResult> _reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.https('restapi.amap.com', '/v3/geocode/regeo', <String, String>{
      'key': webApiKey,
      'location': '$longitude,$latitude',
      'extensions': 'base',
    });

    final client = HttpClient();
    try {
      final request = await client.getUrl(uri).timeout(_networkTimeout);
      final response = await request.close().timeout(_networkTimeout);
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != HttpStatus.ok) {
        throw LocationResolveException(
          type: LocationResolveErrorType.networkError,
          message: '地址解析请求失败（HTTP ${response.statusCode}）',
        );
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const LocationResolveException(
          type: LocationResolveErrorType.parseError,
          message: '地址解析返回数据格式异常',
        );
      }

      final status = decoded['status']?.toString();
      if (status != '1') {
        final info = decoded['info']?.toString();
        throw LocationResolveException(
          type: LocationResolveErrorType.apiError,
          message: info == null || info.trim().isEmpty ? '高德地址解析失败' : '高德地址解析失败：$info',
        );
      }

      final regeo = decoded['regeocode'];
      if (regeo is! Map<String, dynamic>) {
        throw const LocationResolveException(
          type: LocationResolveErrorType.parseError,
          message: '地址解析结果缺少字段',
        );
      }

      final rawAddressComponent = regeo['addressComponent'];
      if (rawAddressComponent is! Map) {
        throw const LocationResolveException(
          type: LocationResolveErrorType.parseError,
          message: '地址组件数据缺失',
        );
      }

      final addressComponent = _sanitizeAddressComponent(rawAddressComponent);
      if (addressComponent.isEmpty) {
        throw const LocationResolveException(
          type: LocationResolveErrorType.parseError,
          message: '地址组件数据为空',
        );
      }

      final township = _normalizeOptionalText(addressComponent['township']);
      final formattedAddress = _normalizeOptionalText(regeo['formatted_address']);

      return _ReverseGeocodeResult(
        township: township,
        formattedAddress: formattedAddress,
        addressComponent: addressComponent,
      );
    } on TimeoutException catch (error) {
      throw LocationResolveException(
        type: LocationResolveErrorType.networkError,
        message: '地址解析请求超时，请检查网络后重试',
        cause: error,
      );
    } on SocketException catch (error) {
      throw LocationResolveException(
        type: LocationResolveErrorType.networkError,
        message: '网络不可用，无法解析地址',
        cause: error,
      );
    } on FormatException catch (error) {
      throw LocationResolveException(
        type: LocationResolveErrorType.parseError,
        message: '地址解析结果无法读取',
        cause: error,
      );
    } finally {
      client.close(force: true);
    }
  }

  Map<String, Object?> _sanitizeAddressComponent(Map raw) {
    final output = <String, Object?>{};
    for (final entry in raw.entries) {
      final key = entry.key?.toString();
      if (key == null || key.isEmpty) {
        continue;
      }
      // 遵循产品约束：不保留 street/number 细粒度信息。
      if (key == 'street' || key == 'number' || key == 'streetNumber') {
        continue;
      }
      final value = _sanitizeJsonValue(entry.value);
      if (value != null) {
        output[key] = value;
      }
    }
    return output;
  }

  Object? _sanitizeJsonValue(Object? value) {
    if (value == null || value is num || value is bool || value is String) {
      return value;
    }
    if (value is Map) {
      return _sanitizeAddressComponent(value);
    }
    if (value is List) {
      return value.map(_sanitizeJsonValue).toList(growable: false);
    }
    return value.toString();
  }

  String? _normalizeOptionalText(Object? raw) {
    final normalized = raw?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }
}

class _ReverseGeocodeResult {
  const _ReverseGeocodeResult({
    required this.addressComponent,
    this.township,
    this.formattedAddress,
  });

  final String? township;
  final String? formattedAddress;
  final Map<String, Object?> addressComponent;
}
