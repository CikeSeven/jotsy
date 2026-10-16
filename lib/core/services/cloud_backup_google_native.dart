import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';

import 'cloud_backup_app_keys.dart';
import 'cloud_backup_drive.dart';
import 'cloud_backup_models.dart';
import 'cloud_backup_oauth.dart';

/// 经系统账号服务授权 Google Drive 的接口（测试可替换为假实现）。
abstract interface class GoogleDriveNativeAuth {
  /// 本机可以尝试系统授权：Android 且配置了 Web 客户端 ID。
  bool get isSupported;

  /// 弹出账号选择与授权。用户取消返回 null；本机无法使用系统授权时抛出
  /// [CloudNativeAuthUnavailable]。
  Future<CloudOAuthToken?> authorize(List<String> scopes);

  /// 静默换取新的访问令牌；账号已退出或撤销授权时抛出
  /// [CloudBackupFailure.sessionExpired]。
  Future<CloudOAuthToken> refresh(CloudOAuthToken current, List<String> scopes);
}

/// Android 上经 Google Play 服务（google_sign_in）授权。
///
/// - 先用 Credential Manager 选择账号（需要 Web 客户端 ID 作为
///   serverClientId），再在该账号上申请 `drive.file`：绑定账号后，多账号的
///   手机也能静默续期；
/// - 访问令牌由 Play 服务签发与缓存，应用不保存刷新令牌：令牌标记为
///   [CloudOAuthToken.platformManaged]，续期时先清掉旧令牌的缓存再静默
///   申请，拿到的一定是新令牌；
/// - `GoogleSignIn.initialize` 每个进程只能调用一次，用静态 Future 共享。
/// 没有 Play 服务、手机未登录 Google 账号、客户端配置不匹配（包名/SHA-1）
/// 时抛出 [CloudNativeAuthUnavailable]，由界面回落到设备码授权。
class PlayServicesGoogleDriveAuth implements GoogleDriveNativeAuth {
  PlayServicesGoogleDriveAuth({String? serverClientId, bool? android})
    : _serverClientId = serverClientId ?? CloudBackupAppKeys.googleWebClientId,
      _android = android ?? Platform.isAndroid;

  final String _serverClientId;
  final bool _android;

  /// Play 服务的访问令牌约一小时有效，提前十分钟按过期处理并续期。
  static const _tokenLifetime = Duration(minutes: 50);
  static Future<void>? _initialized;

  @override
  bool get isSupported => _android && _serverClientId.isNotEmpty;

  Future<void> _ensureInitialized() => _initialized ??= GoogleSignIn.instance
      .initialize(serverClientId: _serverClientId)
      .catchError((Object error) {
        // 初始化失败时允许下次重试，而不是永久缓存失败结果。
        _initialized = null;
        throw error;
      });

  @override
  Future<CloudOAuthToken?> authorize(List<String> scopes) async {
    try {
      await _ensureInitialized();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: scopes,
      );
      final client = account.authorizationClient;
      final authorization =
          await client.authorizationForScopes(scopes) ??
          await client.authorizeScopes(scopes);
      return _token(authorization.accessToken);
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return null;
      }
      throw CloudNativeAuthUnavailable(
        '${error.code.name}: ${error.description}',
      );
    } on CloudNativeAuthUnavailable {
      rethrow;
    } catch (error) {
      // 插件缺失、平台通道异常等同样视为本机无法使用系统授权。
      throw CloudNativeAuthUnavailable('$error');
    }
  }

  @override
  Future<CloudOAuthToken> refresh(
    CloudOAuthToken current,
    List<String> scopes,
  ) async {
    if (!isSupported) {
      throw const CloudBackupException(CloudBackupFailure.sessionExpired);
    }
    try {
      await _ensureInitialized();
      final account = await GoogleSignIn.instance
          .attemptLightweightAuthentication();
      final client =
          account?.authorizationClient ??
          GoogleSignIn.instance.authorizationClient;
      try {
        await client.clearAuthorizationToken(accessToken: current.accessToken);
      } on GoogleSignInException {
        // 清缓存失败不影响续期，最坏拿到的仍是旧令牌，过期后会再续一次。
      }
      final authorization = await client.authorizationForScopes(scopes);
      if (authorization == null) {
        throw const CloudBackupException(CloudBackupFailure.sessionExpired);
      }
      return _token(authorization.accessToken);
    } on GoogleSignInException catch (error) {
      throw CloudBackupException(
        CloudBackupFailure.sessionExpired,
        error.code.name,
      );
    } on CloudBackupException {
      rethrow;
    } catch (error) {
      throw CloudBackupException(CloudBackupFailure.sessionExpired, '$error');
    }
  }

  static CloudOAuthToken _token(String accessToken) => CloudOAuthToken(
    accessToken: accessToken,
    expiresAt: DateTime.now().add(_tokenLifetime),
    platformManaged: true,
  );
}
