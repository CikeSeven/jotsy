import 'journal_import_models.dart';

/// 备份文件的类型，决定可用的导入方式。
enum BackupArchiveKind {
  /// 完整备份（`backup_data.json`）：全部日记、标签、媒体与应用设置。
  fullBackup,

  /// 日记包（`diary_package.json`）：一篇或几篇日记及其标签、媒体，不含设置。
  diaryPackage,

  /// 其他日记应用的导出（见 [JournalImportSource]），转换后只能合并导入。
  journalExport,
}

/// 导入方式。
///
/// 日记按业务 diaryId 判定是否“同一篇”；本地自增 id 在不同安装之间没有意义。
enum BackupImportMode {
  /// 合并：保留本机全部数据，只新增本机没有的日记；本机已有的同一篇日记保持
  /// 本机版本。标签按名称复用，不修改应用设置与新建日记草稿；日记模板只新增
  /// 本机没有的；日记本只新增本机没有的，本机已有的保持本机定义。
  merge,

  /// 合并并覆盖：在 [merge] 的基础上，把本机已有的同一篇日记整篇替换为文件
  /// 中的版本（正文、标签、归档/置顶/回收站状态一并替换）；同一条纪念日同样
  /// 替换为文件中的版本；同一个日记本的定义替换为文件中的版本（书架顺序保留
  /// 本机的）。日记模板仍只新增、不替换本机已有的。
  mergeOverwrite,

  /// 覆盖全部：清空本机日记、标签、媒体与设置后换入备份内容，仅限完整备份。
  replaceAll;

  /// 是否会永久改写本机已有数据；UI 必须先经严重警告确认。
  bool get overwritesLocalData => this != merge;
}

/// 导入前的只读预检结果，用于选择导入方式与组织警告文案；生成过程不修改
/// 本机任何数据。
class BackupArchivePreview {
  const BackupArchivePreview({
    required this.kind,
    required this.diaryCount,
    required this.tagCount,
    required this.existingDiaryCount,
    required this.localDiaryCount,
    required this.localTagCount,
    this.soleDiaryTitle,
    this.journalSource,
    this.missingMediaCount = 0,
    this.skippedNotes = const <JournalSkipReason, int>{},
    this.summaryOnlyCount = 0,
    this.partialContentCount = 0,
    this.anniversaryCount = 0,
    this.existingAnniversaryCount = 0,
    this.localAnniversaryCount = 0,
    this.localTemplateCount = 0,
    this.localNotebookCount = 0,
    this.existingNotebookCount = 0,
    this.existingDayMoodCount = 0,
    this.localDayMoodCount = 0,
  });

  final BackupArchiveKind kind;

  /// 文件内的日记数（含归档、回收站与时间胶囊）。
  final int diaryCount;
  final int tagCount;

  /// 文件内本机已有的日记数，也就是 [BackupImportMode.mergeOverwrite] 会替换
  /// 的篇数。
  final int existingDiaryCount;

  /// 本机当前日记总数（含归档与回收站），即 [BackupImportMode.replaceAll]
  /// 会删除的篇数。
  final int localDiaryCount;
  final int localTagCount;

  /// 文件只含一篇日记时它的标题（可能为空串），确认时点名是哪一篇。
  final String? soleDiaryTitle;

  /// [BackupArchiveKind.journalExport] 时导出来自哪个应用。
  final JournalImportSource? journalSource;

  /// 导出中被引用、但文件不在包内而将被跳过的媒体数。
  final int missingMediaCount;

  /// 其他应用的笔记中整篇跳过的篇数（按原因），见 [JournalSkipReason]。
  final Map<JournalSkipReason, int> skippedNotes;

  /// 其他应用的笔记中正文读不到、只导入了摘要的篇数。
  final int summaryOnlyCount;

  /// 保留了可读正文及原始信息，但含无法解密或显示片段的笔记数。
  final int partialContentCount;

  /// 文件内的纪念日数（只有完整备份带纪念日）。
  final int anniversaryCount;

  /// 文件内本机已有（按 anniversaryId）的纪念日数。
  final int existingAnniversaryCount;

  /// 本机当前纪念日总数，即 [BackupImportMode.replaceAll] 会删除的条数——
  /// 不含纪念日的旧备份覆盖导入后，本机纪念日会被清空，警告里要列出来。
  final int localAnniversaryCount;

  /// 本机当前的用户模板数，即 [BackupImportMode.replaceAll] 会删除的个数——
  /// 不含模板的旧备份覆盖导入后，本机模板会被清空，警告里要列出来。
  final int localTemplateCount;

  /// 本机当前的日记本数，即 [BackupImportMode.replaceAll] 会删除的个数——
  /// 不含日记本的旧备份覆盖导入后，本机日记本会被清空，警告里要列出来。
  final int localNotebookCount;

  /// 文件内本机已有（按 notebookId）的日记本数，即
  /// [BackupImportMode.mergeOverwrite] 会替换定义的个数。日记本重复本身不
  /// 提供“覆盖已存在”（见 [availableModes]），只在说明里补一行。
  final int existingNotebookCount;

  /// 文件内本机那天也记了心情的天数，即 [BackupImportMode.mergeOverwrite]
  /// 会替换的天数（只有完整备份带心情）。
  final int existingDayMoodCount;

  /// 本机记了心情的天数，即 [BackupImportMode.replaceAll] 会删除的条数——
  /// 不含心情的旧备份覆盖导入后，本机记下的心情会被清空，警告里要列出来。
  final int localDayMoodCount;

  /// 当前文件可用的导入方式，按“安全在前”的展示顺序排列：没有已存在的日记、
  /// 纪念日或心情时不提供“覆盖已存在”；日记包与其他应用的导出不能覆盖全部
  /// 数据。
  List<BackupImportMode> get availableModes => <BackupImportMode>[
    BackupImportMode.merge,
    if (existingDiaryCount > 0 ||
        existingAnniversaryCount > 0 ||
        existingDayMoodCount > 0)
      BackupImportMode.mergeOverwrite,
    if (kind == BackupArchiveKind.fullBackup) BackupImportMode.replaceAll,
  ];
}

/// 导入完成后的统计，用于结果提示。
class BackupImportResult {
  const BackupImportResult({
    required this.mode,
    required this.addedDiaries,
    required this.replacedDiaries,
    required this.skippedDiaries,
    this.addedAnniversaries = 0,
    this.replacedAnniversaries = 0,
    this.skippedAnniversaries = 0,
    this.addedTemplates = 0,
    this.addedNotebooks = 0,
    this.addedDayMoods = 0,
    this.replacedDayMoods = 0,
    this.addedComments = 0,
    this.replacedComments = 0,
  });

  final BackupImportMode mode;

  /// 新增的日记数；[BackupImportMode.replaceAll] 时为换入的全部日记数。
  final int addedDiaries;

  /// 被导入版本替换的本机日记数。
  final int replacedDiaries;

  /// 本机已有、按 [BackupImportMode.merge] 保留本机版本而跳过的日记数。
  final int skippedDiaries;

  /// 纪念日的同口径统计；[BackupImportMode.replaceAll] 时新增数为换入的
  /// 全部纪念日数。
  final int addedAnniversaries;
  final int replacedAnniversaries;
  final int skippedAnniversaries;

  /// 新增的日记模板数；[BackupImportMode.replaceAll] 时为换入的全部模板数。
  final int addedTemplates;

  /// 新增的日记本数（只算新建的定义，替换或保留本机已有的不计）；
  /// [BackupImportMode.replaceAll] 时为换入的全部日记本数。
  final int addedNotebooks;

  /// 新增与替换的“这天的心情”天数（合并保留本机而跳过的不计）；
  /// [BackupImportMode.replaceAll] 时新增数为换入的全部天数。
  final int addedDayMoods;
  final int replacedDayMoods;

  /// 新增与替换的日记留言条数（合并保留本机而跳过的不计）；
  /// [BackupImportMode.replaceAll] 时新增数为换入的全部留言数。
  final int addedComments;
  final int replacedComments;

  bool get touchedAnniversaries =>
      addedAnniversaries + replacedAnniversaries + skippedAnniversaries > 0;
}
