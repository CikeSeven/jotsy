import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../utils/text_stats.dart';
import '../database/app_database.dart';
import 'backup_payload.dart';
import 'journal_import_models.dart';
import 'journal_import_notebooks.dart';
import 'journal_import_support.dart';
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
/// - 来源日记本 / 文件夹（[JournalImportEntry.notebooks]）按 [folderMode]
///   落成日记本（经 [JournalImportNotebookBuilder]，与本机日记本的复用规则
///   见那里）、标签（旧版行为：接在条目标签之后，与标签同样规整）或两者；
///   [existingNotebooks] 是本机现有日记本，由调用方读库后传入；
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
  JournalImportFolderMode folderMode = JournalImportFolderMode.notebooks,
  List<NotebookRow> existingNotebooks = const <NotebookRow>[],
  DateTime? now,
}) {
  final notebooks = JournalImportNotebookBuilder(
    source: source,
    existing: existingNotebooks,
    colors: tagColors,
    fallbackColor: journalImportFallbackTagColor,
    now: now ?? DateTime.now(),
  );
  final tags = <String, Tag>{};
  final diaries = <Diary>[];
  final relations = <DiaryTag>[];
  final keys = JournalKeyRegistry();
  for (final entry in entries) {
    // 即使某个来源返回了重复 ID，也不能丢掉后面的正文。保持第一次的稳定
    // ID，其余确定性分配后缀；云端分页的重复另在读取阶段视为协议错误。
    final sourceKey = keys.unique(entry.sourceKey);
    final diaryId = journalImportDiaryId(source, sourceKey);
    final localId = diaries.length + 1;
    diaries.add(
      Diary(
        id: localId,
        diaryId: diaryId,
        title: _clamp(entry.title.trim(), 200),
        content: entry.contentJson,
        contentText: entry.contentText,
        metadata: _metadata(
          source,
          sourceKey,
          entry,
          _moodEmoji(entry, moodOptions),
          folderMode,
        ),
        createdAt: entry.createdAt,
        updatedAt: entry.updatedAt.isBefore(entry.createdAt)
            ? entry.createdAt
            : entry.updatedAt,
        isArchived: entry.archived,
        isPinned: entry.pinned,
        isDeleted: false,
      ),
    );
    final names = <String>{
      for (final raw in [
        ...entry.tags,
        if (folderMode.createsTags) ...entry.notebooks,
      ])
        if (_tagName(raw) case final name when name.isNotEmpty) name,
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
    if (folderMode.createsNotebooks) notebooks.add(localId, entry.notebooks);
  }
  return BackupPayload(
    diaries: diaries,
    tags: tags.values.toList(growable: false),
    diaryTags: relations,
    notebooks: notebooks.notebooks,
    diaryNotebooks: notebooks.memberships,
  );
}

/// 来源 + 稳定键 → UUID v5 格式的 diaryId（与本机生成的 v4 ID 同形）。
String journalImportDiaryId(JournalImportSource source, String sourceKey) =>
    _uuidV5(_namespace, '${source.name}:$sourceKey');

/// 来源 + 规整后的名称（见 [normalizeJournalImportNotebookName]）→ UUID v5
/// 格式的 notebookId。命名空间与日记的不同：来源里某篇的稳定键恰好与某个
/// 日记本名相同时，两者也不会得到同一个 id。
String journalImportNotebookId(JournalImportSource source, String name) =>
    _uuidV5(_notebookNamespace, '${source.name}:$name');

String _uuidV5(List<int> namespace, String name) {
  final bytes = sha1
      .convert([...namespace, ...utf8.encode(name)])
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

/// 日记本 id 的固定命名空间。
const List<int> _notebookNamespace = [
  0x3a, 0xd1, 0x57, 0x0e, 0x8b, 0x42, 0x4f, 0x96, //
  0xa4, 0x1f, 0x63, 0xc8, 0x2d, 0x75, 0xe9, 0x0b,
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
  String sourceKey,
  JournalImportEntry entry,
  String? moodEmoji,
  JournalImportFolderMode folderMode,
) {
  final text = entry.contentText.trim();
  final context = <String, Object?>{
    if (entry.location?.trim() case final location? when location.isNotEmpty)
      'location': location,
    if (isJournalCoordinate(entry.latitude, entry.longitude))
      'geo': <String, Object?>{
        'source': 'import',
        'latitude': entry.latitude,
        'longitude': entry.longitude,
      },
    if (entry.weather?.trim() case final weather? when weather.isNotEmpty)
      'weather': weather,
    'moodEmoji': ?moodEmoji,
  };
  // 与界面上的“字数”同一口径（见 TextStats）。
  final stats = TextStats.of(text);
  return jsonEncode(<String, Object?>{
    'schemaVersion': 1,
    'generatedAt': entry.createdAt.toIso8601String(),
    'stats': <String, Object?>{
      'wordCount': stats.words,
      'charCount': stats.characters,
    },
    'hasCover': false,
    if (context.isNotEmpty) 'context': context,
    'import': <String, Object?>{
      'source': source.name,
      'sourceKey': sourceKey,
      if (sourceKey != entry.sourceKey) 'originalSourceKey': entry.sourceKey,
      if (_clamp(entry.title.trim(), 200) != entry.title)
        'originalTitle': entry.title,
      if (entry.tags.any((tag) => _tagName(tag) != tag))
        'originalTags': entry.tags,
      // 来源日记本 / 文件夹名同理：按所选方式落地时被规整或截断（标签 40、
      // 日记本 60）就留下原名，免得长名称的后半截悄悄丢了。
      if (entry.notebooks.any(
        (name) =>
            (folderMode.createsTags && _tagName(name) != name) ||
            (folderMode.createsNotebooks &&
                normalizeJournalImportNotebookName(name) != name),
      ))
        'originalNotebooks': entry.notebooks,
      if (entry.sourceMetadata.isNotEmpty) 'details': entry.sourceMetadata,
    },
  });
}

/// 标签名规整：连续空白合成一个空格、去首尾空白、截到数据库上限 40。
String _tagName(String raw) =>
    _clamp(raw.replaceAll(RegExp(r'\s+'), ' ').trim(), 40);

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
