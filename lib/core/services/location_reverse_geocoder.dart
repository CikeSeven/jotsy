part of 'location_resolver_service.dart';

/// 将设备 WGS84 坐标转换成高德坐标，再获取可保存的地址组件。
/// 坐标转换与逆地理编码共用 HTTP 错误映射；每次请求的超时覆盖连接、
/// 响应头和完整正文，防止收到响应头后断流使按钮永久处于等待状态。
class _AmapReverseGeocoder {
  const _AmapReverseGeocoder(this.webApiKey);

  final String webApiKey;
  static const _networkTimeout = Duration(seconds: 10);

  Future<_ReverseGeocodeResult> resolve(Position position) async {
    // Geolocator 返回 GPS/WGS84；逆地理编码要求高德坐标。使用官方转换
    // 接口而非直接发送 GPS 点，避免国内地址产生数百米偏移。
    final converted = await _getJson('/v3/assistant/coordinate/convert', {
      'locations':
          '${position.longitude.toStringAsFixed(6)},'
          '${position.latitude.toStringAsFixed(6)}',
      'coordsys': 'gps',
    });
    final rawLocations = converted['locations'];
    final parts = rawLocations is String ? rawLocations.split(',') : <String>[];
    final longitude = parts.length == 2 ? double.tryParse(parts[0]) : null;
    final latitude = parts.length == 2 ? double.tryParse(parts[1]) : null;
    if (longitude == null ||
        latitude == null ||
        !longitude.isFinite ||
        !latitude.isFinite ||
        longitude.abs() > 180 ||
        latitude.abs() > 90) {
      throw const LocationResolveException(
        type: LocationResolveErrorType.parseError,
        message: 'AMap coordinate conversion returned invalid coordinates.',
      );
    }
    final decoded = await _getJson('/v3/geocode/regeo', {
      'location': '$longitude,$latitude',
      'extensions': 'base',
    });
    final regeo = decoded['regeocode'];
    if (regeo is! Map<String, dynamic>) {
      throw const LocationResolveException(
        type: LocationResolveErrorType.parseError,
        message: 'AMap response is missing regeocode.',
      );
    }

    final rawAddressComponent = regeo['addressComponent'];
    if (rawAddressComponent is! Map) {
      throw const LocationResolveException(
        type: LocationResolveErrorType.parseError,
        message: 'AMap response is missing addressComponent.',
      );
    }

    final addressComponent = _sanitizeAddressComponent(rawAddressComponent);
    final streetNumber = addressComponent['streetNumber'];
    final hasDisplayAddress = [
      for (final key in ['province', 'city', 'district', 'township'])
        addressComponent[key],
      if (streetNumber is Map) streetNumber['street'],
    ].any((value) => _normalizeOptionalText(value) != null);
    if (!hasDisplayAddress) {
      throw const LocationResolveException(
        type: LocationResolveErrorType.parseError,
        message: 'AMap address components are empty.',
      );
    }

    final township = _normalizeOptionalText(addressComponent['township']);
    final formattedAddress = _normalizeOptionalText(regeo['formatted_address']);

    return _ReverseGeocodeResult(
      township: township,
      formattedAddress: formattedAddress,
      addressComponent: addressComponent,
    );
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, String> parameters,
  ) async {
    final client = HttpClient();
    final uri = Uri.https('restapi.amap.com', path, {
      'key': webApiKey,
      ...parameters,
    });
    try {
      final body = await (() async {
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          throw LocationResolveException(
            type: LocationResolveErrorType.networkError,
            message: 'AMap request failed (HTTP ${response.statusCode}).',
          );
        }
        return response.transform(utf8.decoder).join();
      })().timeout(_networkTimeout);
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object.');
      }
      if (decoded['status']?.toString() != '1') {
        throw LocationResolveException(
          type: LocationResolveErrorType.apiError,
          message:
              'AMap rejected request: ${decoded['infocode']} ${decoded['info']}',
        );
      }
      return decoded;
    } on TimeoutException catch (error) {
      throw LocationResolveException(
        type: LocationResolveErrorType.networkError,
        message: 'AMap request timed out.',
        cause: error,
      );
    } on IOException catch (error) {
      throw LocationResolveException(
        type: LocationResolveErrorType.networkError,
        message: 'AMap connection failed.',
        cause: error,
      );
    } on FormatException catch (error) {
      throw LocationResolveException(
        type: LocationResolveErrorType.parseError,
        message: 'AMap returned unreadable data.',
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
      // 保留道路和门牌组件，供地址层级切换复用；展示层只取用户选择的层级，
      // 避免每次调整文案都重新定位和请求逆地理编码。
      final rawValue = entry.value;
      final value = key == 'streetNumber' && rawValue is Map
          ? _sanitizeStreetNumber(rawValue)
          : _sanitizeJsonValue(rawValue);
      if (value != null) {
        output[key] = value;
      }
    }
    return output;
  }

  /// 门牌组件只留道路名和门牌号：高德附带的门牌坐标、方位与距离和 geo
  /// 经纬度重复，地址层级也用不到，不随日记 metadata 落盘。
  Map<String, Object?> _sanitizeStreetNumber(Map raw) =>
      _sanitizeAddressComponent({
        for (final key in const ['street', 'number'])
          if (raw.containsKey(key)) key: raw[key],
      });

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
    if (raw is String) {
      final normalized = raw.trim();
      return normalized.isEmpty ? null : normalized;
    }
    if (raw is List) {
      for (final value in raw) {
        final text = _normalizeOptionalText(value);
        if (text != null) return text;
      }
    }
    return null;
  }
}
