import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:node_diary/core/services/location_resolver_service.dart';

import 'location_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocationTestHarness harness;
  const service = LocationResolverService(webApiKey: 'test-key');

  setUp(() async {
    harness = LocationTestHarness();
    await harness.setUp();
  });
  tearDown(() => harness.tearDown());

  test('首次授权仅使用期间即可获得位置且高精度允许 GPS 参与', () async {
    harness.geolocator.permission = LocationPermission.denied;
    harness.geolocator.requestedPermission = LocationPermission.whileInUse;

    final result = await service.resolveCurrentLocation();

    expect(result.latitude, 31.2304);
    expect(harness.geolocator.permissionRequests, 1);
    final settings = harness.geolocator.settings.single;
    expect(settings.accuracy, LocationAccuracy.high);
    expect(settings.forceLocationManager, isFalse);
    expect(settings.timeLimit, const Duration(seconds: 12));
  });

  test('仅大致位置的低精度坐标仍可获取地址', () async {
    harness.geolocator.currentPosition = (_) async =>
        locationPosition(accuracy: 3000);
    final result = await service.resolveCurrentLocation();
    expect(result.addressComponent['district'], '浦东新区');
    expect(harness.geolocator.permissionRequests, 0);
  });

  for (final permission in [
    LocationPermission.denied,
    LocationPermission.deniedForever,
    LocationPermission.unableToDetermine,
  ]) {
    test('权限 $permission 不可用时不获取位置或请求地址', () async {
      harness.geolocator.permission = permission;
      harness.geolocator.requestedPermission = permission;
      await expectLater(
        service.resolveCurrentLocation(),
        throwsA(
          locationError(
            permission == LocationPermission.deniedForever
                ? LocationResolveErrorType.permissionDeniedForever
                : LocationResolveErrorType.permissionDenied,
          ),
        ),
      );
      expect(
        harness.geolocator.permissionRequests,
        permission == LocationPermission.denied ? 1 : 0,
      );
      expect(harness.geolocator.lastKnownProviders, isEmpty);
      expect(harness.requests, isEmpty);
    });
  }

  test('本次授权被永久拒绝时给出永久拒绝错误', () async {
    harness.geolocator.permission = LocationPermission.denied;
    harness.geolocator.requestedPermission = LocationPermission.deniedForever;
    await expectLater(
      service.resolveCurrentLocation(),
      throwsA(locationError(LocationResolveErrorType.permissionDeniedForever)),
    );
    expect(harness.geolocator.permissionRequests, 1);
    expect(harness.geolocator.settings, isEmpty);
  });

  test('新鲜设备缓存可直接解析地址', () async {
    harness.geolocator.lastKnownPosition = locationPosition(latitude: 32);
    final result = await service.resolveCurrentLocation();
    expect(result.latitude, 32);
    expect(harness.geolocator.settings, isEmpty);
  });

  test('过期缓存不作为当前位置返回', () async {
    harness.geolocator.lastKnownPosition = locationPosition(
      latitude: 32,
      timestamp: DateTime.now().subtract(const Duration(minutes: 6)),
    );
    final result = await service.resolveCurrentLocation();
    expect(result.latitude, 31.2304);
    expect(harness.geolocator.settings, hasLength(1));
  });

  test('缓存读取失败不会阻断实时定位', () async {
    harness.geolocator.readLastKnown = (_) async =>
        throw StateError('No cache');
    final result = await service.resolveCurrentLocation();
    expect(result.latitude, 31.2304);
  });

  for (final error in [
    TimeoutException('Fused provider timed out'),
    const PositionUpdateException('Fused provider unavailable'),
    const LocationServiceDisabledException(),
  ]) {
    test('融合定位失败 $error 后使用 Android 系统定位', () async {
      harness.geolocator.currentPosition = (settings) async {
        if (!settings.forceLocationManager) throw error;
        return locationPosition(latitude: 32);
      };
      final result = await service.resolveCurrentLocation();
      expect(result.latitude, 32);
      expect(harness.geolocator.settings.map((s) => s.forceLocationManager), [
        false,
        true,
      ]);
      final fallback = harness.geolocator.settings.last;
      expect(fallback.accuracy, LocationAccuracy.high);
      expect(fallback.timeLimit, const Duration(seconds: 20));
    });
  }

  test('融合定位失败时可复用另一 provider 的新鲜缓存', () async {
    harness.geolocator.systemLastKnownPosition = locationPosition(latitude: 32);
    harness.geolocator.currentPosition = (_) async =>
        throw TimeoutException('Fused unavailable');
    final result = await service.resolveCurrentLocation();
    expect(result.latitude, 32);
    expect(harness.geolocator.settings, hasLength(1));
    expect(harness.geolocator.lastKnownProviders, [false, true]);
  });

  test('两个 provider 均超时后返回 unavailable 且不无限重试', () async {
    harness.geolocator.currentPosition = (_) async =>
        throw TimeoutException('Unavailable');
    await expectLater(
      service.resolveCurrentLocation(),
      throwsA(locationError(LocationResolveErrorType.unavailable)),
    );
    expect(harness.geolocator.settings, hasLength(2));
    expect(harness.requests, isEmpty);
  });

  for (final invalidPosition in [
    locationPosition(latitude: double.nan),
    locationPosition(longitude: 181),
    locationPosition(timestamp: DateTime.now().add(const Duration(days: 1))),
    locationPosition(
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ]) {
    test('非法或过期的设备坐标被丢弃并尝试系统定位', () async {
      harness.geolocator.lastKnownPosition = invalidPosition;
      harness.geolocator.currentPosition = (settings) async =>
          settings.forceLocationManager ? locationPosition() : invalidPosition;
      final result = await service.resolveCurrentLocation();
      expect(result.latitude, 31.2304);
      expect(harness.geolocator.settings, hasLength(2));
    });
  }

  test('请求途中关闭系统定位不会再等待第二次定位', () async {
    harness.geolocator.currentPosition = (_) async {
      harness.geolocator.serviceEnabled = false;
      throw const LocationServiceDisabledException();
    };
    await expectLater(
      service.resolveCurrentLocation(),
      throwsA(locationError(LocationResolveErrorType.serviceDisabled)),
    );
    expect(harness.geolocator.settings, hasLength(1));
  });

  test('请求途中撤回权限不会重弹权限框或重试定位', () async {
    harness.geolocator.currentPosition = (_) async {
      harness.geolocator.permission = LocationPermission.denied;
      throw const PermissionDeniedException('Revoked');
    };
    await expectLater(
      service.resolveCurrentLocation(),
      throwsA(locationError(LocationResolveErrorType.permissionDenied)),
    );
    expect(harness.geolocator.settings, hasLength(1));
    expect(harness.geolocator.permissionRequests, 0);
  });
}
