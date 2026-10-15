import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'journal_import_delta_writer.dart';
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
  var recognized = false;
  for (final file in files) {
    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on FormatException {
      continue;
    } on FileSystemException {
      continue;
    }
    // 单篇导出是一个对象；也接受对象数组，兼容合并过的导出。
    final items = decoded is List ? decoded : [decoded];
    for (final item in items.whereType<Map>()) {
      final raw = item.cast<String, Object?>();
      if (raw['date_journal'] is! num || raw['text'] is! String) continue;
      recognized = true;
      entries.add(_parseEntry(raw, file.parent.path, input, media, keys));
    }
  }
  if (!recognized) {
    throw const JournalImportFormatException(JournalImportSource.journey);
  }
  return JournalImportParseResult(
    entries: entries,
    missingMediaCount: media.missingCount,
  );
}

JournalImportEntry _parseEntry(
  Map<String, Object?> raw,
  String directory,
  JournalImportInput input,
  JournalMediaStager media,
  JournalKeyRegistry keys,
) {
  final createdAt = DateTime.fromMillisecondsSinceEpoch(
    (raw['date_journal'] as num).toInt(),
  );
  final modified = raw['date_modified'];
  final writer = JournalDeltaWriter();
  final text = raw['text'] as String;
  if (raw['type'] == 'html' ||
      (raw['type'] == null && looksLikeJournalHtml(text))) {
    JournalHtmlConverter(writer).appendHtml(text);
  } else {
    JournalMarkdownConverter(writer).append(text);
  }
  for (final name in journalStringList(raw['photos'])) {
    // 文件通常与 JSON 同级；个别导出会把 JSON 与媒体分在不同层级，再回退到根目录。
    final candidates = [
      p.join(directory, p.basename(name)),
      if (input.extractedPath != null)
        p.join(input.extractedPath!, p.basename(name)),
    ];
    final path = candidates.firstWhere(
      (candidate) => File(candidate).existsSync(),
      orElse: () => candidates.first,
    );
    final data = media.embedFile(path);
    if (data != null) writer.embed(data);
  }
  final content = writer.build();

  final latitude = raw['lat'];
  final longitude = raw['lon'];
  final hasCoordinate =
      latitude is num &&
      longitude is num &&
      isJournalCoordinate(latitude, longitude);
  final weather = raw['weather'];
  return JournalImportEntry(
    sourceKey: keys.unique(
      journalString(raw['id']) ?? journalWallClockKey(createdAt, seconds: true),
    ),
    title: journalString(raw['title']) ?? '',
    contentJson: content.contentJson,
    contentText: content.contentText,
    createdAt: createdAt,
    updatedAt: modified is num && modified > 0
        ? DateTime.fromMillisecondsSinceEpoch(modified.toInt())
        : null,
    tags: journalStringList(raw['tags']),
    weather: weather is Map
        ? journalWeatherText(
            journalString(weather['description']),
            weather['degree_c'] as num?,
          )
        : null,
    location: journalString(raw['address']),
    latitude: hasCoordinate ? latitude.toDouble() : null,
    longitude: hasCoordinate ? longitude.toDouble() : null,
  );
}
