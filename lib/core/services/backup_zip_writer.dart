import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'backup_aes_cipher.dart';
import 'backup_zip_encryption.dart';

/// 将私有工作目录逐文件写为 WinZip AES-256 ZIP，不缓存加密条目。
/// 媒体本身多已压缩，使用 STORE；统一 ZIP64，确保大视频的长度和偏移不截断。
/// 先流式计算 CRC 再加密，保持 AE-1 及旧版 archive 备份导入兼容性。
class BackupZipWriter {
  const BackupZipWriter._();

  static void writeEncryptedDirectory(
    String rootPath,
    String zipPath,
    String password,
  ) {
    final output = OutputFileStream(zipPath);
    final random = Random.secure();
    final entries = <_ZipEntry>[];
    try {
      for (final file in Directory(
        rootPath,
      ).listSync(recursive: true, followLinks: false).whereType<File>()) {
        final input = InputFileStream(file.path);
        try {
          var crc = 0;
          for (final bytes in _chunks(input)) {
            crc = getCrc32(bytes, crc);
          }
          input.reset();
          final entry = _ZipEntry(
            utf8.encode(
              p.relative(file.path, from: rootPath).replaceAll('\\', '/'),
            ),
            file.lengthSync(),
            output.length,
            crc,
            file.statSync(),
          );
          _writeLocalHeader(output, entry);
          final salt = Uint8List.fromList(
            List.generate(16, (_) => random.nextInt(256)),
          );
          final cipher = BackupAesCipher(password, salt, 32, encrypt: true);
          output.writeBytes(salt);
          output.writeBytes(cipher.passwordVerifier);
          for (final bytes in _chunks(input)) {
            cipher.processChunk(bytes);
            output.writeBytes(bytes);
          }
          output.writeBytes(cipher.finishAuthentication());
          entries.add(entry);
        } finally {
          input.closeSync();
        }
      }
      final directoryOffset = output.length;
      for (final entry in entries) {
        _writeCentralHeader(output, entry);
      }
      _writeEndRecords(output, entries.length, directoryOffset);
    } catch (_) {
      output.closeSync();
      File(zipPath).deleteSync();
      rethrow;
    } finally {
      output.closeSync();
    }
  }

  static Iterable<Uint8List> _chunks(InputFileStream input) sync* {
    while (!input.isEOS) {
      final count = min(input.length, backupZipChunkSize);
      yield input.readBytes(count).toUint8List();
    }
  }

  static void _writeLocalHeader(OutputFileStream output, _ZipEntry entry) {
    output
      ..writeUint32(0x04034b50)
      ..writeUint16(51) // AES requires ZIP version 5.1.
      ..writeUint16(0x0801) // UTF-8 filename and encrypted content.
      ..writeUint16(99)
      ..writeUint16(entry.time)
      ..writeUint16(entry.date)
      ..writeUint32(entry.crc)
      ..writeUint32(0xffffffff)
      ..writeUint32(0xffffffff)
      ..writeUint16(entry.name.length)
      ..writeUint16(31)
      ..writeBytes(entry.name)
      ..writeUint16(1) // ZIP64 local sizes.
      ..writeUint16(16)
      ..writeUint64(entry.size)
      ..writeUint64(entry.encryptedSize);
    _writeAesExtra(output);
  }

  static void _writeCentralHeader(OutputFileStream output, _ZipEntry entry) {
    output
      ..writeUint32(0x02014b50)
      ..writeUint16((3 << 8) | 51) // UNIX permissions, ZIP version 5.1.
      ..writeUint16(51)
      ..writeUint16(0x0801)
      ..writeUint16(99)
      ..writeUint16(entry.time)
      ..writeUint16(entry.date)
      ..writeUint32(entry.crc)
      ..writeUint32(0xffffffff)
      ..writeUint32(0xffffffff)
      ..writeUint16(entry.name.length)
      ..writeUint16(39)
      ..writeUint16(0) // Comment length.
      ..writeUint16(0) // Disk number.
      ..writeUint16(0) // Internal attributes.
      ..writeUint32(entry.mode << 16)
      ..writeUint32(0xffffffff)
      ..writeBytes(entry.name)
      ..writeUint16(1)
      ..writeUint16(24)
      ..writeUint64(entry.size)
      ..writeUint64(entry.encryptedSize)
      ..writeUint64(entry.offset);
    _writeAesExtra(output);
  }

  static void _writeAesExtra(OutputFileStream output) {
    output
      ..writeUint16(0x9901)
      ..writeUint16(7)
      ..writeUint16(1) // AE-1 retains a CRC in addition to authentication.
      ..writeBytes(const [0x41, 0x45]) // WinZip vendor "AE".
      ..writeByte(3) // AES-256.
      ..writeUint16(0); // STORE.
  }

  static void _writeEndRecords(OutputFileStream output, int count, int offset) {
    final size = output.length - offset;
    final endOffset = output.length;
    output
      ..writeUint32(0x06064b50)
      ..writeUint64(44)
      ..writeUint16((3 << 8) | 51)
      ..writeUint16(51)
      ..writeUint32(0)
      ..writeUint32(0)
      ..writeUint64(count)
      ..writeUint64(count)
      ..writeUint64(size)
      ..writeUint64(offset)
      ..writeUint32(0x07064b50)
      ..writeUint32(0)
      ..writeUint64(endOffset)
      ..writeUint32(1)
      ..writeUint32(0x06054b50)
      ..writeUint16(0)
      ..writeUint16(0)
      ..writeUint16(0xffff)
      ..writeUint16(0xffff)
      ..writeUint32(0xffffffff)
      ..writeUint32(0xffffffff)
      ..writeUint16(0);
  }
}

class _ZipEntry {
  _ZipEntry(this.name, this.size, this.offset, this.crc, FileStat stat)
    : mode = stat.mode,
      time =
          (stat.modified.hour << 11) |
          (stat.modified.minute << 5) |
          (stat.modified.second ~/ 2),
      date =
          ((stat.modified.year.clamp(1980, 2107).toInt() - 1980) << 9) |
          (stat.modified.month << 5) |
          stat.modified.day;

  final List<int> name;
  final int size;
  final int offset;
  final int crc;
  final int mode;
  final int time;
  final int date;
  int get encryptedSize => size + 28; // Salt, password check, authentication.
}
