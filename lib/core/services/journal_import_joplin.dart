import 'dart:io';

import 'package:path/path.dart' as p;

import 'journal_import_block_writer.dart';
import 'journal_import_html.dart';
import 'journal_import_joplin_archive.dart';
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
/// 日期，缺失时用 created_time/updated_time）→ 发表/更新时间；标签 → 标签；
/// 笔记分属多个笔记本时记下所在笔记本（[JournalImportEntry.notebooks]）；
/// 经纬度 → 坐标。`markup_language: 2`
/// 的笔记正文是 HTML。正文中 `:/<ID>` 指向附件的转为媒体嵌入，指向其他
/// 笔记的保留链接文字。加密、上锁（正文为密文）、回收站中的笔记不导入；冲突副本同样保留。
JournalImportParseResult parseJoplinExport(
  JournalImportInput input,
  JournalMediaStager media,
) {
  final String? root;
  try {
    root =
        input.extractedPath ??
        extractJoplinArchive(input.filePath, media.stagingPath);
  } on FormatException {
    throw const JournalImportFormatException(JournalImportSource.joplin);
  } on RangeError {
    throw const JournalImportFormatException(JournalImportSource.joplin);
  }
  final issues = JournalImportIssues();
  if (root == null) {
    throw const JournalImportFormatException(JournalImportSource.joplin);
  }
  final items = <String, Map<String, String>>{};
  final fallbackTimes = <String, DateTime>{};
  final blobs = <String, String>{};
  for (final file in listJournalExportFiles(root)) {
    final name = p.basename(file.path);
    final itemId = RegExp(r'^([0-9a-fA-F]{32})\.md$').firstMatch(name);
    if (itemId != null && p.basename(file.parent.path) != 'resources') {
      final item = _readItem(file);
      if (item != null &&
          item['id']?.toLowerCase() == itemId.group(1)!.toLowerCase()) {
        if (items.containsKey(item['id'])) {
          throw const JournalImportFormatException(JournalImportSource.joplin);
        }
        items[item['id']!.toLowerCase()] = item;
        fallbackTimes[item['id']!] = file.lastModifiedSync();
      } else {
        issues.skip(JournalSkipReason.unreadable);
      }
      continue;
    }
    final blob = RegExp(r'^([0-9a-fA-F]{32})(\.[^.]+)?$').firstMatch(name);
    if (blob != null && p.basename(file.parent.path) == 'resources') {
      if (blobs.containsKey(blob.group(1)!.toLowerCase())) {
        throw const JournalImportFormatException(JournalImportSource.joplin);
      }
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
  final imported = <Map<String, String>>[];
  for (final note in ofType(1)) {
    final deleted = journalNumber(note['deleted_time']);
    if ((deleted != null && deleted > 0) ||
        _time(note['deleted_time']) != null) {
      continue;
    }
    if (note['encryption_applied'] == '1' ||
        note['is_locked'] == '1' ||
        (note['body'] ?? '').startsWith('JLD')) {
      issues.skip(JournalSkipReason.encrypted);
      continue;
    }
    imported.add(note);
  }
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
      return media.embedFile(
        path,
        name: journalString(resource['title']),
        mime: journalString(resource['mime']),
      );
    }

    final writer = JournalBlockWriter();
    final body = note['body'] ?? '';
    if (note['markup_language'] == '2') {
      JournalHtmlConverter(
        writer,
        resolveEmbed: resolve,
        resolveLink: resolve,
      ).appendHtml(body);
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
            fallbackTimes[id]!,
        updatedAt:
            _time(note['user_updated_time']) ?? _time(note['updated_time']),
        tags: [...?noteTags[id]],
        notebooks: [
          if (notebooks.length > 1 && notebook != null && notebook.isNotEmpty)
            notebook,
        ],
        latitude: hasCoordinate ? latitude : null,
        longitude: hasCoordinate ? longitude : null,
        sourceMetadata: {if (note['is_conflict'] == '1') 'conflict': true},
      ),
    );
  }
  return JournalImportParseResult(
    entries: entries,
    missingMediaCount: media.missingCount,
    skippedNotes: issues.skipped,
  );
}

DateTime? _time(String? raw) {
  final parsed = parseJournalDateTime(raw);
  if (parsed != null) return parsed;
  return (journalNumber(raw) ?? 0) != 0 ? journalEpochTime(raw) : null;
}

/// 按 Joplin 的 `BaseItem.unserialize` 读取一个对象：从末尾向上逐行读取
/// `key: value`（按第一个冒号拆分），遇到第一个空行停止；其上首行为标题，
/// 隔一个空行后为正文。没有 `type_`、ID 不是 32 位十六进制时返回 null。
Map<String, String>? _readItem(File file) {
  final String text;
  try {
    text = readJournalText(
      file,
    ).replaceAll('\r\n', '\n').replaceFirst(RegExp(r'\r?\n$'), '');
  } on FileSystemException {
    return null;
  } on FormatException {
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
