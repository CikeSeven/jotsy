import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'backup_aes_cipher.dart';

const backupZipChunkSize = 64 * 1024;

/// 复用 archive 的 AES 与密码派生，逐块解密 ZIP 内容并校验认证码。
/// 不调用 ZipFile.content，避免把整个录音/视频条目缓存到内存。
class BackupZipEncryption {
  BackupZipEncryption(this.header, this.password);

  final ZipFileHeader header;
  final String? password;

  bool get isAes =>
      header.compressionMethod == ZipFile.zipCompressionAexEncryption;

  ({int version, int strength}) get _aesMetadata {
    final extra = InputStream(header.file!.extraField);
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
      if ((version == 1 || version == 2) &&
          vendor == 'AE' &&
          strength >= 1 &&
          strength <= 3) {
        return (version: version, strength: strength);
      }
      break;
    }
    throw const FormatException('Invalid ZIP AES metadata');
  }

  // AE-2 uses the authentication code instead of CRC; AE-1 and plain ZIPs
  // still require CRC verification even when encryption authentication passes.
  bool get requiresCrc => !isAes || _aesMetadata.version == 1;

  Iterable<Uint8List> decode({void Function(int)? onChunkRead}) sync* {
    final raw = header.file!.rawContent!;
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
          : header.crc32! >> 24;
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
    // 保持 archive 3.x 的密码编码，兼容已经导出的加密备份。
    final cipher = BackupAesCipher(password!, salt, keySize);
    if (!Uint8ListEquality.equals(check, cipher.passwordVerifier)) {
      throw const FormatException('Incorrect ZIP password');
    }
    // 除最后一块外固定为 16 的倍数，使 archive AES 的 counter 连续。
    // Aes.processData 会逐次重置内部 MAC，因此另外累计整条目的认证码。
    for (final bytes in _chunks(raw, raw.length - 10, onChunkRead)) {
      cipher.processChunk(bytes);
      yield bytes;
    }
    final actualMac = cipher.finishAuthentication();
    final expectedMac = raw.readBytes(10).toUint8List();
    if (!Uint8ListEquality.equals(expectedMac, actualMac)) {
      throw const FormatException('Invalid ZIP authentication code');
    }
  }

  Iterable<Uint8List> _chunks(
    InputStreamBase raw,
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
    _key0 = CRC32(_key0, byte);
    _key1 = ((_key1 + (_key0 & 0xff)) * 134775813 + 1) & 0xffffffff;
    _key2 = CRC32(_key2, _key1 >> 24);
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
