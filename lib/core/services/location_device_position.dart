part of 'location_resolver_service.dart';

/// 只负责设备前台授权与 WGS84 坐标，不依赖地址服务或 UI。
/// 首次请求使用高精度以允许 GPS 参与；融合定位失败后再走系统定位，
/// 避免已安装但不可用的 Google 服务让整个定位流程直接失败。
class _DevicePositionResolver {
  static const _lastKnownTimeout = Duration(seconds: 2);
  static const _lastKnownMaxAge = Duration(minutes: 5);

  static Future<void> ensureAccess({required bool requestPermission}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationResolveException(
        type: LocationResolveErrorType.serviceDisabled,
        message: 'System location services are disabled.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (requestPermission && permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationResolveException(
        type: LocationResolveErrorType.permissionDeniedForever,
        message: 'Location permission must be enabled in system settings.',
      );
    }
    // Android 的“仅使用期间”和“仅大致位置”都可用，不索要后台权限，
    // 也不把用户拒绝精确位置误判为拒绝全部位置权限。
    if (permission != LocationPermission.whileInUse &&
        permission != LocationPermission.always) {
      throw const LocationResolveException(
        type: LocationResolveErrorType.permissionDenied,
        message: 'Foreground location permission is not granted.',
      );
    }
  }

  static Future<Position> resolve() async {
    final lastKnown = await _lastKnown(forceLocationManager: false);
    if (lastKnown != null) return lastKnown;

    try {
      return await _current(forceLocationManager: false);
    } catch (_) {
      // 请求途中可能撤权或关闭系统开关；先复查再决定是否重试，避免
      // 无意义地再等一次超时。复查不弹第二次授权框。
      await ensureAccess(requestPermission: false);
    }

    // 系统和 Google 融合定位的缓存相互独立；只用新鲜且合法的坐标兜底。
    final systemLastKnown = await _lastKnown(forceLocationManager: true);
    if (systemLastKnown != null) return systemLastKnown;
    try {
      return await _current(forceLocationManager: true);
    } catch (error) {
      await ensureAccess(requestPermission: false);
      throw LocationResolveException(
        type: error is PermissionDeniedException
            ? LocationResolveErrorType.permissionDenied
            : LocationResolveErrorType.unavailable,
        message: 'No usable position from either location provider.',
        cause: error,
      );
    }
  }

  static Future<Position> _current({required bool forceLocationManager}) async {
    // 使用插件自己的 timeLimit，超时会取消原生位置监听，而不是仅停止
    // Dart 等待。给系统 GPS 更长的首次搜星窗口，最多重试一次。
    final position = await Geolocator.getCurrentPosition(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        forceLocationManager: forceLocationManager,
        timeLimit: Duration(seconds: forceLocationManager ? 20 : 12),
      ),
    );
    if (!_isUsable(position)) {
      throw const LocationResolveException(
        type: LocationResolveErrorType.unavailable,
        message: 'Location provider returned invalid or stale coordinates.',
      );
    }
    return position;
  }

  static Future<Position?> _lastKnown({
    required bool forceLocationManager,
  }) async {
    try {
      final position = await Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: forceLocationManager,
      ).timeout(_lastKnownTimeout);
      return position != null && _isUsable(position) ? position : null;
    } catch (_) {
      // 缓存读取失败不等于实时定位失败，也不能无限等一个失效的 provider。
      return null;
    }
  }

  static bool _isUsable(Position position) {
    final age = DateTime.now().difference(position.timestamp);
    return position.latitude.isFinite &&
        position.longitude.isFinite &&
        position.latitude.abs() <= 90 &&
        position.longitude.abs() <= 180 &&
        age >= const Duration(seconds: -30) &&
        age <= _lastKnownMaxAge;
  }
}
