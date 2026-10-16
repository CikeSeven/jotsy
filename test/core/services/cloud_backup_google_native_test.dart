import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/cloud_backup_drive.dart';
import 'package:node_diary/core/services/cloud_backup_google_drive.dart';
import 'package:node_diary/core/services/cloud_backup_google_native.dart';
import 'package:node_diary/core/services/cloud_backup_http.dart';
import 'package:node_diary/core/services/cloud_backup_models.dart';
import 'package:node_diary/core/services/cloud_backup_oauth.dart';

/// Google Drive 的系统授权路径（Play 服务）：授权方式选择、回落与续期。
void main() {
  late CloudBackupHttp http;
  setUp(() => http = CloudBackupHttp());
  tearDown(() => http.close());

  GoogleDriveProvider provider(
    _FakeNativeAuth native, {
    bool deviceCode = true,
  }) => GoogleDriveProvider(
    clientId: deviceCode ? 'tv-client' : '',
    clientSecret: deviceCode ? 'tv-secret' : '',
    nativeAuth: native,
  );

  test(
    'prefers system authorization and keeps device code as fallback',
    () async {
      final native = _FakeNativeAuth(supported: true);
      final method = provider(native).beginAuthorization(http);

      expect(method, isA<CloudNativeAuthorization>());
      final nativeMethod = method as CloudNativeAuthorization;
      expect(nativeMethod.fallback, isA<CloudDeviceCodeAuthorization>());
      final token = await nativeMethod.authorize();
      expect(token?.platformManaged, isTrue);
      expect(native.authorizedScopes, [GoogleDriveProvider.scope]);
    },
  );

  test('system authorization alone makes the drive available', () {
    final drive = provider(_FakeNativeAuth(supported: true), deviceCode: false);
    expect(drive.isAvailable, isTrue);
    final method = drive.beginAuthorization(http) as CloudNativeAuthorization;
    expect(method.fallback, isNull);
  });

  test('without Play services support only device code is offered', () {
    final drive = provider(_FakeNativeAuth(supported: false));
    expect(drive.isAvailable, isTrue);
    expect(drive.beginAuthorization(http), isA<CloudDeviceCodeAuthorization>());
    expect(
      provider(
        _FakeNativeAuth(supported: false),
        deviceCode: false,
      ).isAvailable,
      isFalse,
    );
  });

  test('platform-managed tokens are renewed through the system', () async {
    final native = _FakeNativeAuth(supported: true);
    final drive = provider(native);
    final persisted = <CloudOAuthToken>[];
    final session = CloudOAuthSession(
      // 没有刷新令牌、即将过期：必须向系统续期，而不是判为授权失效。
      token: CloudOAuthToken(
        accessToken: 'play-1',
        expiresAt: DateTime.now().add(const Duration(seconds: 30)),
        platformManaged: true,
      ),
      refresh: (token) => drive.refresh(http, token),
      onRefreshed: (token) async => persisted.add(token),
    );

    expect(await session.accessToken(), 'play-2');
    expect(native.refreshedFrom, ['play-1']);
    expect(persisted.single.platformManaged, isTrue);
    expect(persisted.single.refreshToken, isNull);
  });

  test('platform-managed flag survives the config round trip', () {
    const token = CloudOAuthToken(accessToken: 'a', platformManaged: true);
    final parsed = CloudOAuthToken.tryParse(token.toJson())!;
    expect(parsed.platformManaged, isTrue);
    expect(
      CloudOAuthToken.tryParse(
        const CloudOAuthToken(accessToken: 'b').toJson(),
      )!.platformManaged,
      isFalse,
    );
  });

  test('Play services auth needs Android and a web client id', () async {
    expect(
      PlayServicesGoogleDriveAuth(
        serverClientId: 'web',
        android: true,
      ).isSupported,
      isTrue,
    );
    expect(
      PlayServicesGoogleDriveAuth(
        serverClientId: '',
        android: true,
      ).isSupported,
      isFalse,
    );
    final desktop = PlayServicesGoogleDriveAuth(
      serverClientId: 'web',
      android: false,
    );
    expect(desktop.isSupported, isFalse);
    // 在不支持的平台上续期系统令牌只能重新授权。
    await expectLater(
      desktop.refresh(
        const CloudOAuthToken(accessToken: 'a', platformManaged: true),
        const [GoogleDriveProvider.scope],
      ),
      throwsA(
        isA<CloudBackupException>().having(
          (e) => e.failure,
          'failure',
          CloudBackupFailure.sessionExpired,
        ),
      ),
    );
  });
}

class _FakeNativeAuth implements GoogleDriveNativeAuth {
  _FakeNativeAuth({required this.supported});

  final bool supported;
  final List<String> authorizedScopes = [];
  final List<String> refreshedFrom = [];
  var _issued = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<CloudOAuthToken?> authorize(List<String> scopes) async {
    authorizedScopes.addAll(scopes);
    return _next();
  }

  @override
  Future<CloudOAuthToken> refresh(
    CloudOAuthToken current,
    List<String> scopes,
  ) async {
    refreshedFrom.add(current.accessToken);
    _issued = int.parse(current.accessToken.split('-').last);
    return _next();
  }

  CloudOAuthToken _next() => CloudOAuthToken(
    accessToken: 'play-${++_issued}',
    expiresAt: DateTime.now().add(const Duration(minutes: 50)),
    platformManaged: true,
  );
}
