// 扫码配对的二维码载荷与一次性令牌（docs/lan_sync.md §5.2“扫码配对”）。
//
// 职责边界：纯 Dart，无 I/O。
// - 编码：`jotsy-lan:v1:<base64url(规范 JSON)>`，规范 JSON 的键按字典序
//   （fp、h、id、n、p、t）、无空白；
// - 解码：严格校验——前缀与版本、字段齐全且没有多余字段、端口范围、地址可解析、
//   指纹与令牌的格式、各项长度上限；不合格抛 [LanSyncQrFormatException]；
// - [LanSyncQrToken]：显示二维码一方持有的 128 位随机令牌，2 分钟有效、一次性。
import 'dart:convert';
import 'dart:io';

import 'lan_sync_crypto.dart';

/// 当前载荷前缀。
const String kLanSyncQrPrefix = 'jotsy-lan:v1:';

/// 二维码解析失败的种类：界面据此区分“不是 Jotsy 的码”“对方版本更新，
/// 请升级”和“码已损坏”。
enum LanSyncQrError { notLanSync, unsupportedVersion, malformed }

class LanSyncQrFormatException implements Exception {
  const LanSyncQrFormatException(this.error, [this.detail]);

  final LanSyncQrError error;
  final String? detail;

  @override
  String toString() =>
      'LanSyncQrFormatException(${error.name}${detail == null ? '' : ': $detail'})';
}

/// 二维码里的连接信息。
class LanSyncQrPayload {
  LanSyncQrPayload({
    required List<String> hosts,
    required this.port,
    required this.deviceId,
    required this.fingerprint,
    required this.token,
    required this.name,
  }) : hosts = List.unmodifiable(hosts);

  /// 显示方的本机地址（IPv4 / IPv6 字面量），扫码方逐个尝试。
  final List<String> hosts;

  final int port;
  final String deviceId;

  /// 显示方身份公钥的完整指纹（64 个十六进制字符）。用完整指纹而不是信标里的
  /// 短指纹：扫码配对不再核对数字，指纹是唯一的身份锚点。
  final String fingerprint;

  /// 一次性令牌（[LanSyncQrToken.value]）。
  final String token;

  /// 显示方的设备名（扫码方在连接前展示）。
  final String name;

  static const int maxHosts = 8;
  static const int maxNameLength = 100;
  static const int _maxTextLength = 2048;

  static final RegExp _fingerprintPattern = RegExp(r'^[0-9a-f]{64}$');
  static final RegExp _deviceIdPattern = RegExp(r'^[A-Za-z0-9._:-]{1,64}$');
  static final RegExp _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{22}$');
  static const Set<String> _keys = {'fp', 'h', 'id', 'n', 'p', 't'};

  /// 编码为二维码文本。参数不合格时抛 [ArgumentError]（不生成扫不回来的码）。
  String encode() {
    final problem = _validate(hosts, port, deviceId, fingerprint, token, name);
    if (problem != null) throw ArgumentError(problem);
    // 键按字典序插入：jsonEncode 保留插入顺序，即规范 JSON。
    final json = jsonEncode({
      'fp': fingerprint,
      'h': hosts,
      'id': deviceId,
      'n': name,
      'p': port,
      't': token,
    });
    final body = base64Url.encode(utf8.encode(json)).replaceAll('=', '');
    return '$kLanSyncQrPrefix$body';
  }

  /// 解析二维码文本。
  static LanSyncQrPayload decode(String text) {
    if (!text.startsWith('jotsy-lan:')) {
      throw const LanSyncQrFormatException(LanSyncQrError.notLanSync);
    }
    if (!text.startsWith(kLanSyncQrPrefix)) {
      throw const LanSyncQrFormatException(LanSyncQrError.unsupportedVersion);
    }
    if (text.length > _maxTextLength) {
      throw const LanSyncQrFormatException(LanSyncQrError.malformed, 'length');
    }
    final Object? json;
    try {
      final body = text.substring(kLanSyncQrPrefix.length);
      json = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(body))),
      );
    } on FormatException catch (error) {
      throw LanSyncQrFormatException(LanSyncQrError.malformed, error.message);
    }
    if (json is! Map<String, Object?> ||
        json.length != _keys.length ||
        !json.keys.every(_keys.contains)) {
      throw const LanSyncQrFormatException(LanSyncQrError.malformed, 'fields');
    }
    final hosts = json['h'];
    final port = json['p'];
    final deviceId = json['id'];
    final fingerprint = json['fp'];
    final token = json['t'];
    final name = json['n'];
    if (hosts is! List ||
        !hosts.every((host) => host is String) ||
        port is! int ||
        deviceId is! String ||
        fingerprint is! String ||
        token is! String ||
        name is! String) {
      throw const LanSyncQrFormatException(LanSyncQrError.malformed, 'types');
    }
    final hostList = hosts.cast<String>().toList();
    final problem = _validate(
      hostList,
      port,
      deviceId,
      fingerprint,
      token,
      name,
    );
    if (problem != null) {
      throw LanSyncQrFormatException(LanSyncQrError.malformed, problem);
    }
    return LanSyncQrPayload(
      hosts: hostList,
      port: port,
      deviceId: deviceId,
      fingerprint: fingerprint,
      token: token,
      name: name,
    );
  }

  static String? _validate(
    List<String> hosts,
    int port,
    String deviceId,
    String fingerprint,
    String token,
    String name,
  ) {
    if (hosts.isEmpty || hosts.length > maxHosts) return 'hosts';
    for (final host in hosts) {
      if (host.length > 45 || InternetAddress.tryParse(host) == null) {
        return 'host';
      }
    }
    if (port < 1 || port > 65535) return 'port';
    if (!_deviceIdPattern.hasMatch(deviceId)) return 'id';
    if (!_fingerprintPattern.hasMatch(fingerprint)) return 'fp';
    if (!_tokenPattern.hasMatch(token)) return 'token';
    if (name.isEmpty || name.length > maxNameLength) return 'name';
    return null;
  }
}

/// 显示二维码一方持有的一次性令牌。
///
/// 128 位随机数的 base64url（无填充，22 字符）。有效期 [validity]，核销一次即
/// 作废——界面在作废或过期后立即换新码。
class LanSyncQrToken {
  LanSyncQrToken._(this.value, this.createdAt);

  /// 生成新令牌；[now] 供测试注入时间。
  factory LanSyncQrToken.generate({DateTime? now}) {
    final value = base64Url.encode(lanSyncRandomBytes(16)).replaceAll('=', '');
    return LanSyncQrToken._(value, now ?? DateTime.now());
  }

  static const Duration validity = Duration(minutes: 2);

  final String value;
  final DateTime createdAt;
  bool _used = false;

  DateTime get expiresAt => createdAt.add(validity);

  bool get isUsed => _used;

  /// 在 [now] 时是否仍可使用（未用过、未过期；时钟回拨到生成之前也视为无效）。
  bool isValidAt(DateTime now) =>
      !_used && !now.isBefore(createdAt) && now.isBefore(expiresAt);

  /// 核销：[candidate] 与本令牌一致且仍有效时作废并返回 true，否则返回 false
  /// （不一致时令牌保持有效，误扫的旧码不影响当前这张码）。
  ///
  /// 同步完成“检查 + 作废”，中间没有 await，两个并发连接不可能同时核销成功。
  bool consume(String candidate, {DateTime? now}) {
    if (!isValidAt(now ?? DateTime.now())) return false;
    if (!lanSyncBytesEqual(utf8.encode(candidate), utf8.encode(value))) {
      return false;
    }
    _used = true;
    return true;
  }
}
