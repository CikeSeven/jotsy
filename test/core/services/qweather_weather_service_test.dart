import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/qweather_weather_service.dart';

void main() {
  late HttpServer server;
  var requestCount = 0;
  final requestedLanguages = <String?>[];
  const apiHost = 'qweather.test';

  setUp(() async {
    QWeatherWeatherService.debugClearCache();
    requestCount = 0;
    requestedLanguages.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    HttpOverrides.global = _RedirectingHttpOverrides(
      host: apiHost,
      serverPort: server.port,
    );
    unawaited(
      server.forEach((request) async {
        requestCount += 1;
        requestedLanguages.add(request.uri.queryParameters['lang']);
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'code': '200',
            'now': <String, String>{'text': '晴', 'temp': '26', 'icon': '100'},
          }),
        );
        await request.response.close();
      }),
    );
  });

  tearDown(() async {
    QWeatherWeatherService.debugClearCache();
    HttpOverrides.global = null;
    await server.close(force: true);
  });

  test('短时间同坐标同语言复用天气缓存', () async {
    final service = QWeatherWeatherService(
      config: QWeatherConfig(apiKey: 'test-key', apiHost: apiHost),
    );

    final first = await service.fetchNow(
      latitude: 31.2304,
      longitude: 121.4737,
      languageCode: 'zh-Hans',
    );
    final second = await service.fetchNow(
      latitude: 31.23041,
      longitude: 121.47369,
      languageCode: 'zh',
    );

    expect(first.displayText, '晴 26℃');
    expect(identical(first, second), isTrue);
    expect(requestCount, 1);
  });

  test('同一天气请求并发时复用 pending Future', () async {
    final service = QWeatherWeatherService(
      config: QWeatherConfig(apiKey: 'test-key', apiHost: apiHost),
    );

    final results = await Future.wait(<Future<QWeatherNow>>[
      service.fetchNow(latitude: 31.2304, longitude: 121.4737),
      service.fetchNow(latitude: 31.2304, longitude: 121.4737),
    ]);

    expect(identical(results[0], results[1]), isTrue);
    expect(requestCount, 1);
  });

  test('天气描述语言跟随界面语言，和风不支持的语言用英文', () async {
    final service = QWeatherWeatherService(
      config: QWeatherConfig(apiKey: 'test-key', apiHost: apiHost),
    );

    for (final code in <String>['zh-Hans', 'ja-JP', 'ru', 'fr']) {
      await service.fetchNow(
        latitude: 31.2304,
        longitude: 121.4737,
        languageCode: code,
      );
    }

    expect(requestedLanguages, <String>['zh', 'ja', 'ru', 'en']);
  });
}

class _RedirectingHttpOverrides extends HttpOverrides {
  _RedirectingHttpOverrides({required this.host, required this.serverPort});

  final String host;
  final int serverPort;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _RedirectingHttpClient(
      delegate: super.createHttpClient(context),
      host: host,
      serverPort: serverPort,
    );
  }
}

class _RedirectingHttpClient implements HttpClient {
  _RedirectingHttpClient({
    required this.delegate,
    required this.host,
    required this.serverPort,
  });

  final HttpClient delegate;
  final String host;
  final int serverPort;

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    if (url.host == host) {
      return delegate.getUrl(
        url.replace(scheme: 'http', host: '127.0.0.1', port: serverPort),
      );
    }
    return delegate.getUrl(url);
  }

  @override
  void close({bool force = false}) => delegate.close(force: force);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
