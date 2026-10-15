import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:node_diary/core/services/location_resolver_service.dart';

import 'location_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late LocationTestHarness harness;
  const service = LocationResolverService(webApiKey: ' test-key ');

  setUp(() async {
    harness = LocationTestHarness();
    await harness.setUp();
  });
  tearDown(() => harness.tearDown());

  test('短时间重复定位复用地址缓存且不重复请求权限', () async {
    final first = await service.resolveCurrentLocation();
    final second = await service.resolveCurrentLocation();

    expect(identical(first, second), isTrue);
    expect(first.township, '陆家嘴街道');
    expect(first.addressComponent['streetNumber'], {
      'street': '陆家嘴环路',
      'number': '1号',
    });
    expect(harness.geolocator.settings, hasLength(1));
    expect(harness.geolocator.permissionRequests, 0);
    expect(harness.requests, hasLength(2));
  });

  test('先转换 GPS 坐标再查高德地址而保存坐标保持 WGS84', () async {
    final result = await service.resolveCurrentLocation();

    expect(harness.requests.first.path, '/v3/assistant/coordinate/convert');
    expect(harness.requests.first.queryParameters, {
      'key': 'test-key',
      'locations': '121.473700,31.230400',
      'coordsys': 'gps',
    });
    expect(harness.requests.last.path, '/v3/geocode/regeo');
    expect(
      harness.requests.last.queryParameters['location'],
      '121.478223,31.228458',
    );
    expect(result.latitude, 31.2304);
    expect(result.longitude, 121.4737);
  });

  test('缺少 API key 时不请求权限或访问定位', () async {
    await expectLater(
      const LocationResolverService(webApiKey: ' ').resolveCurrentLocation(),
      throwsA(locationError(LocationResolveErrorType.missingApiKey)),
    );
    expect(harness.geolocator.permissionRequests, 0);
    expect(harness.geolocator.lastKnownProviders, isEmpty);
    expect(harness.requests, isEmpty);
  });

  test('暂不支持的平台不进入设备定位', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await expectLater(
      service.resolveCurrentLocation(),
      throwsA(locationError(LocationResolveErrorType.unsupported)),
    );
    expect(harness.geolocator.lastKnownProviders, isEmpty);
  });

  test('缓存命中前仍检查权限避免撤权后返回位置', () async {
    await service.resolveCurrentLocation();
    harness.geolocator.permission = LocationPermission.deniedForever;
    await expectLater(
      service.resolveCurrentLocation(),
      throwsA(locationError(LocationResolveErrorType.permissionDeniedForever)),
    );
    expect(harness.requests, hasLength(2));
  });

  test('缓存命中前仍检查系统定位开关', () async {
    await service.resolveCurrentLocation();
    harness.geolocator.serviceEnabled = false;
    await expectLater(
      service.resolveCurrentLocation(),
      throwsA(locationError(LocationResolveErrorType.serviceDisabled)),
    );
  });

  test('高德拒绝转换时报告 API 错误且不把 GPS 坐标直接当高德坐标', () async {
    harness.responses['/v3/assistant/coordinate/convert'] = {
      'status': '0',
      'infocode': '10001',
      'info': 'INVALID_USER_KEY',
    };
    await expectLater(
      service.resolveCurrentLocation(),
      throwsA(locationError(LocationResolveErrorType.apiError)),
    );
    expect(harness.requests, hasLength(1));
  });

  for (final coordinates in ['invalid', 'NaN,31', '121,91', '181,31']) {
    test('转换返回非法坐标 $coordinates 时停止解析', () async {
      harness.responses['/v3/assistant/coordinate/convert'] = {
        'status': '1',
        'locations': coordinates,
      };
      await expectLater(
        service.resolveCurrentLocation(),
        throwsA(locationError(LocationResolveErrorType.parseError)),
      );
      expect(harness.requests, hasLength(1));
    });
  }

  test('地址服务返回 HTTP 错误后可以立即重试成功', () async {
    harness.statusCode = HttpStatus.serviceUnavailable;
    await expectLater(
      service.resolveCurrentLocation(),
      throwsA(locationError(LocationResolveErrorType.networkError)),
    );
    harness.statusCode = HttpStatus.ok;
    final result = await service.resolveCurrentLocation();
    expect(result.addressComponent['province'], '上海市');
    expect(harness.requests, hasLength(3));
  });

  for (final badResponse in [
    <Object?>[],
    {'status': '1'},
    {
      'status': '1',
      'regeocode': {'addressComponent': <String, Object?>{}},
    },
    {
      'status': '1',
      'regeocode': {
        'addressComponent': {
          'province': [],
          'city': [],
          'district': '',
          'township': [],
        },
      },
    },
  ]) {
    test('缺失或无效的地址组件不会被当作定位成功', () async {
      harness.responses['/v3/geocode/regeo'] = badResponse;
      await expectLater(
        service.resolveCurrentLocation(),
        throwsA(locationError(LocationResolveErrorType.parseError)),
      );
    });
  }

  test('地址正文断流会超时退出而不是永久等待', () async {
    harness.stallBodyPath = '/v3/geocode/regeo';
    await expectLater(
      service.resolveCurrentLocation(),
      throwsA(locationError(LocationResolveErrorType.networkError)),
    );
    expect(harness.requests, hasLength(2));
  });
}
