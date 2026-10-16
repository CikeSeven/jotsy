import 'cloud_backup_http.dart';
import 'cloud_backup_models.dart';
import 'cloud_backup_oauth.dart';

/// 授权类网盘（Google Drive、OneDrive、Dropbox、百度网盘、阿里云盘）的
/// 统一描述：怎样授权、怎样刷新令牌、授权后怎样访问备份目录。
///
/// 每个网盘一个实现，在 `cloud_backup_drives.dart` 登记；新增网盘只需新增
/// `cloud_backup_<网盘>.dart` 并登记，不改动备份编排与界面流程。
abstract class CloudDriveProvider {
  CloudBackupKind get kind;

  /// 此安装包是否配置了该网盘的应用密钥；未配置时不提供添加入口。
  bool get isAvailable;

  /// 开始一次授权。返回的方式决定界面形态（设备码 / 粘贴授权码）。
  CloudDriveAuthorization beginAuthorization(CloudBackupHttp http);

  /// 用刷新令牌换新的访问令牌；刷新令牌失效时抛出
  /// [CloudBackupFailure.sessionExpired]。
  Future<CloudOAuthToken> refresh(CloudBackupHttp http, CloudOAuthToken token);

  /// 授权后读取账号名（邮箱或昵称）用于展示；读取失败返回 null，不影响授权。
  Future<String?> fetchAccount(CloudBackupHttp http, CloudOAuthSession session);

  CloudBackupRemote createRemote(
    CloudBackupHttp http,
    CloudOAuthSession session,
  );
}

/// 授权方式。
sealed class CloudDriveAuthorization {
  const CloudDriveAuthorization();
}

/// 设备码：界面展示 [CloudDeviceAuthorization.userCode]，用户在浏览器打开
/// 授权页输入后，应用轮询拿到令牌。不需要回调地址，也不需要内嵌网页。
final class CloudDeviceCodeAuthorization extends CloudDriveAuthorization {
  const CloudDeviceCodeAuthorization({required this.start, required this.poll});

  final Future<CloudDeviceAuthorization> Function() start;
  final Future<CloudDevicePoll> Function(CloudDeviceAuthorization) poll;
}

/// 粘贴授权码：用户在浏览器打开 [authorizeUri] 授权，网盘页面显示授权码，
/// 用户复制回应用后 [exchange] 换取令牌（PKCE，不需要应用密钥中的 secret）。
final class CloudCodePasteAuthorization extends CloudDriveAuthorization {
  const CloudCodePasteAuthorization({
    required this.authorizeUri,
    required this.exchange,
  });

  final Uri authorizeUri;
  final Future<CloudOAuthToken> Function(String code) exchange;
}

/// 刷新令牌的通用表单请求：成功返回新令牌（沿用旧刷新令牌兜底），失败按
/// [throwTokenError] 归类。
Future<CloudOAuthToken> refreshWithForm(
  CloudBackupHttp http,
  Uri tokenEndpoint,
  CloudOAuthToken token,
  Map<String, String> fields,
) async {
  final response = await http.sendForm(tokenEndpoint, <String, String>{
    'grant_type': 'refresh_token',
    'refresh_token': token.refreshToken!,
    ...fields,
  });
  if (!response.isSuccess) throwTokenError(response);
  return CloudOAuthToken.fromResponse(
    response.requireJsonObject(),
    previousRefreshToken: token.refreshToken,
  );
}

/// RFC 8628 的一次设备码轮询（表单 POST）：成功返回令牌，等待/降速/拒绝/
/// 过期按错误码归类。
Future<CloudDevicePoll> pollDeviceTokenWithForm(
  CloudBackupHttp http,
  Uri tokenEndpoint,
  Map<String, String> fields,
) async {
  final response = await http.sendForm(tokenEndpoint, fields);
  final json = response.jsonObject;
  if (response.isSuccess && json['access_token'] != null) {
    return CloudDeviceGranted(CloudOAuthToken.fromResponse(json));
  }
  if (response.statusCode >= 500) {
    throw CloudBackupException(
      CloudBackupFailure.network,
      'device poll',
      response.statusCode,
    );
  }
  return classifyDevicePollError(
    jsonString(json['error']),
    response.statusCode,
  );
}
