import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'cloud_backup_http.dart';
import 'cloud_backup_models.dart';

/// 授权类网盘共用的 OAuth 2.0 组件。
///
/// 职责边界：
/// - 令牌模型与持久化格式（[CloudOAuthToken]、[CloudDriveCredentials]）；
/// - 设备码授权（RFC 8628）的轮询骨架：Google、Microsoft 与百度网盘只在
///   端点和参数上不同，等待/降速/超时/取消的处理统一在 [waitForDeviceToken]；
/// - PKCE 授权码（Dropbox、阿里云盘：用户在浏览器授权后把授权码粘贴回来）；
/// - [CloudOAuthSession] 在访问令牌将过期或被拒绝时刷新，并把新令牌交给
///   调用方落盘（Microsoft 等会轮换刷新令牌，旧的随即失效）。
/// 不涉及界面，也不认识具体网盘的端点。
class CloudOAuthToken {
  const CloudOAuthToken({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
  });

  /// 解析令牌端点的标准响应。刷新响应可能不带新的刷新令牌（Google），
  /// 此时沿用 [previousRefreshToken]。
  factory CloudOAuthToken.fromResponse(
    Map<String, Object?> json, {
    String? previousRefreshToken,
    DateTime? now,
  }) {
    final accessToken = jsonString(json['access_token']);
    if (accessToken == null) {
      throw const CloudBackupException(
        CloudBackupFailure.protocol,
        'token response without access_token',
      );
    }
    final expiresIn = jsonInt(json['expires_in']);
    return CloudOAuthToken(
      accessToken: accessToken,
      refreshToken: jsonString(json['refresh_token']) ?? previousRefreshToken,
      expiresAt: expiresIn == null
          ? null
          : (now ?? DateTime.now()).add(Duration(seconds: expiresIn)),
    );
  }

  static CloudOAuthToken? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final accessToken = jsonString(raw['accessToken']);
    if (accessToken == null) return null;
    return CloudOAuthToken(
      accessToken: accessToken,
      refreshToken: jsonString(raw['refreshToken']),
      expiresAt: jsonDateTime(raw['expiresAt']),
    );
  }

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  /// 提前两分钟刷新，避免请求发出途中令牌过期。
  bool needsRefresh(DateTime now) =>
      expiresAt != null &&
      !now.isBefore(expiresAt!.subtract(const Duration(minutes: 2)));

  Map<String, Object?> toJson() => <String, Object?>{
    'accessToken': accessToken,
    if (refreshToken != null) 'refreshToken': refreshToken,
    if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
  };
}

/// 授权类备份位置的 `config`：令牌与授权时取得的账号名（只用于展示）。
class CloudDriveCredentials {
  const CloudDriveCredentials({required this.token, this.account});

  final CloudOAuthToken token;
  final String? account;

  /// 令牌缺失（配置被改坏）时抛出 [CloudBackupFailure.sessionExpired]，
  /// 界面据此引导重新授权。
  factory CloudDriveCredentials.fromConfig(Map<String, Object?> config) {
    final token = CloudOAuthToken.tryParse(config['token']);
    if (token == null) {
      throw const CloudBackupException(CloudBackupFailure.sessionExpired);
    }
    return CloudDriveCredentials(
      token: token,
      account: jsonString(config['account']),
    );
  }

  static String? accountOf(Map<String, Object?> config) =>
      jsonString(config['account']);

  CloudDriveCredentials withToken(CloudOAuthToken token) =>
      CloudDriveCredentials(token: token, account: account);

  Map<String, Object?> toConfig() => <String, Object?>{
    'token': token.toJson(),
    if (account != null) 'account': account,
  };
}

/// 设备码授权的进行中状态。用户在 [verificationUri] 输入 [userCode]；
/// 平台提供 [verificationUriComplete] 时可直接打开，免去手动输入。
class CloudDeviceAuthorization {
  const CloudDeviceAuthorization({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresAt,
    required this.interval,
    this.verificationUriComplete,
  });

  /// 解析 RFC 8628 响应；Google 用 `verification_url`，其余用
  /// `verification_uri`。
  factory CloudDeviceAuthorization.fromResponse(
    Map<String, Object?> json, {
    DateTime? now,
  }) {
    final deviceCode = jsonString(json['device_code']);
    final userCode = jsonString(json['user_code']);
    final verification = Uri.tryParse(
      jsonString(json['verification_uri']) ??
          jsonString(json['verification_url']) ??
          '',
    );
    if (deviceCode == null ||
        userCode == null ||
        verification == null ||
        !verification.hasScheme) {
      throw const CloudBackupException(
        CloudBackupFailure.protocol,
        'device authorization response incomplete',
      );
    }
    final complete = jsonString(json['verification_uri_complete']);
    return CloudDeviceAuthorization(
      deviceCode: deviceCode,
      userCode: userCode,
      verificationUri: verification,
      verificationUriComplete: complete == null ? null : Uri.tryParse(complete),
      expiresAt: (now ?? DateTime.now()).add(
        Duration(seconds: jsonInt(json['expires_in']) ?? 600),
      ),
      interval: Duration(seconds: max(jsonInt(json['interval']) ?? 5, 1)),
    );
  }

  final String deviceCode;
  final String userCode;
  final Uri verificationUri;
  final Uri? verificationUriComplete;
  final DateTime expiresAt;
  final Duration interval;
}

/// 一次设备码轮询的结果。
sealed class CloudDevicePoll {
  const CloudDevicePoll();
}

/// 用户尚未完成授权，按原间隔继续轮询。
final class CloudDevicePending extends CloudDevicePoll {
  const CloudDevicePending();
}

/// 平台要求降低轮询频率（RFC 8628：间隔加 5 秒）。
final class CloudDeviceSlowDown extends CloudDevicePoll {
  const CloudDeviceSlowDown();
}

final class CloudDeviceGranted extends CloudDevicePoll {
  const CloudDeviceGranted(this.token);

  final CloudOAuthToken token;
}

/// 把设备码轮询的错误码归类：等待中/降速返回对应结果，拒绝与过期抛出
/// 对应失败，其余（含未知错误码）视为协议不符。
CloudDevicePoll classifyDevicePollError(String? error, int statusCode) {
  switch (error) {
    case 'authorization_pending':
      return const CloudDevicePending();
    case 'slow_down':
      return const CloudDeviceSlowDown();
    case 'access_denied' || 'authorization_declined':
      throw CloudBackupException(
        CloudBackupFailure.authorizationDenied,
        error,
        statusCode,
      );
    // Google 文档没有 expired_token，设备码过期时返回 invalid_grant。
    case 'expired_token' || 'bad_verification_code' || 'invalid_grant':
      throw CloudBackupException(
        CloudBackupFailure.authorizationExpired,
        error,
        statusCode,
      );
    default:
      throw CloudBackupException(
        CloudBackupFailure.protocol,
        error ?? 'device poll failed',
        statusCode,
      );
  }
}

/// 允许界面中途取消等待（关闭授权对话框）。
class CloudBackupCancellation {
  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (!_completer.isCompleted) _completer.complete();
  }
}

/// 被取消时抛出，调用方静默结束，不当作失败提示。
class CloudBackupCancelled implements Exception {
  const CloudBackupCancelled();
}

/// 按 [authorization] 的间隔轮询直到授权完成。
///
/// - 每次等待都可被 [cancellation] 立即打断，抛出 [CloudBackupCancelled]；
/// - 收到 slow_down 时间隔加 5 秒并保持到结束；
/// - 超过设备码有效期仍未完成时抛出 [CloudBackupFailure.authorizationExpired]；
/// - 单次轮询遇到网络错误不中断（用户可能正切到浏览器、网络短暂切换），
///   连续三次才放弃。
Future<CloudOAuthToken> waitForDeviceToken(
  CloudDeviceAuthorization authorization,
  Future<CloudDevicePoll> Function(CloudDeviceAuthorization) poll, {
  required CloudBackupCancellation cancellation,
  DateTime Function() now = DateTime.now,
  Future<void> Function(Duration duration)? delay,
}) async {
  final wait = delay ?? (Duration duration) => Future<void>.delayed(duration);
  var interval = authorization.interval;
  var networkFailures = 0;
  while (true) {
    await Future.any(<Future<void>>[
      wait(interval),
      cancellation.whenCancelled,
    ]);
    if (cancellation.isCancelled) throw const CloudBackupCancelled();
    if (now().isAfter(authorization.expiresAt)) {
      throw const CloudBackupException(CloudBackupFailure.authorizationExpired);
    }
    final CloudDevicePoll result;
    try {
      result = await poll(authorization);
    } on CloudBackupException catch (error) {
      if (error.failure != CloudBackupFailure.network ||
          ++networkFailures >= 3) {
        rethrow;
      }
      continue;
    }
    if (cancellation.isCancelled) throw const CloudBackupCancelled();
    networkFailures = 0;
    switch (result) {
      case CloudDeviceGranted(:final token):
        return token;
      case CloudDeviceSlowDown():
        interval += const Duration(seconds: 5);
      case CloudDevicePending():
        break;
    }
  }
}

/// PKCE（RFC 7636，S256）的一次性校验码。
class CloudPkce {
  CloudPkce._(this.verifier, this.challenge);

  factory CloudPkce.generate([Random? random]) {
    final source = random ?? Random.secure();
    final bytes = List<int>.generate(32, (_) => source.nextInt(256));
    return CloudPkce.fromVerifier(_base64Url(bytes));
  }

  /// 由已有的校验码推出 S256 挑战值（RFC 7636 附录 B 的测试向量即按此验证）。
  factory CloudPkce.fromVerifier(String verifier) => CloudPkce._(
    verifier,
    _base64Url(sha256.convert(ascii.encode(verifier)).bytes),
  );

  final String verifier;
  final String challenge;

  static String _base64Url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');
}

/// 一个授权会话：缓存访问令牌，将过期或被拒绝时刷新，并发请求共用同一次
/// 刷新。刷新令牌失效时抛出 [CloudBackupFailure.sessionExpired]。
class CloudOAuthSession {
  CloudOAuthSession({
    required this._token,
    required this._refresh,
    this._onRefreshed,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  CloudOAuthToken _token;
  final Future<CloudOAuthToken> Function(CloudOAuthToken token) _refresh;
  final Future<void> Function(CloudOAuthToken token)? _onRefreshed;
  final DateTime Function() _clock;
  Future<CloudOAuthToken>? _refreshing;

  CloudOAuthToken get token => _token;

  Future<String> accessToken() async {
    if (_token.needsRefresh(_clock())) {
      return (await _refreshOnce()).accessToken;
    }
    return _token.accessToken;
  }

  /// 服务端拒绝了 [rejected]：若期间已被其他请求刷新，直接用新令牌；否则
  /// 刷新一次。没有刷新令牌时说明授权已失效。
  Future<String> refreshAfterRejection(String rejected) async {
    if (_token.accessToken != rejected) return _token.accessToken;
    return (await _refreshOnce()).accessToken;
  }

  Future<CloudOAuthToken> _refreshOnce() {
    return _refreshing ??= () async {
      try {
        if (_token.refreshToken == null) {
          throw const CloudBackupException(CloudBackupFailure.sessionExpired);
        }
        final next = await _refresh(_token);
        _token = next;
        await _onRefreshed?.call(next);
        return next;
      } finally {
        _refreshing = null;
      }
    }();
  }
}

/// 令牌端点的通用错误归类：刷新令牌被撤销/过期（invalid_grant）意味着
/// 必须重新授权；客户端配置错误（invalid_client 等）归为应用密钥问题。
Never throwTokenError(CloudHttpResponse response) {
  final json = response.jsonObject;
  final error = jsonString(json['error']);
  final failure = switch (error) {
    'invalid_grant' || 'expired_token' => CloudBackupFailure.sessionExpired,
    'invalid_client' ||
    'unauthorized_client' ||
    'invalid_scope' => CloudBackupFailure.appKeyMissing,
    'access_denied' => CloudBackupFailure.authorizationDenied,
    'rate_limit_exceeded' || 'slow_down' => CloudBackupFailure.rateLimited,
    _ when response.statusCode == 429 => CloudBackupFailure.rateLimited,
    _ when response.statusCode >= 500 => CloudBackupFailure.network,
    _ => CloudBackupFailure.protocol,
  };
  throw CloudBackupException(
    failure,
    error ?? jsonString(json['error_description']),
    response.statusCode,
  );
}

/// 授权会话上的通用请求：带上 Bearer 令牌，401 时刷新一次再重试。
///
/// [request] 每次调用都必须重新构造请求（不能复用已消费的上传流），因此
/// 流式上传只在首次请求前确保令牌新鲜，不走自动重试。
Future<CloudHttpResponse> sendAuthorized(
  CloudOAuthSession session,
  Future<CloudHttpResponse> Function(Map<String, String> authHeaders) request,
) async {
  var accessToken = await session.accessToken();
  var response = await request(_bearer(accessToken));
  if (response.statusCode == 401) {
    accessToken = await session.refreshAfterRejection(accessToken);
    response = await request(_bearer(accessToken));
  }
  return response;
}

Map<String, String> _bearer(String accessToken) => <String, String>{
  'Authorization': 'Bearer $accessToken',
};
