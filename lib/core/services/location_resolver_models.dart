part of 'location_resolver_service.dart';

/// 定位 + 逆地理解析结果。
class ResolvedLocation {
  const ResolvedLocation({
    required this.latitude,
    required this.longitude,
    required this.addressComponent,
    this.township,
    this.formattedAddress,
  });

  /// 设备原始 WGS84 坐标；高德转换后的坐标只用于地址请求，不落盘。
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

class _ResolvedLocationCacheEntry {
  const _ResolvedLocationCacheEntry({
    required this.location,
    required this.expiresAt,
  });

  final ResolvedLocation location;
  final DateTime expiresAt;
}
