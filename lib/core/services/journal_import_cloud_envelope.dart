import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

import 'journal_import_cloud_http.dart';

/// OPPO、vivo 网页版的请求信封（混合加密）：每次读取随机生成 AES 会话
/// 密钥，用厂商在网页中公开的 RSA 公钥（PKCS#1 v1.5）包装后随请求发送，
/// 服务端用同一会话密钥加密响应。只用公钥，不含任何私钥或账号密钥；
/// 格式依据参考实现「笔记互迁」的 `oppo_wire.py` / `vivo_wire.py`。

/// OPPO 笔记请求信封：每个请求一把新的 AES-256-CBC 密钥（32 个十六进制
/// 字符的 ASCII 字节），IV 为 16 个十六进制字符。
class OppoEnvelope {
  OppoEnvelope(Object? data, {RSAPublicKey? publicKey, Random? random})
    : _random = random ?? Random.secure() {
    _key = Uint8List.fromList(ascii.encode(_hex(16)));
    final iv = _hex(8);
    final wrapped = rsaPkcs1Encrypt(
      publicKey ?? rsaPublicKeyFromPem(oppoPublicKeyPem),
      _key,
      _random,
    );
    payload = {
      'key': base64.encode(wrapped),
      'iv': iv,
      'encryptContent': base64.encode(
        aesCbc(_key, ascii.encode(iv), utf8.encode(jsonEncode(data)), true),
      ),
    };
  }

  final Random _random;
  late final Uint8List _key;

  /// 发送的 JSON：`{key, iv, encryptContent}`。
  late final Map<String, String> payload;

  /// 解密响应的 `data`（`{iv, encryptContent}`）为 JSON。
  Object? decrypt(Object? data) {
    try {
      if (data is! Map) throw const FormatException('envelope');
      final iv = ascii.encode(data['iv'] as String);
      final cipher = base64.decode(data['encryptContent'] as String);
      return jsonDecode(utf8.decode(aesCbc(_key, iv, cipher, false)));
    } on Object catch (error) {
      if (error is CloudNoteException) rethrow;
      throw const CloudNoteException(
        CloudNoteFailure.protocolChanged,
        'oppo envelope',
      );
    }
  }

  String _hex(int bytes) => [
    for (var i = 0; i < bytes; i++)
      _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

/// vivo 笔记请求信封：一次读取共用一把 AES-128-CBC 密钥与 IV（各 16 个
/// `0-9A-Z` 字符）。密文前缀一个二进制头：总长、CRC32 校验、固定字段、
/// 应用标识 `com.android.notes`、IV 与 RSA 包装后的密钥，整体用 URL 安全
/// 的 Base64（去掉末尾 `=`）编码。
class VivoEnvelope {
  VivoEnvelope({RSAPublicKey? publicKey, Random? random}) {
    final rng = random ?? Random.secure();
    const alphabet = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    String token() => String.fromCharCodes([
      for (var i = 0; i < 16; i++)
        alphabet.codeUnitAt(rng.nextInt(alphabet.length)),
    ]);
    _key = Uint8List.fromList(ascii.encode(token()));
    _iv = Uint8List.fromList(ascii.encode(token()));
    final wrapped = rsaPkcs1Encrypt(
      publicKey ?? rsaPublicKeyFromPem(vivoPublicKeyPem),
      _key,
      rng,
    );
    final appToken = ascii.encode('com.android.notes');
    final fields = BytesBuilder()
      ..add(_u16(32))
      ..add(_u16(203))
      ..add(_u16(1))
      ..addByte(0x41)
      ..addByte(appToken.length)
      ..add(appToken)
      ..add(_iv)
      ..add(_u16(wrapped.length))
      ..add(wrapped);
    final fieldBytes = fields.takeBytes();
    final checksum = Uint8List(8)
      ..buffer.asByteData().setUint64(0, getCrc32(fieldBytes) & 0xFFFFFFFF);
    _header =
        (BytesBuilder()
              ..add(_u16(2 + checksum.length + fieldBytes.length))
              ..add(checksum)
              ..add(fieldBytes))
            .takeBytes();
  }

  late final Uint8List _key;
  late final Uint8List _iv;
  late final Uint8List _header;

  String encrypt(String text) {
    final bytes = BytesBuilder()
      ..add(_header)
      ..add(aesCbc(_key, _iv, utf8.encode(text), true));
    return base64Url.encode(bytes.takeBytes()).replaceAll('=', '');
  }

  /// 解密服务端返回的信封文本；头部或校验不符时视为协议变化。
  String decrypt(String encoded) {
    try {
      final padded = encoded + '=' * ((4 - encoded.length % 4) % 4);
      final raw = base64Url.decode(padded);
      if (raw.length < 36 || raw[12] != 0x00 || raw[13] != 0xCB) {
        throw const FormatException('header');
      }
      final data = ByteData.sublistView(raw);
      final headerSize = data.getUint16(0);
      final tokenSize = raw[17];
      final keySizeOffset = 34 + tokenSize;
      final keySize = data.getUint16(keySizeOffset);
      if (headerSize != keySizeOffset + 2 + keySize ||
          headerSize >= raw.length) {
        throw const FormatException('size');
      }
      final crc = data.getUint64(2);
      if (crc != getCrc32(raw.sublist(10, headerSize)) & 0xFFFFFFFF) {
        throw const FormatException('crc');
      }
      return utf8.decode(aesCbc(_key, _iv, raw.sublist(headerSize), false));
    } on Object catch (error) {
      if (error is CloudNoteException) rethrow;
      throw const CloudNoteException(
        CloudNoteFailure.protocolChanged,
        'vivo envelope',
      );
    }
  }

  static Uint8List _u16(int value) =>
      Uint8List(2)..buffer.asByteData().setUint16(0, value);
}

/// AES-CBC + PKCS#7 填充；[encrypt] 为 false 时解密。
Uint8List aesCbc(List<int> key, List<int> iv, List<int> data, bool encrypt) {
  final cipher =
      PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))..init(
        encrypt,
        PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
          ParametersWithIV<KeyParameter>(
            KeyParameter(Uint8List.fromList(key)),
            Uint8List.fromList(iv),
          ),
          null,
        ),
      );
  return cipher.process(Uint8List.fromList(data));
}

/// RSA PKCS#1 v1.5 公钥加密。
Uint8List rsaPkcs1Encrypt(RSAPublicKey key, List<int> data, Random random) {
  final seed = Uint8List.fromList([
    for (var i = 0; i < 32; i++) random.nextInt(256),
  ]);
  final secure = FortunaRandom()..seed(KeyParameter(seed));
  final cipher = PKCS1Encoding(RSAEngine())
    ..init(
      true,
      ParametersWithRandom<PublicKeyParameter<RSAPublicKey>>(
        PublicKeyParameter<RSAPublicKey>(key),
        secure,
      ),
    );
  return cipher.process(Uint8List.fromList(data));
}

/// 解析 PEM 格式的 SubjectPublicKeyInfo RSA 公钥。
RSAPublicKey rsaPublicKeyFromPem(String pem) {
  final body = pem
      .replaceAll(RegExp(r'-----[^-]+-----'), '')
      .replaceAll(RegExp(r'\s+'), '');
  final info = ASN1Parser(base64.decode(body)).nextObject() as ASN1Sequence;
  final bits = info.elements![1] as ASN1BitString;
  final key =
      ASN1Parser(Uint8List.fromList(bits.stringValues!)).nextObject()
          as ASN1Sequence;
  final modulus = (key.elements![0] as ASN1Integer).integer!;
  final exponent = (key.elements![1] as ASN1Integer).integer!;
  return RSAPublicKey(modulus, exponent);
}

/// OPPO 网页版公开的 RSA 公钥（官方网页客户端内置，2026-09）。
const String oppoPublicKeyPem = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAlh6qqqYM/E/ruZ+nb/epfhCWMlVKJqFpzc9AL7PIl5mdk/HN1U57Z4kFMvT+m81kYle3foPWrl02bZ93BtmYPW5fEEHw2gRgTNum9BMhKEVSuvkBTLxqVoOA+iOwPsSZMUNAOg6eTWK93JeUSKBa2VZTNegBvVXZyq1nXrq40QuixZlViX6eR0QgHNVzb3q/qmRdXulRWtVr48plzVr2oRnVb+iPapswfeAuUT173IiIDDShdAU52wcBuvW6LKBw3y7XqfOm8yPBumSQ5px/4XyI6lcJnIWybTPlSW9BEiuaZzQLvUSj2lvPv4JmZ5omzXO52OlGx0n/HdCoe4eGfQIDAQAB
-----END PUBLIC KEY-----''';

/// vivo 网页版公开的 RSA 公钥（官方笔记模块内置，2026-09）。
const String vivoPublicKeyPem = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvDIrvLpx++MEO5xeVy6yUJrYi5zKLdq9MNNvbLGvLgF7YL9VI9gPWPJR2t5vIKVGhL83s/8Mp7/ZQ80TnNzDhaXfAkSOm6nplmar1HFuZryJ5CrY+aW45sLJP764h7i/CEMOj2CpxKgnGAxS8IMur90F2ffhkRLrSCJxolrSS2jFYi3B7NfX/DiOsh5refr6UFiO2emogzmuG2eyCal0P5gmgLZCXLmxeg9SIT+VG2r2wwFHQjittJZFVlDB4505SltBGzNv3aYI4V6JKALvVryxIgWS7KWAiBwxEOJVbEZgseyT44kCSop9wuDWPqxEjRFENROH5zEpp2x8i0sEqQIDAQAB
-----END PUBLIC KEY-----''';
