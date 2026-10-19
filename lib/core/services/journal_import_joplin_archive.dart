import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'journal_import_dates.dart';

/// JEX 归档的隔离读取：gzip 逐块解到临时 tar；校验每个 tar 头和文件长度，
/// 再只写出 Joplin 对象及资源。损坏、重复路径或截断的归档不能部分成功。
String? extractJoplinArchive(String path, String stagingPath) {
  var tar = File(path);
  final head = _readHead(tar, 512);
  if (head.length >= 2 && head[0] == 0x1F && head[1] == 0x8B) {
    tar = File(p.join(stagingPath, 'jex.tar'));
    _inflate(File(path), tar);
  } else if (!_isTarHeader(head)) {
    return null;
  }
  _validateTar(tar);
  final input = InputFileStream(tar.path);
  final root = p.join(stagingPath, 'jex');
  try {
    final decoder = TarDecoder();
    final archive = decoder.decodeBuffer(input);
    final names = <String>{};
    // Archive 会按名称覆盖重复项；先查 decoder 的完整记录，避免内容悄悄
    // 被后面同名的文件替换，随后仍从 archive 流式写出普通文件。
    for (final entry in decoder.files) {
      final name = _entryName(entry.filename);
      if (name != null && !names.add(name.toLowerCase())) {
        throw const FormatException('Duplicate JEX entry');
      }
    }
    for (final entry in archive.files) {
      final name = _entryName(entry.name);
      if (name == null || !entry.isFile || entry.isSymbolicLink) continue;
      final target = File(p.joinAll([root, ...name.split('/')]));
      target.parent.createSync(recursive: true);
      final output = OutputFileStream(target.path);
      try {
        entry.writeContent(output);
      } finally {
        output.closeSync();
      }
      if (target.lengthSync() != entry.size) {
        throw const FormatException('Incomplete JEX resource');
      }
      final modified = journalEpochTime(entry.lastModTime * 1000);
      if (modified != null) target.setLastModifiedSync(modified);
    }
  } finally {
    input.closeSync();
  }
  return Directory(root).existsSync() ? root : null;
}

String? _entryName(String raw) {
  final name = raw.replaceAll('\\', '/').replaceFirst(RegExp(r'^\./'), '');
  return RegExp(
        r'^(resources/)?[0-9a-fA-F]{32}(\.[A-Za-z0-9_-]{1,16})?$',
      ).hasMatch(name)
      ? name
      : null;
}

void _inflate(File source, File target) {
  final input = source.openSync();
  target.parent.createSync(recursive: true);
  final output = target.openSync(mode: FileMode.write);
  final decoder = gzip.decoder.startChunkedConversion(_FileSink(output));
  try {
    while (true) {
      final chunk = input.readSync(1 << 20);
      if (chunk.isEmpty) break;
      decoder.add(chunk);
    }
    decoder.close();
  } finally {
    input.closeSync();
    output.closeSync();
  }
}

class _FileSink implements Sink<List<int>> {
  _FileSink(this.file);
  final RandomAccessFile file;

  @override
  void add(List<int> data) => file.writeFromSync(data);

  @override
  void close() {}
}

/// archive 3.x 的 TarDecoder 没有真正执行 verify，也会容忍截断内容。
/// 在交给它处理 GNU/PAX 扩展名之前，先逐头校验并确认数据在文件边界内。
void _validateTar(File tar) {
  final input = tar.openSync();
  try {
    final length = input.lengthSync();
    var offset = 0;
    while (offset < length) {
      input.setPositionSync(offset);
      final header = input.readSync(512);
      if (header.length != 512) {
        throw const FormatException('Truncated JEX header');
      }
      if (header.every((byte) => byte == 0)) {
        final terminator = input.readSync(512);
        if (terminator.length != 512 || terminator.any((byte) => byte != 0)) {
          throw const FormatException('Truncated JEX terminator');
        }
        return;
      }
      if (!_isTarHeader(header)) {
        throw const FormatException('Invalid JEX checksum');
      }
      final sizeText = String.fromCharCodes(
        header.sublist(124, 136),
      ).replaceAll(RegExp(r'[\x00 ]'), '');
      final size = sizeText.isEmpty ? 0 : int.tryParse(sizeText, radix: 8);
      if (size == null || size < 0 || size > length - offset - 512) {
        throw const FormatException('Truncated JEX file');
      }
      offset += 512 + ((size + 511) ~/ 512) * 512;
      if (offset > length) throw const FormatException('Truncated JEX padding');
    }
    throw const FormatException('Missing JEX terminator');
  } finally {
    input.closeSync();
  }
}

bool _isTarHeader(List<int> head) {
  if (head.length < 512) return false;
  final field = String.fromCharCodes(
    head.sublist(148, 156),
  ).replaceAll(RegExp(r'[\x00 ]'), '');
  final expected = int.tryParse(field, radix: 8);
  if (expected == null) return false;
  var sum = 0;
  for (var i = 0; i < 512; i++) {
    sum += i >= 148 && i < 156 ? 0x20 : head[i];
  }
  return sum == expected;
}

List<int> _readHead(File file, int length) {
  final handle = file.openSync();
  try {
    return handle.readSync(length);
  } finally {
    handle.closeSync();
  }
}
