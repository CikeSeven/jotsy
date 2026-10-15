import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'journal_import_delta_writer.dart';
import 'journal_import_markdown.dart';
import 'journal_import_media.dart';
import 'journal_import_models.dart';
import 'journal_import_support.dart';

/// 解析 Day One 的 JSON 导出。
///
/// 导出 ZIP 里每个日记本一个 `<日记本名>.json`（`{"metadata": …, "entries":
/// […]}`），媒体按类型放在同级的 `photos/`、`videos/`、`audios/`、`pdfs/`，
/// 文件名是条目里记录的 `md5`。正文是 Markdown，媒体以
/// `![](dayone-moment://<identifier>)`（视频/录音/PDF 为
/// `dayone-moment:/video/<id>` 等）嵌在原位置；正文没引用到的媒体追加在末尾。
///
/// 映射：uuid → 稳定键；creationDate/modifiedDate（UTC）→ 本地发表/更新时间；
/// 首行 Markdown 标题 → 标题；tags → 标签（多个日记本时再加日记本名）；
/// location/weather → 位置与天气；isPinned → 置顶。Day One 没有心情。
JournalImportParseResult parseDayOneExport(
  JournalImportInput input,
  JournalMediaStager media,
) {
  final journals = <({String name, String root, List<Object?> entries})>[];
  final candidates = input.extractedPath == null
      ? [File(input.filePath)]
      : listJournalExportFiles(
          input.extractedPath!,
        ).where((file) => p.extension(file.path).toLowerCase() == '.json');
  for (final file in candidates) {
    final decoded = _tryDecodeJson(file);
    if (decoded is Map && decoded['entries'] is List) {
      journals.add((
        name: p.basenameWithoutExtension(file.path),
        root: file.parent.path,
        entries: decoded['entries'] as List<Object?>,
      ));
    }
  }
  if (journals.isEmpty) {
    throw const JournalImportFormatException(JournalImportSource.dayOne);
  }

  final entries = <JournalImportEntry>[];
  final keys = JournalKeyRegistry();
  for (final journal in journals) {
    final files = _DayOneMediaFiles(journal.root);
    for (final raw in journal.entries) {
      if (raw is! Map) continue;
      final entry = _parseEntry(
        raw.cast<String, Object?>(),
        files,
        media,
        keys,
        journalTag: journals.length > 1 ? journal.name : null,
      );
      if (entry != null) entries.add(entry);
    }
  }
  return JournalImportParseResult(
    entries: entries,
    missingMediaCount: media.missingCount,
  );
}

Object? _tryDecodeJson(File file) {
  try {
    return jsonDecode(file.readAsStringSync());
  } on FormatException {
    return null;
  } on FileSystemException {
    return null;
  }
}

JournalImportEntry? _parseEntry(
  Map<String, Object?> raw,
  _DayOneMediaFiles files,
  JournalMediaStager media,
  JournalKeyRegistry keys, {
  String? journalTag,
}) {
  final createdAt = parseJournalDateTime(raw['creationDate']);
  if (createdAt == null) return null;

  // identifier → 资源描述；正文按 identifier 引用，未引用的按 orderInEntry 追加。
  final resources = <String, _DayOneResource>{};
  for (final kind in _DayOneKind.values) {
    final list = raw[kind.jsonKey];
    if (list is! List) continue;
    for (final item in list.whereType<Map>()) {
      final identifier = journalString(item['identifier']);
      if (identifier == null) continue;
      final order = item['orderInEntry'];
      final duration = item['duration'];
      resources[identifier] = _DayOneResource(
        kind: kind,
        md5: journalString(item['md5']),
        order: order is num ? order.toInt() : resources.length,
        duration: duration is num && duration > 0
            ? Duration(milliseconds: (duration * 1000).round())
            : null,
        name: journalString(item['filename']),
      );
    }
  }
  final referenced = <String>{};
  Map<String, Object?>? embedResource(String identifier) {
    final resource = resources[identifier];
    if (resource == null || !referenced.add(identifier)) return null;
    final path = files.find(resource.kind, resource.md5);
    if (path == null) {
      media.missingCount++;
      return null;
    }
    return media.embedFile(
      path,
      kind: resource.kind.mediaKind,
      name: resource.name,
      duration: resource.duration,
    );
  }

  final writer = JournalDeltaWriter();
  final converter = JournalMarkdownConverter(
    writer,
    resolveEmbed: (source) {
      final identifier = _momentIdentifier(source);
      return identifier == null ? null : embedResource(identifier);
    },
  );
  var text = journalString(raw['text']) ?? '';
  var title = '';
  final lines = text.split('\n');
  final first = lines.indexWhere((line) => line.trim().isNotEmpty);
  final heading = first < 0
      ? null
      : RegExp(r'^ {0,3}#{1,6}\s+(.+?)\s*#*\s*$').firstMatch(lines[first]);
  if (heading != null) {
    // Day One 把首行当标题显示；首行是 Markdown 标题时取作本应用的标题。
    title = converter.plainInline(heading.group(1)!).trim();
    text = lines.sublist(first + 1).join('\n');
  }
  converter.append(text);
  final unreferenced =
      resources.entries
          .where((resource) => !referenced.contains(resource.key))
          .toList()
        ..sort((a, b) => a.value.order.compareTo(b.value.order));
  for (final resource in unreferenced) {
    final data = embedResource(resource.key);
    if (data != null) writer.embed(data);
  }
  final content = writer.build();

  final location = raw['location'];
  final weather = raw['weather'];
  final uuid = journalString(raw['uuid']);
  return JournalImportEntry(
    sourceKey: keys.unique(
      uuid ?? journalWallClockKey(createdAt, seconds: true),
    ),
    title: title,
    contentJson: content.contentJson,
    contentText: content.contentText,
    createdAt: createdAt,
    updatedAt: parseJournalDateTime(raw['modifiedDate']),
    tags: [...journalStringList(raw['tags']), ?journalTag],
    weather: weather is Map
        ? journalWeatherText(
            journalString(weather['conditionsDescription']),
            weather['temperatureCelsius'] as num?,
          )
        : null,
    location: location is Map ? _locationLabel(location) : null,
    latitude: location is Map ? _coordinate(location, 'latitude') : null,
    longitude: location is Map ? _coordinate(location, 'longitude') : null,
    pinned: raw['isPinned'] == true,
  );
}

/// `dayone-moment://ID`（照片）、`dayone-moment:/video/ID` 等 → ID。
String? _momentIdentifier(String source) {
  const scheme = 'dayone-moment:';
  if (!source.startsWith(scheme)) return null;
  final path = source.substring(scheme.length).replaceFirst(RegExp(r'^/+'), '');
  final slash = path.indexOf('/');
  final identifier = slash < 0 ? path : path.substring(slash + 1);
  return identifier.isEmpty ? null : identifier;
}

String? _locationLabel(Map<Object?, Object?> location) {
  final place = journalString(location['placeName']);
  if (place != null) return place;
  final parts = [
    journalString(location['localityName']),
    journalString(location['administrativeArea']),
    journalString(location['country']),
  ].nonNulls.toSet();
  return parts.isEmpty ? null : parts.join(' · ');
}

double? _coordinate(Map<Object?, Object?> location, String key) {
  final latitude = location['latitude'];
  final longitude = location['longitude'];
  if (latitude is! num ||
      longitude is! num ||
      !isJournalCoordinate(latitude, longitude)) {
    return null;
  }
  return (location[key] as num).toDouble();
}

enum _DayOneKind {
  photo('photos', 'photos', JournalMediaKind.image),
  video('videos', 'videos', JournalMediaKind.video),
  audio('audios', 'audios', JournalMediaKind.audio),
  pdf('pdfAttachments', 'pdfs', JournalMediaKind.attachment);

  const _DayOneKind(this.jsonKey, this.directory, this.mediaKind);

  final String jsonKey;
  final String directory;
  final JournalMediaKind mediaKind;
}

class _DayOneResource {
  const _DayOneResource({
    required this.kind,
    required this.md5,
    required this.order,
    this.duration,
    this.name,
  });

  final _DayOneKind kind;
  final String? md5;
  final int order;
  final Duration? duration;
  final String? name;
}

/// 日记本 JSON 同级各媒体目录中“md5 → 文件路径”的索引（不区分扩展名）。
class _DayOneMediaFiles {
  _DayOneMediaFiles(this.root);

  final String root;
  final Map<_DayOneKind, Map<String, String>> _index = {};

  String? find(_DayOneKind kind, String? md5) {
    if (md5 == null) return null;
    final index = _index[kind] ??= {
      for (final file in listJournalExportFiles(p.join(root, kind.directory)))
        p.basenameWithoutExtension(file.path).toLowerCase(): file.path,
    };
    return index[md5.toLowerCase()];
  }
}
