import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart' hide ZLibDecoder;
import 'package:path/path.dart' as p;

import 'backup_zip_encryption.dart';

/// 只读取 ZIP 目录索引；正文按固定块解密/解压/写盘，逐条校验 CRC 与长度。
/// 完全校验结束后调用方才可换入媒体；损坏的 ZIP 不触碰原数据库或文件。
class BackupZipReader {
  const BackupZipReader._();

  /// [only] 非空时仍校验全部条目的路径与类型，但只写出其中列出的条目：导入
  /// 预检只需读载荷判断类型与冲突，不必为此解压整包视频。
  ///
  /// [keepModifiedTimes] 为 true 时把条目记录的修改时间写回解压出的文件：
  /// 其他应用导出的 Markdown 常只有文件时间可作日记日期。
  static void extract(
    String zipPath,
    String directoryPath, {
    String? password,
    Set<String>? only,
    void Function(int)? onChunkRead,
    bool keepModifiedTimes = false,
  }) {
    final input = InputFileStream(zipPath);
    try {
      final directory = ZipDirectory()..read(input, password: password);
      if (directory.fileHeaders.length !=
              directory.totalCentralDirectoryEntries ||
          directory.numberOfThisDisk != 0 ||
          directory.diskWithTheStartOfTheCentralDirectory != 0) {
        throw const FormatException('Incomplete or split backup ZIP directory');
      }
      final paths = <String>{};
      for (final header in directory.fileHeaders) {
        final name = _safeName(header.filename);
        final mode = header.externalFileAttributes >> 16;
        if (header.versionMadeBy >> 8 == 3 && mode & 0xf000 == 0xa000) {
          throw const FormatException('Backup ZIP contains symbolic links');
        }
        if (name.endsWith('/') || (mode & 0xf000 == 0x4000)) continue;
        final normalized = p.posix.normalize(name);
        if (!paths.add(normalized)) {
          throw const FormatException('Duplicate ZIP entry');
        }
        final outputPath = p.joinAll([
          directoryPath,
          ...p.posix.split(normalized),
        ]);
        if (!p.isWithin(directoryPath, outputPath)) {
          throw const FormatException('ZIP entry escapes the backup directory');
        }
        if (only != null && !only.contains(normalized)) continue;
        final file = File(outputPath);
        if (file.existsSync()) {
          throw const FormatException('Duplicate ZIP file path');
        }
        file.parent.createSync(recursive: true);
        _extractEntry(input, header, file, password, onChunkRead);
        if (keepModifiedTimes) _restoreModifiedTime(header, file);
      }
    } finally {
      input.closeSync();
    }
  }

  /// 条目头里的 DOS 日期时间（本地墙钟，秒取偶数）；无效时保留解压时间。
  static void _restoreModifiedTime(ZipFileHeader header, File file) {
    final date = header.lastModifiedFileDate;
    final time = header.lastModifiedFileTime;
    final month = (date >> 5) & 0x0f;
    final day = date & 0x1f;
    if (month < 1 || month > 12 || day < 1) return;
    try {
      file.setLastModifiedSync(
        DateTime(
          1980 + (date >> 9),
          month,
          day,
          time >> 11,
          (time >> 5) & 0x3f,
          (time & 0x1f) * 2,
        ),
      );
    } on FileSystemException {
      // 部分文件系统不允许改时间，退回解压时间不影响导入。
    }
  }

  static String _safeName(String raw) {
    final name = raw.replaceAll('\\', '/');
    // 检查路径段，而不是整串包含 '..'，合法的 report..pdf 必须原样保留。
    if (name.isEmpty ||
        name.contains('\u0000') ||
        p.posix.isAbsolute(name) ||
        RegExp(r'^[a-zA-Z]:').hasMatch(name) ||
        name.split('/').contains('..') ||
        p.posix.normalize(name) == '.') {
      throw const FormatException('Invalid ZIP entry path');
    }
    return name;
  }

  static void _extractEntry(
    InputStream input,
    ZipFileHeader header,
    File file,
    String? password,
    void Function(int)? onChunkRead,
  ) {
    final payload = _payload(input, header);
    final encryption = BackupZipEncryption(
      header,
      password,
      payload.extra,
      payload.raw,
      payload.method,
    );
    // 不关闭 payload.raw：它和 [input] 共用文件句柄，关掉会把后续条目一起关掉。
    final compression = encryption.contentCompression;
    if (compression != ZipFile.zipCompressionStore &&
        compression != ZipFile.zipCompressionDeflate) {
      throw const FormatException('Unsupported backup ZIP compression');
    }
    final output = _CheckedFileSink(file, header.uncompressedSize);
    ByteConversionSink? inflate;
    try {
      if (compression == ZipFile.zipCompressionDeflate) {
        inflate = ZLibDecoder(raw: true).startChunkedConversion(output);
      }
      for (final bytes in encryption.decode(onChunkRead: onChunkRead)) {
        if (inflate == null) {
          output.add(bytes);
        } else {
          inflate.add(bytes);
        }
      }
      inflate?.close();
      if (output.length != header.uncompressedSize ||
          (encryption.requiresCrc && output.crc != header.crc32)) {
        throw const FormatException('Invalid ZIP entry checksum or length');
      }
    } finally {
      output.close();
    }
  }

  static bool isPasswordProtected(String zipPath) {
    final input = InputFileStream(zipPath);
    try {
      final directory = ZipDirectory()..read(input);
      return directory.fileHeaders.any(
        (header) =>
            header.generalPurposeBitFlag & 1 != 0 ||
            header.compressionMethod == ZipFile.zipCompressionAexEncryption,
      );
    } finally {
      input.closeSync();
    }
  }
}

/// 本地头之后的原始数据。archive 4.x 不再公开 `ZipFile.rawContent`，
/// 而读 `file` 会把整段密文留在 ZipFile 里；这里只按中央目录的长度切一个窗口。
({InputStream raw, Uint8List extra, int method}) _payload(
  InputStream input,
  ZipFileHeader header,
) {
  input.setPosition(header.localHeaderOffset);
  if (input.length < 30 || input.readUint32() != ZipFile.zipSignature) {
    throw const FormatException('Invalid ZIP local header');
  }
  // 签名之后：版本、标志、方式、时间、日期、CRC、两个长度，再是两个长度字段。
  if (input.length < 26) {
    throw const FormatException('Invalid ZIP local header');
  }
  input.skip(4);
  final method = input.readUint16();
  input.skip(16);
  final nameLength = input.readUint16();
  final extraLength = input.readUint16();
  if (nameLength > input.length || extraLength > input.length - nameLength) {
    throw const FormatException('Invalid ZIP local header');
  }
  input.skip(nameLength);
  final extra = input.readBytes(extraLength).toUint8List();
  if (header.compressedSize > input.length) {
    throw const FormatException('Truncated ZIP entry');
  }
  return (
    raw: input.readBytes(header.compressedSize),
    extra: extra,
    method: method,
  );
}

class _CheckedFileSink implements Sink<List<int>> {
  _CheckedFileSink(File file, this.expectedLength)
    : _file = file.openSync(mode: FileMode.write);

  final RandomAccessFile _file;
  final int expectedLength;
  int length = 0;
  int crc = 0;
  bool _closed = false;

  @override
  void add(List<int> bytes) {
    if (length + bytes.length > expectedLength) {
      throw const FormatException('ZIP entry exceeds its declared length');
    }
    length += bytes.length;
    crc = getCrc32(bytes, crc);
    _file.writeFromSync(bytes);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _file.closeSync();
  }
}
