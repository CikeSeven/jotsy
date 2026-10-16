import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import 'journal_import_delta_writer.dart';
import 'journal_import_html.dart';
import 'journal_import_markdown.dart';
import 'journal_import_media.dart';
import 'journal_import_models.dart';
import 'journal_import_support.dart';

/// 解析 Joplin 的 JEX 导出（未压缩的 tar），也接受把「RAW - Joplin Export
/// Directory」打包成的 ZIP——两者内容相同。
///
/// 包内每个对象一个 `<32 位 ID>.md`：首行标题、空行、正文（仅笔记有），
/// 再空一行后是 `key: value` 元数据，以 `type_` 结尾（1 笔记、2 笔记本、
/// 4 附件、5 标签、6 笔记-标签关联）；附件文件在 `resources/<ID>.<扩展名>`。
/// 格式依据 Joplin 源码 `BaseItem.serialize/unserialize`。
///
/// 映射：ID → 稳定键；user_created_time/user_updated_time（UTC，用户可改的
/// 日期，缺失时用 created_time/updated_time）→ 发表/更新时间；标签 → 标签，
/// 笔记分属多个笔记本时再加笔记本名；经纬度 → 坐标。`markup_language: 2`
/// 的笔记正文是 HTML。正文中 `:/<ID>` 指向附件的转为媒体嵌入，指向其他
/// 笔记的保留链接文字。加密、上锁（正文为密文）、回收站中与冲突副本不导入。
JournalImportParseResult parseJoplinExport(
  JournalImportInput input,
  JournalMediaStager media,
) {
  final root = input.extractedPath ?? _extractJex(input.filePath, media);
  if (root == null) {
    throw const JournalImportFormatException(JournalImportSource.joplin);
  }
  final items = <String, Map<String, String>>{};
  final blobs = <String, String>{};
  for (final file in listJournalExportFiles(root)) {
    final name = p.basename(file.path);
    final itemId = RegExp(r'^([0-9a-fA-F]{32})\.md$').firstMatch(name);
    if (itemId != null && p.basename(file.parent.path) != 'resources') {
      final item = _readItem(file);
      if (item != null &&
          item['id']?.toLowerCase() == itemId.group(1)!.toLowerCase()) {
        items[item['id']!.toLowerCase()] = item;
      }
      continue;
    }
    final blob = RegExp(r'^([0-9a-fA-F]{32})(\.[^.]+)?$').firstMatch(name);
    if (blob != null && p.basename(file.parent.path) == 'resources') {
      blobs[blob.group(1)!.toLowerCase()] = file.path;
    }
  }
  List<Map<String, String>> ofType(int type) => [
    for (final item in items.values)
      if (item['type_'] == '$type') item,
  ];
  if (items.isEmpty) {
    throw const JournalImportFormatException(JournalImportSource.joplin);
  }

  final folders = {for (final item in ofType(2)) item['id']!: item['title']};
  final tagNames = {for (final item in ofType(5)) item['id']!: item['title']};
  final noteTags = <String, List<String>>{};
  for (final link in ofType(6)) {
    final name = tagNames[link['tag_id']?.toLowerCase()];
    final noteId = link['note_id']?.toLowerCase();
    if (name != null && noteId != null) {
      (noteTags[noteId] ??= <String>[]).add(name);
    }
  }
  final imported = ofType(1).where(_importable).toList(growable: false);
  final notebooks = imported
      .map((note) => note['parent_id']?.toLowerCase())
      .toSet();

  final entries = <JournalImportEntry>[];
  for (final note in imported) {
    final id = note['id']!;
    Map<String, Object?>? resolve(String source) {
      final match = RegExp(
        r'^(?:joplin://|:/)([0-9a-fA-F]{32})',
      ).firstMatch(source.trim());
      if (match == null) return null;
      final targetId = match.group(1)!.toLowerCase();
      final resource = items[targetId];
      // 指向笔记（或包里没有的对象）的链接不是附件，保留文字。
      if (resource == null || resource['type_'] != '4') return null;
      final path = blobs[targetId];
      if (path == null) {
        media.missingCount++;
        return null;
      }
      return media.embedFile(path, name: journalString(resource['title']));
    }

    final writer = JournalDeltaWriter();
    final body = note['body'] ?? '';
    if (note['markup_language'] == '2') {
      JournalHtmlConverter(writer, resolveEmbed: resolve).appendHtml(body);
    } else {
      JournalMarkdownConverter(
        writer,
        resolveEmbed: resolve,
        resolveLink: resolve,
        inlineHtml: true,
      ).append(body);
    }
    final content = writer.build();
    final latitude = double.tryParse(note['latitude'] ?? '');
    final longitude = double.tryParse(note['longitude'] ?? '');
    final hasCoordinate = isJournalCoordinate(latitude, longitude);
    final notebook = folders[note['parent_id']?.toLowerCase()];
    entries.add(
      JournalImportEntry(
        sourceKey: id,
        title: note['title']?.trim() ?? '',
        contentJson: content.contentJson,
        contentText: content.contentText,
        createdAt:
            _time(note['user_created_time']) ??
            _time(note['created_time']) ??
            _time(note['user_updated_time']) ??
            File(input.filePath).lastModifiedSync(),
        updatedAt:
            _time(note['user_updated_time']) ?? _time(note['updated_time']),
        tags: [
          ...?noteTags[id],
          if (notebooks.length > 1 && notebook != null && notebook.isNotEmpty)
            notebook,
        ],
        latitude: hasCoordinate ? latitude : null,
        longitude: hasCoordinate ? longitude : null,
      ),
    );
  }
  return JournalImportParseResult(
    entries: entries,
    missingMediaCount: media.missingCount,
  );
}

bool _importable(Map<String, String> note) =>
    note['encryption_applied'] != '1' &&
    note['is_locked'] != '1' &&
    !(note['body'] ?? '').startsWith('JLD') &&
    note['is_conflict'] != '1' &&
    (int.tryParse(note['deleted_time'] ?? '') ?? 0) == 0;

DateTime? _time(String? raw) {
  final parsed = parseJournalDateTime(raw);
  return parsed == null || parsed.millisecondsSinceEpoch <= 0 ? null : parsed;
}

/// 按 Joplin 的 `BaseItem.unserialize` 读取一个对象：从末尾向上逐行读取
/// `key: value`（按第一个冒号拆分），遇到第一个空行停止；其上首行为标题，
/// 隔一个空行后为正文。没有 `type_`、ID 不是 32 位十六进制时返回 null。
Map<String, String>? _readItem(File file) {
  final String text;
  try {
    text = utf8
        .decode(file.readAsBytesSync(), allowMalformed: true)
        .replaceFirst('﻿', '')
        .replaceFirst(RegExp(r'\r?\n$'), '');
  } on FileSystemException {
    return null;
  }
  final lines = text.split('\n');
  final item = <String, String>{};
  var bodyEnd = 0;
  for (var i = lines.length - 1; i >= 0; i--) {
    final line = lines[i].trim();
    if (line.isEmpty) {
      bodyEnd = i;
      break;
    }
    final colon = line.indexOf(':');
    if (colon < 0) return null;
    final key = line.substring(0, colon).trim();
    final value = line.substring(colon + 1).trim();
    item[key] = key.endsWith('_') ? value : _unescape(value);
  }
  if (item['type_'] == null ||
      !RegExp(r'^[0-9a-fA-F]{32}$').hasMatch(item['id'] ?? '')) {
    return null;
  }
  item['id'] = item['id']!.toLowerCase();
  if (bodyEnd > 0) {
    item['title'] = _unescape(lines.first);
    if (bodyEnd > 2) item['body'] = lines.sublist(2, bodyEnd).join('\n');
  }
  return item;
}

/// Joplin 元数据值的反转义，顺序与 `unserialize_format` 一致。
String _unescape(String value) => value
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\r', '\r')
    .replaceAll('\\\n', r'\n')
    .replaceAll('\\\r', r'\r');

/// 把 JEX（tar，偶尔被 gzip 压缩）解开到暂存区；不是 tar 时返回 null。
///
/// 只写出 `<ID>.md` 与 `resources/<ID>.<扩展名>` 两种条目，其余（包括带
/// `..` 的路径）一律跳过，条目名因此不会越出解压目录。
String? _extractJex(String path, JournalMediaStager media) {
  final InputStreamBase input;
  final head = _readHead(path, 512);
  if (head.length >= 2 && head[0] == 0x1F && head[1] == 0x8B) {
    final compressed = InputFileStream(path);
    try {
      input = InputStream(GZipDecoder().decodeBuffer(compressed));
    } finally {
      compressed.closeSync();
    }
  } else if (_isTarHeader(head)) {
    input = InputFileStream(path);
  } else {
    return null;
  }
  final root = p.join(media.stagingPath, 'jex');
  try {
    final archive = TarDecoder().decodeBuffer(input);
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final name = entry.name.replaceAll('\\', '/').replaceFirst('./', '');
      if (!RegExp(
        r'^(resources/)?[0-9a-fA-F]{32}(\.[A-Za-z0-9_-]{1,16})?$',
      ).hasMatch(name)) {
        continue;
      }
      final target = File(p.joinAll([root, ...name.split('/')]));
      target.parent.createSync(recursive: true);
      final output = OutputFileStream(target.path);
      try {
        entry.writeContent(output);
      } finally {
        output.closeSync();
      }
    }
  } on FormatException {
    return null;
  } on RangeError {
    // 截断的 tar：已解出的部分照常导入。
  } finally {
    input.closeSync();
  }
  return Directory(root).existsSync() ? root : null;
}

/// tar 头块的校验和（148 起 8 字节八进制，计算时该字段按空格计）是否
/// 吻合；同时适用于带 `ustar` 标记的 POSIX 头与老式 v7 头。
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

List<int> _readHead(String path, int length) {
  final handle = File(path).openSync();
  try {
    return handle.readSync(length);
  } finally {
    handle.closeSync();
  }
}
