// 局域网同步的消息信封与握手 / 配对用到的消息（docs/lan_sync.md §5.2、§5.3）。
//
// 职责边界：
// - 输入：收到的 UTF-8 JSON 字节；
// - 输出：带类型的消息 [LanSyncMessage]，以及严格校验后的 hello [LanSyncPeerHello]；
// - 副作用：无。
//
// 信封是一个 JSON 对象 `{"type": "...", ...字段}`。这里只定义握手与配对需要的
// 类型；同步会话的消息（manifest、records、media…）由会话层在同一信封上扩展。
// 对端来的每个字段都按类型与长度校验，校验失败一律抛 FormatException，由调用方
// 当作协议错误断开。
import 'dart:convert';
import 'dart:typed_data';

import 'lan_sync_crypto.dart';

/// 握手协议版本：hello 的 `v`。不同即拒绝（reason = version），不做兼容协商。
const int kLanSyncProtocolVersion = 1;

/// 握手与配对的消息类型。
abstract final class LanSyncMessageTypes {
  /// 双方的 hello（发起方带承诺，响应方带临时公钥）。
  static const String hello = 'hs.hello';

  /// 发起方揭示临时公钥（之后双方都切到密文帧）。
  static const String reveal = 'hs.reveal';

  /// 对 transcript 哈希的签名；扫码配对时发起方在这里出示令牌。
  static const String auth = 'hs.auth';

  /// 响应方确认已验证发起方。
  static const String ok = 'hs.ok';

  /// 拒绝并说明原因（`reason`），发送后关闭连接。
  static const String reject = 'hs.reject';

  /// 核对码配对：本机用户确认核对码一致。
  static const String pairConfirm = 'pair.confirm';

  /// 核对码配对：本机用户拒绝或超时（`reason`）。
  static const String pairReject = 'pair.reject';
}

/// 一条控制消息：类型 + 其余字段。
class LanSyncMessage {
  LanSyncMessage(this.type, [Map<String, Object?> fields = const {}])
    : fields = Map.unmodifiable(fields) {
    if (fields.containsKey('type')) {
      throw ArgumentError.value(fields, 'fields', '"type" is reserved');
    }
  }

  final String type;
  final Map<String, Object?> fields;

  /// 类型名的长度上限（对端来的值）。
  static const int _maxTypeLength = 64;

  Map<String, Object?> toJson() => {'type': type, ...fields};

  Uint8List encode() => utf8.encode(jsonEncode(toJson()));

  /// 解析 UTF-8 JSON；不是对象、缺少 `type` 或格式不对时抛 FormatException。
  static LanSyncMessage decode(List<int> bytes) {
    final Object? json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, Object?>) {
      throw const FormatException('message is not a JSON object');
    }
    final type = json['type'];
    if (type is! String || type.isEmpty || type.length > _maxTypeLength) {
      throw const FormatException('message has no valid "type"');
    }
    return LanSyncMessage(type, {
      for (final entry in json.entries)
        if (entry.key != 'type') entry.key: entry.value,
    });
  }

  /// 必填字符串，长度 1..[maxLength]，可选再按 [pattern] 校验。
  String requireString(String key, {required int maxLength, RegExp? pattern}) {
    final value = fields[key];
    if (value is! String ||
        value.isEmpty ||
        value.length > maxLength ||
        (pattern != null && !pattern.hasMatch(value))) {
      throw FormatException('invalid "$key" in $type');
    }
    return value;
  }

  /// 可选字符串：缺失或 null 返回 null，存在时规则同 [requireString]。
  String? optionalString(String key, {required int maxLength}) {
    if (fields[key] == null) return null;
    return requireString(key, maxLength: maxLength);
  }

  /// 必填整数，范围 [min]..[max]。
  int requireInt(String key, {int min = 0, int max = 0x7fffffff}) {
    final value = fields[key];
    if (value is! int || value < min || value > max) {
      throw FormatException('invalid "$key" in $type');
    }
    return value;
  }

  /// 必填 base64 字节串，解码后必须正好 [length] 字节。
  Uint8List requireBytes(String key, {required int length}) {
    final value = fields[key];
    if (value is! String || value.length > (length + 2) ~/ 3 * 4) {
      throw FormatException('invalid "$key" in $type');
    }
    final Uint8List bytes;
    try {
      bytes = base64.decode(value);
    } on FormatException {
      throw FormatException('invalid "$key" in $type');
    }
    if (bytes.length != length) {
      throw FormatException('invalid "$key" in $type');
    }
    return bytes;
  }

  @override
  String toString() => 'LanSyncMessage($type)';
}

/// 连接意图：同步，或配对（hello 的 `intent`，只由发起方给出）。
enum LanSyncIntent { sync, pair }

/// 配对方式：核对码（双方确认 6 位数字）或扫码（一次性令牌）。
enum LanSyncPairingMethod { sas, qr }

/// 一方在 hello 里宣告的身份与参数（本机发出的 hello 也用它编码）。
class LanSyncPeerHello {
  LanSyncPeerHello({
    required this.protocolVersion,
    required this.formatVersion,
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.publicKey,
    required this.nonce,
    this.intent,
    this.pairingMethod,
    this.commitment,
    this.ephemeralPublicKey,
  });

  /// 握手协议版本（[kLanSyncProtocolVersion]）。
  final int protocolVersion;

  /// 应用的同步格式版本（`kSyncFormatVersion`，由调用方传入）：握手不比较，
  /// 交给会话层决定是否拒绝（§5.3）。
  final int formatVersion;

  final String deviceId;
  final String name;
  final String platform;

  /// Ed25519 身份公钥（32 字节）。
  final Uint8List publicKey;

  /// 本次握手的 32 字节随机数。
  final Uint8List nonce;

  /// 发起方的意图；响应方的 hello 没有（null）。
  final LanSyncIntent? intent;

  /// 发起方意图为配对时的方式。
  final LanSyncPairingMethod? pairingMethod;

  /// 发起方对临时公钥的承诺（只在发起方 hello 里）。
  final Uint8List? commitment;

  /// 响应方的临时公钥（只在响应方 hello 里；发起方的在 reveal 里）。
  final Uint8List? ephemeralPublicKey;

  /// 身份指纹（sha256(公钥) 十六进制）。
  String get fingerprint => lanSyncFingerprint(publicKey);

  /// 短指纹（前 8 字节十六进制）。
  String get shortFingerprint => lanSyncShortFingerprint(publicKey);

  static final RegExp _deviceIdPattern = RegExp(r'^[A-Za-z0-9._:-]+$');
  static final RegExp _platformPattern = RegExp(r'^[a-z0-9_]+$');
  static const int maxNameLength = 100;

  LanSyncMessage toMessage() {
    return LanSyncMessage(LanSyncMessageTypes.hello, {
      'v': protocolVersion,
      'f': formatVersion,
      'id': deviceId,
      'name': name,
      'platform': platform,
      'pk': base64.encode(publicKey),
      'nonce': base64.encode(nonce),
      if (intent != null) 'intent': intent!.name,
      if (pairingMethod != null) 'method': pairingMethod!.name,
      if (commitment != null) 'commit': base64.encode(commitment!),
      if (ephemeralPublicKey != null) 'eph': base64.encode(ephemeralPublicKey!),
    });
  }

  /// 严格解析对方的 hello。[fromInitiator] 决定哪些字段必填：发起方必须有
  /// intent 与承诺、不能带临时公钥；响应方相反。协议版本由调用方先行比较
  /// （版本不同时其余字段可能根本不同），这里只读出数值。
  static LanSyncPeerHello parse(
    LanSyncMessage message, {
    required bool fromInitiator,
  }) {
    if (message.type != LanSyncMessageTypes.hello) {
      throw FormatException('expected hello, got ${message.type}');
    }
    final intent = fromInitiator
        ? _enumByName(LanSyncIntent.values, message, 'intent')
        : null;
    final method = intent == LanSyncIntent.pair
        ? _enumByName(LanSyncPairingMethod.values, message, 'method')
        : null;
    if (!fromInitiator && message.fields['intent'] != null) {
      throw const FormatException('responder hello must not carry intent');
    }
    return LanSyncPeerHello(
      protocolVersion: message.requireInt('v'),
      formatVersion: message.requireInt('f'),
      deviceId: message.requireString(
        'id',
        maxLength: 64,
        pattern: _deviceIdPattern,
      ),
      name: message.requireString('name', maxLength: maxNameLength),
      platform: message.requireString(
        'platform',
        maxLength: 32,
        pattern: _platformPattern,
      ),
      publicKey: message.requireBytes('pk', length: kLanSyncKeyBytes),
      nonce: message.requireBytes('nonce', length: kLanSyncKeyBytes),
      intent: intent,
      pairingMethod: method,
      commitment: fromInitiator
          ? message.requireBytes('commit', length: kLanSyncKeyBytes)
          : _absent(message, 'commit'),
      ephemeralPublicKey: fromInitiator
          ? _absent(message, 'eph')
          : message.requireBytes('eph', length: kLanSyncKeyBytes),
    );
  }

  /// 把这份 hello 追加到握手记录。[ephemeral] 是这一方的临时公钥（发起方的来自
  /// reveal）。字段顺序固定，两端逐字节一致。
  void addToTranscript(LanSyncTranscript transcript, List<int> ephemeral) {
    transcript
      ..addInt(protocolVersion)
      ..addInt(formatVersion)
      ..addOptionalString(intent?.name)
      ..addOptionalString(pairingMethod?.name)
      ..addString(deviceId)
      ..addString(name)
      ..addString(platform)
      ..addBytes(publicKey)
      ..addBytes(nonce)
      ..addBytes(commitment ?? const <int>[])
      ..addBytes(ephemeral);
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    LanSyncMessage message,
    String key,
  ) {
    final name = message.requireString(key, maxLength: 16);
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('invalid "$key" in hello');
  }

  static Uint8List? _absent(LanSyncMessage message, String key) {
    if (message.fields[key] != null) {
      throw FormatException('unexpected "$key" in hello');
    }
    return null;
  }
}
