import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'app_platform.dart';

part 'location_device_position.dart';
part 'location_resolver_models.dart';
part 'location_reverse_geocoder.dart';

/// 发布与编辑共用的定位入口：检查前台授权、获取 WGS84 坐标，再解析地址。
/// 短期缓存只在权限与系统开关仍有效时复用；地址失败不写缓存，允许立即重试。
class LocationResolverService {
  const LocationResolverService({required this.webApiKey});

  final String webApiKey;

  static const Duration _resolvedLocationCacheTtl = Duration(minutes: 2);
  static final Map<String, _ResolvedLocationCacheEntry> _resolvedLocationCache =
      <String, _ResolvedLocationCacheEntry>{};

  @visibleForTesting
  static void debugClearCache() => _resolvedLocationCache.clear();

  Future<ResolvedLocation> resolveCurrentLocation() async {
    if (!AppPlatform.supportsAutoLocation) {
      throw const LocationResolveException(
        type: LocationResolveErrorType.unsupported,
        message: 'Automatic location is only supported on Android.',
      );
    }

    final cacheKey = webApiKey.trim();
    if (cacheKey.isEmpty) {
      throw const LocationResolveException(
        type: LocationResolveErrorType.missingApiKey,
        message: 'Missing AMap web service API key.',
      );
    }

    await _DevicePositionResolver.ensureAccess(requestPermission: true);
    final cached = _resolvedLocationCache[cacheKey];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.location;
    }
    _resolvedLocationCache.remove(cacheKey);

    final position = await _DevicePositionResolver.resolve();
    final regeo = await _AmapReverseGeocoder(cacheKey).resolve(position);
    final resolved = ResolvedLocation(
      latitude: position.latitude,
      longitude: position.longitude,
      township: regeo.township,
      formattedAddress: regeo.formattedAddress,
      addressComponent: regeo.addressComponent,
    );
    _resolvedLocationCache[cacheKey] = _ResolvedLocationCacheEntry(
      location: resolved,
      expiresAt: DateTime.now().add(_resolvedLocationCacheTtl),
    );
    return resolved;
  }
}
