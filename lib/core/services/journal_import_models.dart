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

  /// Diaro：备份 ZIP（`DiaroBackup.xml` + `media/photo/`）；加密备份不支持。
  diaro,

  /// Evernote / 印象笔记：每个笔记本一个 `.enex`（可多个打包成 ZIP）。
  evernote,

  /// Google Keep：Google Takeout 导出的 ZIP（`Takeout/Keep/*.json` + 附件）。
  googleKeep,

  /// Joplin：JEX 导出（tar），或打包成 ZIP 的 RAW 导出目录。
  joplin,

  /// Memos：v0.31 起的导出 ZIP（Memos Export Format 1.0），或 v0.19 ~ v0.22
  /// 的平铺 Markdown 导出。
  memos,

  /// Markdown / 纯文本笔记：单个 `.md`/`.txt`，或 Obsidian、Bear、Notion
  /// 等导出的 ZIP，每个文件一篇。
  markdown,

  // 以下七个是手机厂商与 WPS 的云端笔记：没有自带的导出，在应用内登录官方
  // 云服务后直接读取（`journal_import_cloud_<平台>.dart`，协议依据开源项目
  // 「笔记互迁」note-bridge-desktop），不经过文件解析。

  /// 小米笔记。
  xiaomiNotes,

  /// 华为备忘录。
  huaweiNotepad,

  /// OPPO 笔记。
  oppoNotes,

  /// vivo 笔记。
  vivoNotes,

  /// 荣耀笔记。
  honorNotes,

  /// 魅族笔记（Flyme）。
  meizuNotes,

  /// WPS 便签。
  wpsNotes,
}

/// 在应用内登录后从云端读取的来源。
const Set<JournalImportSource> cloudJournalSources = {
  JournalImportSource.xiaomiNotes,
  JournalImportSource.huaweiNotepad,
  JournalImportSource.oppoNotes,
  JournalImportSource.vivoNotes,
  JournalImportSource.honorNotes,
  JournalImportSource.meizuNotes,
  JournalImportSource.wpsNotes,
};

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
    this.notebooks = const <String>[],
    this.moodLevel,
    this.weather,
    this.location,
    this.latitude,
    this.longitude,
    this.pinned = false,
    this.archived = false,
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

  /// 来源里这篇所在的日记本 / 笔记本 / 文件夹名称（原样，未规整）。落成
  /// 本应用的日记本、标签还是两者，由 [JournalImportFolderMode] 在生成载荷
  /// 时决定；解析器只负责如实报告，不替用户做选择。
  final List<String> notebooks;

  /// 心情：1（最差）~ 5（最好），来源没有心情或无法换算时为 null。
  final int? moodLevel;
  final String? weather;
  final String? location;
  final double? latitude;
  final double? longitude;
  final bool pinned;

  /// 来源里已归档（如 Google Keep 的归档笔记），导入后同样归档。
  final bool archived;
}

/// 来源里的日记本 / 文件夹（[JournalImportEntry.notebooks]）落成什么：
/// 日记本（默认，保留原来的分本）、标签（旧版行为），或两者都要。
enum JournalImportFolderMode {
  notebooks,
  tags,
  both;

  bool get createsNotebooks => this != tags;

  bool get createsTags => this != notebooks;
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
/// （[noEntries]），或是密钥不公开的加密备份（[encrypted]，如 Diaro）。
/// 界面据此给出具体提示，而不是展示底层解析异常。
class JournalImportFormatException implements Exception {
  const JournalImportFormatException(
    this.source, {
    this.noEntries = false,
    this.encrypted = false,
  });

  final JournalImportSource source;
  final bool noEntries;
  final bool encrypted;

  @override
  String toString() =>
      'JournalImportFormatException(${source.name}'
      '${noEntries ? ', no entries' : ''}'
      '${encrypted ? ', encrypted' : ''})';
}
