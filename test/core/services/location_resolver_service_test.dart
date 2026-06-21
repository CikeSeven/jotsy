import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:node_diary/core/services/location_resolver_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GeolocatorPlatform originalPlatform;
  late _FakeGeolocatorPlatform fakeGeolocator;
  late HttpServer server;
  late int requestCount;

  setUp(() async {
    LocationResolverService.debugClearCache();
    originalPlatform = GeolocatorPlatform.instance;
    fakeGeolocator = _FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = fakeGeolocator;
    requestCount = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(
      server.forEach((request) async {
        requestCount += 1;
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'status': '1',
            'regeocode': <String, Object?>{
              'formatted_address': '上海市浦东新区',
              'addressComponent': <String, Object?>{
                'province': '上海市',
                'city': <Object?>[],
                'district': '浦东新区',
                'township': '陆家嘴街道',
              },
            },
          }),
        );
        await request.response.close();
      }),
    );
    HttpOverrides.global = _AmapHttpOverrides(serverPort: server.port);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    HttpOverrides.global = null;
    GeolocatorPlatform.instance = originalPlatform;
    LocationResolverService.debugClearCache();
    await server.close(force: true);
  });

  test('短时间重复定位复用 ResolvedLocation 缓存', () async {
    final service = LocationResolverService(webApiKey: 'test-key');

    final first = await service.resolveCurrentLocation();
    final second = await service.resolveCurrentLocation();

    expect(identical(first, second), isTrue);
    expect(first.township, '陆家嘴街道');
    expect(fakeGeolocator.currentPositionCalls, 1);
    expect(requestCount, 1);
  });

  test('有新鲜 lastKnownPosition 时不触发当前定位', () async {
    fakeGeolocator.lastKnownPosition = _position(
      latitude: 31.2304,
      longitude: 121.4737,
    );
    final service = LocationResolverService(webApiKey: 'another-key');

    final location = await service.resolveCurrentLocation();

    expect(location.latitude, 31.2304);
    expect(fakeGeolocator.currentPositionCalls, 0);
    expect(requestCount, 1);
  });
}

class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  Position? lastKnownPosition;
  var currentPositionCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.always;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.always;

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) {
    return Future<Position?>.value(lastKnownPosition);
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    currentPositionCalls += 1;
    expect(locationSettings?.accuracy, LocationAccuracy.medium);
    return Future<Position>.value(
      _position(latitude: 31.2304, longitude: 121.4737),
    );
  }
}

class _AmapHttpOverrides extends HttpOverrides {
  _AmapHttpOverrides({required this.serverPort});

  final int serverPort;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _AmapRedirectingHttpClient(
      delegate: super.createHttpClient(context),
      serverPort: serverPort,
    );
  }
}

class _AmapRedirectingHttpClient implements HttpClient {
  _AmapRedirectingHttpClient({required this.delegate, required this.serverPort});

  final HttpClient delegate;
  final int serverPort;

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    if (url.host == 'restapi.amap.com') {
      return delegate.getUrl(
        url.replace(
          scheme: 'http',
          host: '127.0.0.1',
          port: serverPort,
        ),
      );
    }
    return delegate.getUrl(url);
  }

  @override
  void close({bool force = false}) => delegate.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Position _position({required double latitude, required double longitude}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.now(),
    accuracy: 100,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}
