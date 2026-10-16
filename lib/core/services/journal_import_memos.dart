import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'journal_import_delta_writer.dart';
import 'journal_import_markdown.dart';
import 'journal_import_media.dart';
import 'journal_import_models.dart';
import 'journal_import_support.dart';

/// 解析 Memos 的导出 ZIP。
///
/// - v0.31 起（设置 › 导出与导入）为「Memos Export Format 1.0」：
///   `manifest.json`（`format` 为 `memos-export`），每条 memo 一个
///   `memos/<uid>.json` 记录与 `contentPath` 指向的 Markdown，附件在
///   `attachments/<uid>/<文件名>`；
/// - v0.19.1 ~ v0.22.4 的 `memos-export.zip` 只有平铺的 Markdown，文件名为
///   `<RFC3339 时间>[-<uid>]-<可见性>.md`（最早的版本只有时间）。
/// v0.22.5 ~ v0.30 没有导出功能，需升级后再导出。
///
/// 映射（1.0 格式）：uid → 稳定键；createTime/updateTime（UTC）→ 发表/
/// 更新时间；正文首行一级标题 → 标题；tags（由正文 `#标签` 推导）→ 标签；
/// pinned → 置顶；ARCHIVED → 归档；location → 位置与坐标。正文里的
/// `![](/file/attachments/<uid>)` 换成对应附件，未在正文引用的附件追加在
/// 末尾（与 Memos 显示一致），外部存储的附件只有链接，保留为链接文字。
/// 评论（带 parent 的记录）同样是本人写下的内容，作为单独的日记导入。
JournalImportParseResult parseMemosExport(
  JournalImportInput input,
  JournalMediaStager media,
) {
  final root = input.extractedPath;
  if (root == null) {
    throw const JournalImportFormatException(JournalImportSource.memos);
  }
  final files = listJournalExportFiles(root);
  final manifest = files
      .where((file) => p.basename(file.path) == 'manifest.json')
      .map((file) => (file, _readJson(file)))
      .where(
        (item) =>
            item.$2 is Map &&
            const {
              'memos-export',
              'memos-archive',
            }.contains((item.$2 as Map)['format']) &&
            '${(item.$2 as Map)['formatVersion']}'.startsWith('1.'),
      )
      .firstOrNull;
  final entries = manifest != null
      ? _parseFormat1(manifest.$1.parent.path, media)
      : _parseLegacy(files);
  if (entries == null) {
    throw const JournalImportFormatException(JournalImportSource.memos);
  }
  return JournalImportParseResult(
    entries: entries,
    missingMediaCount: media.missingCount,
  );
}

Object? _readJson(File file) {
  try {
    return jsonDecode(file.readAsStringSync());
  } on FormatException {
    return null;
  } on FileSystemException {
    return null;
  }
}

List<JournalImportEntry> _parseFormat1(String root, JournalMediaStager media) {
  final directory = Directory(p.join(root, 'memos'));
  final records = directory.existsSync()
      ? (listJournalExportFiles(directory.path)
            .where((file) => p.extension(file.path) == '.json')
            .map(_readJson)
            .whereType<Map>()
            .map((record) => record.cast<String, Object?>())
            .where((record) => journalString(record['uid']) != null)
            .toList())
      : <Map<String, Object?>>[];
  final entries = <JournalImportEntry>[];
  for (final record in records) {
    final createdAt = parseJournalDateTime(record['createTime']);
    if (createdAt == null) continue;
    final contentPath = _inside(root, journalString(record['contentPath']));
    final markdown = contentPath != null && File(contentPath).existsSync()
        ? utf8.decode(File(contentPath).readAsBytesSync(), allowMalformed: true)
        : '';

    final attachments = <String, Map<String, Object?>>{
      for (final item in (record['attachments'] as List?) ?? const [])
        if (item is Map && journalString(item['uid']) != null)
          journalString(item['uid'])!: item.cast<String, Object?>(),
    };
    final used = <String>{};
    Map<String, Object?>? embed(Map<String, Object?> attachment) {
      final path = _inside(root, journalString(attachment['path']));
      if (path == null) return null;
      return media.embedFile(path, name: journalString(attachment['filename']));
    }

    Map<String, Object?>? resolve(String source) {
      final match = RegExp(
        r'^/?file/attachments/([^/?#]+)',
      ).firstMatch(source.trim());
      final attachment = attachments[match?.group(1)];
      if (attachment == null) return null;
      used.add(match!.group(1)!);
      return embed(attachment);
    }

    final writer = JournalDeltaWriter();
    final converter = JournalMarkdownConverter(
      writer,
      resolveEmbed: resolve,
      resolveLink: resolve,
    );
    final (title, body) = _splitTitle(markdown, converter);
    converter.append(body);
    for (final MapEntry(:key, :value) in attachments.entries) {
      if (used.contains(key)) continue;
      final link = journalString(value['externalLink']);
      if (link != null && RegExp(r'^https?://').hasMatch(link)) {
        writer.text(journalString(value['filename']) ?? link, {'link': link});
        writer.endLine();
        continue;
      }
      final data = embed(value);
      if (data != null) writer.embed(data);
    }
    final content = writer.build();

    final location = record['location'];
    final latitude = location is Map ? location['latitude'] : null;
    final longitude = location is Map ? location['longitude'] : null;
    final hasCoordinate =
        latitude is num &&
        longitude is num &&
        isJournalCoordinate(latitude, longitude);
    entries.add(
      JournalImportEntry(
        sourceKey: journalString(record['uid'])!,
        title: title,
        contentJson: content.contentJson,
        contentText: content.contentText,
        createdAt: createdAt,
        updatedAt: parseJournalDateTime(record['updateTime']),
        tags: journalStringList(record['tags']),
        pinned: record['pinned'] == true,
        archived: record['state'] == 'ARCHIVED',
        location: location is Map
            ? journalString(location['placeholder'])
            : null,
        latitude: hasCoordinate ? latitude.toDouble() : null,
        longitude: hasCoordinate ? longitude.toDouble() : null,
      ),
    );
  }
  return entries;
}

/// 旧版平铺导出；没有一个文件符合命名规则时返回 null（不是 Memos 导出）。
List<JournalImportEntry>? _parseLegacy(List<File> files) {
  // 时间后可能依次跟 uid 与可见性；uid 可含 `-`，所以两端锚定。
  final name = RegExp(
    r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:\d{2}))'
    r'(?:(?:-(.+))?-(?:PUBLIC|PROTECTED|PRIVATE))?\.md$',
  );
  final entries = <JournalImportEntry>[];
  final keys = JournalKeyRegistry();
  for (final file in files) {
    final match = name.firstMatch(p.basename(file.path));
    final createdAt = parseJournalDateTime(match?.group(1));
    if (match == null || createdAt == null) continue;
    final writer = JournalDeltaWriter();
    final converter = JournalMarkdownConverter(writer);
    final (title, body) = _splitTitle(
      utf8.decode(file.readAsBytesSync(), allowMalformed: true),
      converter,
    );
    converter.append(body);
    final content = writer.build();
    entries.add(
      JournalImportEntry(
        sourceKey: keys.unique(match.group(2) ?? match.group(1)!),
        title: title,
        contentJson: content.contentJson,
        contentText: content.contentText,
        createdAt: createdAt,
      ),
    );
  }
  return entries.isEmpty ? null : entries;
}

/// Memos 把正文首行的一级标题当作标题。
(String, String) _splitTitle(
  String markdown,
  JournalMarkdownConverter converter,
) {
  final text = markdown.replaceAll('\r\n', '\n');
  final heading = RegExp(r'^# +(.+?)\s*(?:\n|$)').firstMatch(text);
  if (heading == null) return ('', text);
  return (
    converter.plainInline(heading.group(1)!).trim(),
    text.substring(heading.end),
  );
}

/// 导出内的相对路径；越出导出目录的路径返回 null。
String? _inside(String root, String? relative) {
  if (relative == null) return null;
  final path = p.normalize(p.join(root, relative));
  return p.isWithin(root, path) ? path : null;
}
