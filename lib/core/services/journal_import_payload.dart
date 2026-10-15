import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../database/app_database.dart';
import 'backup_payload.dart';
import 'journal_import_models.dart';
import 'settings_service.dart';

/// 导入日记标签未指定颜色时使用的中性色。
const int journalImportFallbackTagColor = 0xFF78909C;

/// 把解析出的第三方日记转换成与备份相同的 [BackupPayload]，交由合并导入
/// （BackupMerge）在一个事务里写入：
///
/// - diaryId 由“来源 + 来源内稳定键”确定性生成（UUID v5 格式），再次导入
///   同一文件时识别为“本机已存在”，可选择跳过或覆盖；
/// - 标签按名称去重，长度截到数据库上限；颜色按 [tagColors] 轮流分配，
///   合并时与本机同名标签复用本机标签与颜色；
/// - 心情 1~5 级换算到心情量表的 1~10 档，取用户当前心情选项中对应的表情；
/// - metadata 与发布页结构一致（stats/context），另记录 `import.source/
///   sourceKey` 以便追溯来源。
///
/// 纯数据转换，不读写数据库与文件。
BackupPayload buildJournalImportPayload(
  JournalImportSource source,
  List<JournalImportEntry> entries, {
  List<String> moodOptions = SettingsService.defaultMoodOptions,
  List<int> tagColors = const <int>[],
}) {
  final tags = <String, Tag>{};
  final diaries = <Diary>[];
  final relations = <DiaryTag>[];
  final seenDiaryIds = <String>{};
  for (final entry in entries) {
    final diaryId = journalImportDiaryId(source, entry.sourceKey);
    // 解析器已为重复键追加序号；这里兜底，避免载荷出现重复 diaryId。
    if (!seenDiaryIds.add(diaryId)) continue;
    final localId = diaries.length + 1;
    diaries.add(
      Diary(
        id: localId,
        diaryId: diaryId,
        title: _clamp(entry.title.trim(), 200),
        content: entry.contentJson,
        contentText: entry.contentText,
        metadata: _metadata(source, entry, _moodEmoji(entry, moodOptions)),
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt.isBefore(entry.createdAt)
            ? entry.createdAt
            : entry.updatedAt,
        isArchived: false,
        isPinned: entry.pinned,
        isDeleted: false,
      ),
    );
    final names = <String>{
      for (final raw in entry.tags)
        if (_clamp(raw.replaceAll(RegExp(r'\s+'), ' ').trim(), 40)
            case final name when name.isNotEmpty)
          name,
    };
    for (final name in names) {
      final tag = tags[name] ??= Tag(
        id: tags.length + 1,
        name: name,
        color: tagColors.isEmpty
            ? journalImportFallbackTagColor
            : tagColors[tags.length % tagColors.length],
      );
      relations.add(DiaryTag(diaryId: localId, tagId: tag.id));
    }
  }
  return BackupPayload(
    diaries: diaries,
    tags: tags.values.toList(growable: false),
    diaryTags: relations,
  );
}

/// 来源 + 稳定键 → UUID v5 格式的 diaryId（与本机生成的 v4 ID 同形）。
String journalImportDiaryId(JournalImportSource source, String sourceKey) {
  final bytes = sha1
      .convert([..._namespace, ...utf8.encode('${source.name}:$sourceKey')])
      .bytes
      .sublist(0, 16);
  bytes[6] = (bytes[6] & 0x0f) | 0x50;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// 固定命名空间，保证不同安装对同一导出生成相同的 diaryId。
const List<int> _namespace = [
  0x6b, 0x2f, 0x9e, 0x41, 0xc7, 0x3d, 0x4a, 0x8e, //
  0x91, 0x5c, 0x0d, 0x7a, 0xe2, 0x64, 0xb8, 0x13,
];

/// 心情 1~5 级在 1~10 档量表上的位置：最差、较差、一般、较好、最好。
const Map<int, int> _moodWeights = {1: 1, 2: 3, 3: 5, 4: 8, 5: 10};

String? _moodEmoji(JournalImportEntry entry, List<String> moodOptions) {
  final weight = _moodWeights[entry.moodLevel];
  return weight == null
      ? null
      : SettingsService.moodForWeight(weight, moodOptions);
}

String _metadata(
  JournalImportSource source,
  JournalImportEntry entry,
  String? moodEmoji,
) {
  final text = entry.contentText.trim();
  final context = <String, Object?>{
    if (entry.location?.trim() case final location? when location.isNotEmpty)
      'location': location,
    if (entry.latitude != null && entry.longitude != null)
      'geo': <String, Object?>{
        'source': 'import',
        'latitude': entry.latitude,
        'longitude': entry.longitude,
      },
    if (entry.weather?.trim() case final weather? when weather.isNotEmpty)
      'weather': weather,
    'moodEmoji': ?moodEmoji,
  };
  return jsonEncode(<String, Object?>{
    'schemaVersion': 1,
    'generatedAt': entry.createdAt.toIso8601String(),
    'stats': <String, Object?>{
      'wordCount': text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length,
      'charCount': text.length,
    },
    'hasCover': false,
    if (context.isNotEmpty) 'context': context,
    'import': <String, Object?>{
      'source': source.name,
      'sourceKey': entry.sourceKey,
    },
  });
}

/// 按 UTF-16 长度截断（数据库按此校验），不拆开代理对。
String _clamp(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    if (buffer.length + char.length > maxLength) break;
    buffer.write(char);
  }
  return buffer.toString();
}
