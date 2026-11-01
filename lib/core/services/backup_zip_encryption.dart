import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'backup_aes_cipher.dart';

const backupZipChunkSize = 64 * 1024;

/// 逐块解密 ZIP 内容并校验认证码。
///
/// [raw] 是本地头之后的原始字节窗口（仍可能加密、仍可能压缩），由调用方
/// 从文件流切出。`ZipFile.getStream` 会整段解密进内存，录音和视频不能走那条路。
class BackupZipEncryption {
  BackupZipEncryption(
    this.header,
    this.password,
    this._extraField,
    this.raw,
    this._localMethod,
  );

  final ZipFileHeader header;
  final String? password;
  final Uint8List _extraField;
  final InputStream raw;

  /// 本地头里的压缩方式。AES 条目这里是 99，真正的方式在扩展头。
  final int _localMethod;

  bool get isAes =>
      header.compressionMethod == ZipFile.zipCompressionAexEncryption;

  /// 正文实际的 STORE / DEFLATE。AES 时中央目录记 99，真正的方式写在
  /// 本地扩展头里，和 archive 3.x 读 `ZipFile.compressionMethod` 的口径一致。
  int get contentCompression => isAes ? _aesMetadata.compression : _localMethod;

  ({int version, int strength, int compression}) get _aesMetadata {
    final extra = InputMemoryStream(_extraField);
    while (extra.length >= 4) {
      final id = extra.readUint16();
      final length = extra.readUint16();
      if (length > extra.length) break;
      final field = extra.readBytes(length);
      if (id != 0x9901) continue;
      if (length != 7) break;
      final version = field.readUint16();
      final vendor = field.readString(size: 2);
      final strength = field.readByte();
      final compression = field.readUint16();
      if ((version == 1 || version == 2) &&
          vendor == 'AE' &&
          strength >= 1 &&
          strength <= 3) {
        return (version: version, strength: strength, compression: compression);
      }
      break;
    }
    throw const FormatException('Invalid ZIP AES metadata');
  }

  // AE-2 uses the authentication code instead of CRC; AE-1 and plain ZIPs
  // still require CRC verification even when encryption authentication passes.
  bool get requiresCrc => !isAes || _aesMetadata.version == 1;

  Iterable<Uint8List> decode({void Function(int)? onChunkRead}) sync* {
    raw.reset();
    final encrypted = header.generalPurposeBitFlag & 1 != 0;
    if (!encrypted) {
      if (isAes) throw const FormatException('Invalid ZIP encryption flags');
      yield* _chunks(raw, raw.length, onChunkRead);
      return;
    }
    if (password == null || password!.isEmpty) {
      throw const FormatException('ZIP password is required');
    }
    if (!isAes) {
      final cipher = _ZipCrypto(password!);
      if (raw.length < 12) {
        throw const FormatException('Truncated ZIP encryption header');
      }
      final check = cipher.decrypt(raw.readBytes(12).toUint8List());
      final expected = header.generalPurposeBitFlag & 8 != 0
          ? header.lastModifiedFileTime >> 8
          : header.crc32 >> 24;
      if (check.last != (expected & 0xff)) {
        throw const FormatException('Incorrect ZIP password');
      }
      for (final bytes in _chunks(raw, raw.length, onChunkRead)) {
        yield cipher.decrypt(bytes);
      }
      return;
    }

    final metadata = _aesMetadata;
    final keySize = 8 + metadata.strength * 8;
    final saltSize = keySize ~/ 2;
    if (raw.length < saltSize + 12) {
      throw const FormatException('Truncated ZIP AES data');
    }
    final salt = raw.readBytes(saltSize).toUint8List();
    final check = raw.readBytes(2).toUint8List();
    final cipher = BackupAesCipher(password!, salt, keySize);
    if (!_bytesEqual(check, cipher.passwordVerifier)) {
      throw const FormatException('Incorrect ZIP password');
    }
    // 认证码按整段密文累计；每块原地解密，不把录音或视频留在内存里。
    for (final bytes in _chunks(raw, raw.length - 10, onChunkRead)) {
      cipher.processChunk(bytes);
      yield bytes;
    }
    final actualMac = cipher.finishAuthentication();
    final expectedMac = raw.readBytes(10).toUint8List();
    if (!_bytesEqual(expectedMac, actualMac)) {
      throw const FormatException('Invalid ZIP authentication code');
    }
  }

  Iterable<Uint8List> _chunks(
    InputStream raw,
    int remaining,
    void Function(int)? onChunkRead,
  ) sync* {
    while (remaining > 0) {
      final count = remaining > backupZipChunkSize
          ? backupZipChunkSize
          : remaining;
      final bytes = raw.readBytes(count).toUint8List();
      if (bytes.length != count) {
        throw const FormatException('Truncated ZIP entry');
      }
      remaining -= count;
      onChunkRead?.call(count);
      yield bytes;
    }
  }
}

/// 兼容外部工具使用的传统 ZIP 密码；按字节更新标准的三个 32 位 key。
class _ZipCrypto {
  _ZipCrypto(String password) {
    for (final byte in password.codeUnits) {
      _update(byte);
    }
  }

  int _key0 = 0x12345678;
  int _key1 = 0x23456789;
  int _key2 = 0x34567890;

  void _update(int byte) {
    // 传统 ZIP 口令用的是不取反的单字节 CRC，不是 getCrc32 的整段校验。
    _key0 = getCrc32Byte(_key0, byte);
    _key1 = ((_key1 + (_key0 & 0xff)) * 134775813 + 1) & 0xffffffff;
    _key2 = getCrc32Byte(_key2, _key1 >> 24);
  }

  Uint8List decrypt(Uint8List bytes) {
    for (var i = 0; i < bytes.length; i++) {
      final temp = (_key2 & 0xffff) | 2;
      final byte = bytes[i] ^ ((temp * (temp ^ 1) >> 8) & 0xff);
      bytes[i] = byte;
      _update(byte);
    }
    return bytes;
  }
}

/// 常量时间比较，避免认证码按第一个不同字节提前返回。
bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var difference = 0;
  for (var i = 0; i < a.length; i++) {
    difference |= a[i] ^ b[i];
  }
  return difference == 0;
}
