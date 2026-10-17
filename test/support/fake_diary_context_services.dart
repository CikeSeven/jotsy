import 'package:node_diary/core/services/location_resolver_service.dart';
import 'package:node_diary/core/services/qweather_weather_service.dart';

/// 不走定位权限与网络的定位服务：每次返回固定结果并计数。
class FakeLocationResolverService extends LocationResolverService {
  FakeLocationResolverService({ResolvedLocation? result})
    : result =
          result ??
          const ResolvedLocation(
            latitude: 39.98941,
            longitude: 116.480881,
            addressComponent: <String, Object?>{
              'province': '北京市',
              'city': <Object?>[],
              'district': '朝阳区',
              'township': '望京街道',
            },
          ),
      super(webApiKey: 'fake');

  final ResolvedLocation result;
  int calls = 0;

  @override
  Future<ResolvedLocation> resolveCurrentLocation() async {
    calls++;
    return result;
  }
}

/// 不走网络的天气服务：返回固定天气并记录请求坐标。
class FakeWeatherService extends QWeatherWeatherService {
  FakeWeatherService({
    this.result = const QWeatherNow(
      weatherText: 'Sunny',
      temperatureCelsius: '24',
      iconCode: '100',
    ),
  }) : super(
         config: const QWeatherConfig(apiKey: 'fake', apiHost: 'fake'),
       );

  final QWeatherNow result;
  final List<(double, double)> requests = <(double, double)>[];

  @override
  Future<QWeatherNow> fetchNow({
    required double latitude,
    required double longitude,
    String languageCode = 'zh',
  }) async {
    requests.add((latitude, longitude));
    return result;
  }
}
