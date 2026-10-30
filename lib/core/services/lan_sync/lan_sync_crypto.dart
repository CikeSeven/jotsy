// 局域网同步的密码学原语：握手记录（transcript）、承诺、密钥派生、核对码、
// 签名输入与逐帧 AEAD（docs/lan_sync.md §5.2）。
//
// 职责边界：
// - 输入：双方 hello 的字段、本次会话的临时 X25519 密钥、对方的临时公钥；
// - 输出：transcript 哈希、两个方向的 32 字节密钥、6 位核对码、帧密文；
// - 副作用：无（不做 I/O；随机数取自 Random.secure）。
//
// 选择与理由：
// - 帧加密用 ChaCha20-Poly1305 的纯 Dart 同步实现：本机基准（JIT）约 52 MiB/s，
//   同实现下的 AES-256-GCM 约 20 MiB/s（没有硬件 AES 指令可用），见
//   test/core/services/lan_sync/lan_sync_aead_benchmark_test.dart；
// - 用同步 API 逐帧加解密：异步 API 每帧多几次微任务调度，64 KiB 一帧的耗时
//   只有约 1 ms，阻塞事件循环可以接受；
// - SHA-256 用 package:crypto 的同步实现，签名、密钥交换与 HKDF 用
//   package:cryptography（以后接入原生实现时自动加速）。
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

/// 握手里的两个角色：发起方（连接的一方）与响应方（监听的一方）。
enum LanSyncRole { initiator, responder }

/// 公钥、随机数、临时公钥与承诺的字节长度。
const int kLanSyncKeyBytes = 32;

/// 帧 AEAD 的认证标签长度（Poly1305）。
const int kLanSyncTagBytes = 16;

/// 小写十六进制。
String lanSyncHex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

/// SHA-256 摘要。
Uint8List lanSyncSha256(List<int> bytes) =>
    Uint8List.fromList(crypto.sha256.convert(bytes).bytes);

/// 密码学安全的随机字节。
Uint8List lanSyncRandomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}

/// 常数时间比较，避免按字节提前返回泄露匹配长度（承诺、指纹比较用）。
bool lanSyncBytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// 发起方对临时公钥的承诺：`SHA-256("jotsy-lan/v1 commit" ‖ 临时公钥 ‖ 随机数)`。
///
/// 前缀只做域分离（同一哈希不会与签名输入、transcript 混用）；随机数让承诺
/// 不能被预先算表。为什么需要承诺见 lan_sync_handshake.dart 顶部。
Uint8List lanSyncCommitment(List<int> ephemeralPublicKey, List<int> nonce) {
  return lanSyncSha256([
    ...utf8.encode('jotsy-lan/v1 commit'),
    ...ephemeralPublicKey,
    ...nonce,
  ]);
}

/// 握手记录的规范串联：每个字段写成 `u32 大端长度 ‖ 字节`，没有分隔符歧义，
/// 两端按同一顺序追加同一组值即得到逐字节相同的记录。
class LanSyncTranscript {
  LanSyncTranscript() {
    addString('jotsy-lan/v1 transcript');
  }

  final BytesBuilder _bytes = BytesBuilder(copy: false);

  void addBytes(List<int> value) {
    final length = ByteData(4)..setUint32(0, value.length);
    _bytes
      ..add(length.buffer.asUint8List())
      ..add(value);
  }

  void addString(String value) => addBytes(utf8.encode(value));

  /// 整数按十进制文本写入，与 JSON 里的数值一致，不受整数宽度影响。
  void addInt(int value) => addString(value.toString());

  /// 可空字段写成空串，与“空串”本身由 hello 校验区分（空串不是合法值）。
  void addOptionalString(String? value) => addString(value ?? '');

  /// transcript 哈希：签名与 HKDF salt 的输入。
  Uint8List get hash => lanSyncSha256(_bytes.toBytes());
}

/// 签名输入：`"jotsy-lan/v1 sig <角色>" ‖ transcript 哈希`。
///
/// 带上签名者的角色，防止把一方的签名原样反射回去冒充另一方。
Uint8List lanSyncSignaturePayload(LanSyncRole signer, List<int> transcript) {
  return Uint8List.fromList([
    ...utf8.encode('jotsy-lan/v1 sig ${signer.name}'),
    ...transcript,
  ]);
}

/// 临时 X25519 密钥交换。对方给出低阶点时共享密钥全为 0：这种连接只可能来自
/// 恶意或损坏的对端，直接拒绝。
Future<Uint8List> lanSyncSharedSecret({
  required SimpleKeyPair ephemeral,
  required List<int> peerEphemeralPublicKey,
}) async {
  final secret = await X25519().sharedSecretKey(
    keyPair: ephemeral,
    remotePublicKey: SimplePublicKey(
      peerEphemeralPublicKey,
      type: KeyPairType.x25519,
    ),
  );
  final bytes = Uint8List.fromList(await secret.extractBytes());
  if (bytes.every((byte) => byte == 0)) {
    throw const FormatException('degenerate X25519 shared secret');
  }
  return bytes;
}

/// 握手派生出的会话材料。
class LanSyncSessionKeys {
  const LanSyncSessionKeys._({
    required this.initiatorToResponder,
    required this.responderToInitiator,
    required this.sasCode,
  });

  /// 发起方 → 响应方的帧密钥。
  final Uint8List initiatorToResponder;

  /// 响应方 → 发起方的帧密钥。
  final Uint8List responderToInitiator;

  /// 6 位十进制核对码（首次配对时双方显示，界面按 3+3 分组）。
  final String sasCode;

  /// HKDF-SHA256(ikm = 共享密钥, salt = transcript 哈希) 分别以不同 info 派生
  /// 两个方向的密钥与核对码种子：方向密钥不同，任何一帧都不能被反射回发送方。
  static Future<LanSyncSessionKeys> derive({
    required List<int> sharedSecret,
    required List<int> transcriptHash,
  }) async {
    Future<Uint8List> expand(String info, int length) async {
      final key = await Hkdf(hmac: Hmac.sha256(), outputLength: length)
          .deriveKey(
            secretKey: SecretKey(sharedSecret),
            nonce: transcriptHash,
            info: utf8.encode(info),
          );
      return Uint8List.fromList(await key.extractBytes());
    }

    final i2r = await expand('jotsy-lan/v1 key initiator->responder', 32);
    final r2i = await expand('jotsy-lan/v1 key responder->initiator', 32);
    final sasSeed = await expand('jotsy-sas', 8);
    return LanSyncSessionKeys._(
      initiatorToResponder: i2r,
      responderToInitiator: r2i,
      sasCode: lanSyncSasCode(sasSeed),
    );
  }

  /// 本方发送用的密钥。
  Uint8List sendKey(LanSyncRole self) => self == LanSyncRole.initiator
      ? initiatorToResponder
      : responderToInitiator;

  /// 本方接收用的密钥。
  Uint8List receiveKey(LanSyncRole self) => self == LanSyncRole.initiator
      ? responderToInitiator
      : initiatorToResponder;
}

/// 核对码种子 → 6 位十进制（不足补 0）。取 48 位再对 10^6 取模，偏差约
/// 10^6 / 2^48，可以忽略。
String lanSyncSasCode(List<int> seed) {
  var value = 0;
  for (var i = 0; i < 6; i++) {
    value = (value << 8) | seed[i];
  }
  return (value % 1000000).toString().padLeft(6, '0');
}

/// 帧加解密失败（认证标签不符：被篡改、重放、乱序或密钥不对）。
class LanSyncAuthenticationException implements Exception {
  const LanSyncAuthenticationException();

  @override
  String toString() => 'LanSyncAuthenticationException: frame rejected';
}

/// 一个方向的帧 AEAD 状态（ChaCha20-Poly1305）。
///
/// nonce = 4 字节方向前缀 ‖ 8 字节递增计数器。计数器不随帧传输：接收方用自己
/// 期望的下一个计数器构造 nonce，被重放、乱序或丢弃的帧都会在认证时失败，
/// 因此“计数器不连续即断开”不需要额外比较。帧头（4 字节长度）作附加数据，
/// 截短或改写长度同样认证失败。
class LanSyncFrameCipher {
  LanSyncFrameCipher({required List<int> key, required LanSyncRole sender})
    : _key = SecretKeyData(List<int>.unmodifiable(key)),
      _prefix = sender == LanSyncRole.initiator ? 1 : 2 {
    if (key.length != 32) {
      throw ArgumentError.value(key.length, 'key', 'expected 32 bytes');
    }
  }

  static const DartChacha20 _aead = DartChacha20.poly1305Aead();

  /// 计数器上限：远超任何一次同步的帧数，到达即拒绝继续，绝不重复使用 nonce。
  static const int _maxCounter = 1 << 62;

  final SecretKeyData _key;
  final int _prefix;
  int _counter = 0;

  Uint8List _nextNonce() {
    if (_counter >= _maxCounter) {
      throw StateError('LAN sync frame counter exhausted');
    }
    final nonce = ByteData(12)
      ..setUint32(0, _prefix)
      ..setUint32(4, _counter >> 32)
      ..setUint32(8, _counter & 0xffffffff);
    _counter++;
    return nonce.buffer.asUint8List();
  }

  /// 加密一帧，返回整帧字节：`[u32 大端密文长度][密文 ‖ 标签]`。
  Uint8List seal(List<int> plaintext) {
    final length = plaintext.length + kLanSyncTagBytes;
    final frame = Uint8List(4 + length);
    final header = ByteData.sublistView(frame, 0, 4)..setUint32(0, length);
    final box = _aead.encryptSync(
      plaintext,
      secretKey: _key,
      nonce: _nextNonce(),
      aad: header.buffer.asUint8List(0, 4),
    );
    frame.setRange(4, 4 + plaintext.length, box.cipherText);
    frame.setRange(4 + plaintext.length, frame.length, box.mac.bytes);
    return frame;
  }

  /// 解密一帧的密文部分（不含帧头）；认证失败抛 [LanSyncAuthenticationException]。
  Uint8List open(Uint8List body) {
    if (body.length < kLanSyncTagBytes) {
      throw const LanSyncAuthenticationException();
    }
    final header = ByteData(4)..setUint32(0, body.length);
    final split = body.length - kLanSyncTagBytes;
    final box = SecretBox(
      Uint8List.sublistView(body, 0, split),
      nonce: _nextNonce(),
      mac: Mac(Uint8List.sublistView(body, split)),
    );
    try {
      final plaintext = _aead.decryptSync(
        box,
        secretKey: _key,
        aad: header.buffer.asUint8List(),
      );
      return plaintext is Uint8List ? plaintext : Uint8List.fromList(plaintext);
    } on SecretBoxAuthenticationError {
      throw const LanSyncAuthenticationException();
    }
  }
}

/// 身份指纹：sha256(Ed25519 公钥) 的小写十六进制（64 字符），二维码里用它。
String lanSyncFingerprint(List<int> publicKey) =>
    lanSyncHex(lanSyncSha256(publicKey));

/// 短指纹：指纹的前 8 字节（16 个十六进制字符），信标与界面核对用。
String lanSyncShortFingerprint(List<int> publicKey) =>
    lanSyncFingerprint(publicKey).substring(0, 16);
