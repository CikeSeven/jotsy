import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'journal_import_block_writer.dart';
import 'journal_import_files.dart';
import 'journal_import_html.dart';
import 'journal_import_markdown.dart';
import 'journal_import_media.dart';
import 'journal_import_models.dart';
import 'journal_import_support.dart';

/// 解析 Journey 的 ZIP 导出。
///
/// 每篇日记一个 `<id>.json`，`photos` 列出的媒体文件（照片，也可能是录音或
/// 视频）与 JSON 同级。`text` 在 `type == "html"` 时是 HTML，旧版本是
/// Markdown/纯文本。媒体不在正文中引用，按 `photos` 顺序追加在正文末尾。
///
/// 映射：id → 稳定键；date_journal/date_modified（毫秒时间戳）→ 本地发表/
/// 更新时间；tags → 标签；address、lat/lon → 位置（Journey 用极大值表示
/// 无位置）；weather.description/degree_c → 天气。Journey 的 mood/sentiment
/// 量纲没有公开说明，不做换算。
JournalImportParseResult parseJourneyExport(
  JournalImportInput input,
  JournalMediaStager media,
) {
  final files = input.extractedPath == null
      ? [File(input.filePath)]
      : listJournalExportFiles(
          input.extractedPath!,
        ).where((file) => p.extension(file.path).toLowerCase() == '.json');
  final entries = <JournalImportEntry>[];
  final keys = JournalKeyRegistry();
  final issues = JournalImportIssues();
  final exportFiles = JournalImportFiles(
    input.extractedPath ?? p.dirname(input.filePath),
  );
  var recognized = false;
  for (final file in files) {
    final Object? decoded;
    try {
      decoded = jsonDecode(readJournalText(file));
    } on FormatException {
      continue;
    } on FileSystemException {
      continue;
    }
    // 单篇导出是一个对象；也接受对象数组，兼容合并过的导出。
    final items = decoded is List ? decoded : [decoded];
    for (final item in items.whereType<Map>()) {
      final raw = item.cast<String, Object?>();
      if (!raw.containsKey('date_journal')) continue;
      recognized = true;
      final created = journalEpochTime(raw['date_journal']);
      if (created == null || (raw['text'] != null && raw['text'] is! String)) {
        issues.skip(JournalSkipReason.unreadable);
        continue;
      }
      entries.add(
        _parseEntry(raw, created, file.parent.path, exportFiles, media, keys),
      );
    }
  }
  if (!recognized) {
    throw const JournalImportFormatException(JournalImportSource.journey);
  }
  return JournalImportParseResult(
    entries: entries,
    missingMediaCount: media.missingCount,
    skippedNotes: issues.skipped,
  );
}

JournalImportEntry _parseEntry(
  Map<String, Object?> raw,
  DateTime createdAt,
  String directory,
  JournalImportFiles files,
  JournalMediaStager media,
  JournalKeyRegistry keys,
) {
  final embedded = <String>{};
  Map<String, Object?>? resolve(String source) {
    if (source.toLowerCase().startsWith('data:')) {
      return media.embedDataUri(source);
    }
    if (RegExp(r'^[a-z][a-z0-9+.-]*:', caseSensitive: false).hasMatch(source)) {
      return null;
    }
    final path = files.resolve(source, from: directory);
    if (path == null) {
      media.missingCount++;
      return null;
    }
    final data = media.embedFile(path);
    if (data != null) embedded.add(path);
    return data;
  }

  final writer = JournalBlockWriter();
  final text = raw['text'] as String? ?? '';
  if (raw['type'] == 'html' ||
      (raw['type'] == null && looksLikeJournalHtml(text))) {
    JournalHtmlConverter(
      writer,
      resolveEmbed: resolve,
      resolveLink: resolve,
    ).appendHtml(text);
  } else {
    JournalMarkdownConverter(
      writer,
      resolveEmbed: resolve,
      resolveLink: resolve,
    ).append(text);
  }
  for (final name in journalStringList(raw['photos'])) {
    final path = files.resolve(name, from: directory);
    if (path == null) {
      media.missingCount++;
      continue;
    }
    if (!embedded.add(path)) continue;
    final data = media.embedFile(path);
    if (data != null) writer.embed(data);
  }
  final content = writer.build();

  final latitude = journalNumber(raw['lat']);
  final longitude = journalNumber(raw['lon']);
  final hasCoordinate =
      latitude != null &&
      longitude != null &&
      isJournalCoordinate(latitude, longitude);
  final weather = raw['weather'];
  return JournalImportEntry(
    sourceKey: keys.unique(
      journalId(raw['id']) ?? journalWallClockKey(createdAt, seconds: true),
    ),
    title: journalString(raw['title']) ?? '',
    contentJson: content.contentJson,
    contentText: content.contentText,
    createdAt: createdAt,
    updatedAt: journalEpochTime(raw['date_modified']),
    tags: journalStringList(raw['tags']),
    weather: weather is Map
        ? journalWeatherText(
            journalString(weather['description']),
            journalNumber(weather['degree_c']),
          )
        : null,
    location: journalString(raw['address']),
    latitude: hasCoordinate ? latitude.toDouble() : null,
    longitude: hasCoordinate ? longitude.toDouble() : null,
  );
}
