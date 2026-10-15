import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:node_diary/core/services/location_resolver_service.dart';

/// 隔离系统定位和外网；两个地址接口都保留真实 HTTP 编解码流程。
class LocationTestHarness {
  final geolocator = FakeLocationPlatform();
  final requests = <Uri>[];
  final responses = <String, Object?>{
    '/v3/assistant/coordinate/convert': {
      'status': '1',
      'locations': '121.478223,31.228458',
    },
    '/v3/geocode/regeo': {
      'status': '1',
      'regeocode': {
        'formatted_address': '上海市浦东新区',
        'addressComponent': {
          'province': '上海市',
          'city': <Object?>[],
          'district': '浦东新区',
          'township': '陆家嘴街道',
          'streetNumber': {
            'street': '陆家嘴环路',
            'number': '1号',
            'location': '121.499718,31.239703',
            'direction': '东北',
            'distance': '23.4',
          },
        },
      },
    },
  };
  int statusCode = HttpStatus.ok;
  String? stallBodyPath;

  late HttpServer _server;
  late GeolocatorPlatform _originalPlatform;
  HttpOverrides? _originalHttpOverrides;
  TargetPlatform? _originalTarget;

  Future<void> setUp() async {
    LocationResolverService.debugClearCache();
    _originalPlatform = GeolocatorPlatform.instance;
    _originalHttpOverrides = HttpOverrides.current;
    _originalTarget = debugDefaultTargetPlatformOverride;
    GeolocatorPlatform.instance = geolocator;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) => unawaited(_respond(request)));
    HttpOverrides.global = _AmapHttpOverrides(serverPort: _server.port);
  }

  Future<void> _respond(HttpRequest request) async {
    requests.add(request.uri);
    final response = request.response;
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    if (request.uri.path == stallBodyPath) {
      response.write('{');
      await response.flush();
      // 模拟响应头已到达、正文始终未完成的服务器。
      return;
    }
    response.write(jsonEncode(responses[request.uri.path]));
    await response.close();
  }

  Future<void> tearDown() async {
    HttpOverrides.global = _originalHttpOverrides;
    GeolocatorPlatform.instance = _originalPlatform;
    debugDefaultTargetPlatformOverride = _originalTarget;
    LocationResolverService.debugClearCache();
    await _server.close(force: true);
  }
}

class FakeLocationPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  int permissionRequests = 0;
  Position? lastKnownPosition;
  Position? systemLastKnownPosition;
  final settings = <AndroidSettings>[];
  final lastKnownProviders = <bool>[];
  Future<Position> Function(AndroidSettings)? currentPosition;
  Future<Position?> Function(bool)? readLastKnown;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests += 1;
    permission = requestedPermission;
    return permission;
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    lastKnownProviders.add(forceLocationManager);
    if (readLastKnown != null) return readLastKnown!(forceLocationManager);
    return forceLocationManager ? systemLastKnownPosition : lastKnownPosition;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    final androidSettings = locationSettings! as AndroidSettings;
    settings.add(androidSettings);
    if (currentPosition != null) return currentPosition!(androidSettings);
    return locationPosition();
  }
}

class _AmapHttpOverrides extends HttpOverrides {
  _AmapHttpOverrides({required this.serverPort});

  final int serverPort;

  @override
  HttpClient createHttpClient(SecurityContext? context) => _AmapHttpClient(
    delegate: super.createHttpClient(context),
    serverPort: serverPort,
  );
}

class _AmapHttpClient implements HttpClient {
  _AmapHttpClient({required this.delegate, required this.serverPort});

  final HttpClient delegate;
  final int serverPort;

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    if (url.host != 'restapi.amap.com') {
      throw StateError('Unexpected external location request: ${url.host}');
    }
    return delegate.getUrl(
      url.replace(scheme: 'http', host: '127.0.0.1', port: serverPort),
    );
  }

  @override
  void close({bool force = false}) => delegate.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Position locationPosition({
  double latitude = 31.2304,
  double longitude = 121.4737,
  DateTime? timestamp,
  double accuracy = 100,
}) => Position(
  latitude: latitude,
  longitude: longitude,
  timestamp: timestamp ?? DateTime.now(),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

Matcher locationError(LocationResolveErrorType type) =>
    isA<LocationResolveException>().having((error) => error.type, 'type', type);
