import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart' hide ZLibDecoder;
import 'package:path/path.dart' as p;

import 'backup_zip_encryption.dart';

/// 只读取 ZIP 目录索引；正文按固定块解密/解压/写盘，逐条校验 CRC 与长度。
/// 完全校验结束后调用方才可换入媒体；损坏的 ZIP 不触碰原数据库或文件。
class BackupZipReader {
  const BackupZipReader._();

  static void extract(
    String zipPath,
    String directoryPath, {
    String? password,
    void Function(int)? onChunkRead,
  }) {
    final input = InputFileStream(zipPath);
    try {
      final directory = ZipDirectory.read(input, password: password);
      if (directory.fileHeaders.length !=
              directory.totalCentralDirectoryEntries ||
          directory.numberOfThisDisk != 0 ||
          directory.diskWithTheStartOfTheCentralDirectory != 0) {
        throw const FormatException('Incomplete or split backup ZIP directory');
      }
      final paths = <String>{};
      for (final header in directory.fileHeaders) {
        final name = _safeName(header.filename);
        final mode = (header.externalFileAttributes ?? 0) >> 16;
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
        final file = File(outputPath);
        if (file.existsSync()) {
          throw const FormatException('Duplicate ZIP file path');
        }
        file.parent.createSync(recursive: true);
        _extractEntry(header, file, password, onChunkRead);
      }
    } finally {
      input.closeSync();
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
    ZipFileHeader header,
    File file,
    String? password,
    void Function(int)? onChunkRead,
  ) {
    final compression = header.file!.compressionMethod;
    if (compression != ZipFile.zipCompressionStore &&
        compression != ZipFile.zipCompressionDeflate) {
      throw const FormatException('Unsupported backup ZIP compression');
    }
    final encryption = BackupZipEncryption(header, password);
    final output = _CheckedFileSink(file, header.uncompressedSize!);
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
      final directory = ZipDirectory.read(input);
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
