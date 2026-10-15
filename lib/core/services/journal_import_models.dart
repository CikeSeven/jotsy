/// 可导入的其他日记应用。每个来源对应一种导出格式的解析器，
/// 详见 `journal_import_<来源>.dart`。
///
/// 枚举名会写进导入日记的 metadata（`import.source`）并参与生成稳定的
/// diaryId，改名会让再次导入同一文件时识别不出重复。
enum JournalImportSource {
  /// Day One：「导出 JSON」得到的 ZIP（`<日记本>.json` + photos/videos/
  /// audios/pdfs 目录），也接受单独的 JSON。
  dayOne,

  /// Journey：导出 ZIP，每篇一个 `<id>.json`，媒体文件与之同级。
  journey,

  /// Diarium：JSON 导出（日记数组），或 `.diary` 备份（SQLite 数据库）。
  diarium,

  /// Daylio：`.daylio` 备份（ZIP 内 base64 编码的 JSON + assets），或 CSV 导出。
  daylio,

  /// Apple 手记（Journal）：「导出所有手记条目」得到的 HTML 文件夹 ZIP。
  appleJournal,
}

/// 第三方导出中识别出的一篇日记，正文已转换为本应用的 Delta JSON。
///
/// 正文里的媒体已放进导入暂存区的托管目录结构（见 `JournalMediaStager`），
/// 合并导入时由 BackupMediaPaths 重绑到本机的批次目录。
class JournalImportEntry {
  const JournalImportEntry({
    required this.sourceKey,
    required this.contentJson,
    required this.contentText,
    required this.createdAt,
    DateTime? updatedAt,
    this.title = '',
    this.tags = const <String>[],
    this.moodLevel,
    this.weather,
    this.location,
    this.latitude,
    this.longitude,
    this.pinned = false,
  }) : updatedAt = updatedAt ?? createdAt;

  /// 来源应用内稳定的条目标识，同一导出文件再次导入时不变，用于生成
  /// diaryId 判定“本机已存在”。
  final String sourceKey;

  final String title;
  final String contentJson;

  /// 正文纯文本镜像（列表摘要与检索用）。
  final String contentText;

  /// 发表时间：本地墙钟时间。
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;

  /// 心情：1（最差）~ 5（最好），来源没有心情或无法换算时为 null。
  final int? moodLevel;
  final String? weather;
  final String? location;
  final double? latitude;
  final double? longitude;
  final bool pinned;
}

/// 解析结果：日记与缺失的媒体数（导出里有引用、但文件不在包内）。
class JournalImportParseResult {
  const JournalImportParseResult({
    required this.entries,
    this.missingMediaCount = 0,
  });

  final List<JournalImportEntry> entries;
  final int missingMediaCount;
}

/// 所选文件不是对应来源的导出格式，或格式正确但没有可导入的日记
/// （[noEntries]）。界面据此给出具体提示，而不是展示底层解析异常。
class JournalImportFormatException implements Exception {
  const JournalImportFormatException(this.source, {this.noEntries = false});

  final JournalImportSource source;
  final bool noEntries;

  @override
  String toString() =>
      'JournalImportFormatException(${source.name}'
      '${noEntries ? ', no entries' : ''})';
}
