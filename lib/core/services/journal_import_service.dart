import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import 'backup_archive_io.dart';
import 'backup_import_models.dart';
import 'backup_merge.dart';
import 'backup_payload.dart';
import 'data_archive_service.dart';
import 'journal_import_apple_journal.dart';
import 'journal_import_cloud.dart';
import 'journal_import_day_one.dart';
import 'journal_import_daylio.dart';
import 'journal_import_diaro.dart';
import 'journal_import_diarium.dart';
import 'journal_import_evernote.dart';
import 'journal_import_google_keep.dart';
import 'journal_import_joplin.dart';
import 'journal_import_journey.dart';
import 'journal_import_markdown_files.dart';
import 'journal_import_media.dart';
import 'journal_import_memos.dart';
import 'journal_import_models.dart';
import 'journal_import_notebooks.dart';
import 'journal_import_payload.dart';
import 'journal_import_support.dart';
import 'settings_service.dart';
import 'app_data_directory.dart';

/// 导入其他日记应用的导出或云端笔记：解析 → 预检 → 按所选方式合并。
///
/// 流程与备份导入一致，分两步，任何一步取消都不写入本机数据：
/// 1. [prepare]：在应用文档目录下建立隔离暂存区，解压所选文件（是 ZIP
///    时），在后台 isolate 中按来源解析，把媒体放进暂存区，生成与备份相同
///    的载荷，并只读统计与本机重复的篇数，得到 [JournalImportSession.preview]；
///    [prepareCloud] 改为从云端读取笔记、下载附件，其余相同；
/// 2. [JournalImportSession.apply]：在备份服务的串行队列中经 BackupMerge
///    合并导入（事务写表、媒体搬进新批次目录、失败整体回滚）。
///
/// 来源里的日记本 / 文件夹按 `folderMode` 落成日记本（默认）、标签或两者，
/// 见 [buildJournalImportPayload]。
///
/// 暂存区与文档目录同一文件系统，媒体搬运只需 rename。会话结束（导入完成
/// 或取消）必须调用 [JournalImportSession.dispose] 删除暂存区；进程意外退出
/// 留下的暂存区在下一次 [prepare] 时清理。
class JournalImportService {
  const JournalImportService._();

  static const String _stagingPrefix = '.journal_import_';

  /// 尚未结束的会话的暂存区，清理遗留目录时跳过。
  static final Set<String> _liveStaging = <String>{};

  static Future<JournalImportSession> prepare({
    required AppDatabase database,
    required JournalImportSource source,
    required String filePath,
    List<String> moodOptions = SettingsService.defaultMoodOptions,
    List<int> tagColors = const <int>[],
    JournalImportFolderMode folderMode = JournalImportFolderMode.notebooks,
  }) async {
    if (!await File(filePath).exists()) {
      throw FileSystemException('导入文件不存在', filePath);
    }
    return _prepare(
      database: database,
      source: source,
      moodOptions: moodOptions,
      tagColors: tagColors,
      folderMode: folderMode,
      parse: (staging) async {
        String? extracted;
        if (await _isZip(filePath)) {
          final directory = Directory(p.join(staging.path, 'source'));
          await BackupArchiveIO.extract(
            filePath,
            directory,
            keepModifiedTimes: true,
          );
          extracted = directory.path;
        }
        return _parseInBackground(
          source,
          JournalImportInput(filePath: filePath, extractedPath: extracted),
          staging.path,
        );
      },
    );
  }

  /// 从手机厂商或 WPS 云端读取笔记（[provider] 已带登录状态并通过核验），
  /// 附件下载进暂存区，之后与文件导入相同：只读预检，经会话合并写入。
  static Future<JournalImportSession> prepareCloud({
    required AppDatabase database,
    required JournalImportSource source,
    required CloudNoteProvider provider,
    CloudProgress? onProgress,
    List<String> moodOptions = SettingsService.defaultMoodOptions,
    List<int> tagColors = const <int>[],
    JournalImportFolderMode folderMode = JournalImportFolderMode.notebooks,
  }) {
    return _prepare(
      database: database,
      source: source,
      moodOptions: moodOptions,
      tagColors: tagColors,
      folderMode: folderMode,
      parse: (staging) => fetchCloudJournal(
        provider,
        JournalMediaStager(staging.path),
        onProgress: onProgress,
      ),
    );
  }

  /// 建立暂存区 → [parse] 得到条目与暂存媒体 → 生成载荷并只读预检。任何
  /// 一步失败都删除暂存区并原样抛出。
  static Future<JournalImportSession> _prepare({
    required AppDatabase database,
    required JournalImportSource source,
    required List<String> moodOptions,
    required List<int> tagColors,
    required JournalImportFolderMode folderMode,
    required Future<JournalImportParseResult> Function(Directory staging) parse,
  }) async {
    // 创建目录和登记存活状态属于同一个临界区。并发准备时，不能让另一
    // 会话在 createTemp 完成、_liveStaging 登记前把新目录误当作遗留目录删掉。
    final (documents, staging) = await DataArchiveService.runSerialized(
      () async {
        final documents = await appDataRootDirectory();
        await documents.create(recursive: true);
        await _removeStaleStaging(documents);
        final staging = await documents.createTemp(_stagingPrefix);
        _liveStaging.add(staging.path);
        return (documents, staging);
      },
    );
    try {
      final parsed = await parse(staging);
      if (parsed.entries.isEmpty) {
        throw JournalImportFormatException(
          source,
          noEntries: true,
          skippedNotes: parsed.skippedNotes,
        );
      }
      // 本机日记本只在这里读一次：载荷生成保持纯函数，复用本机同名 / 上次
      // 导入建的日记本所需的信息由此传入。预检到确认之间用户若又改了日记本，
      // 合并按 notebookId 处理，最坏只是多建一本或沿用旧定义，不会写坏数据。
      final existingNotebooks = await database.getNotebooks();
      // 三种落地方式共用同一个时间，切换方式后重建的载荷除差异部分外完全相同。
      final now = DateTime.now();
      final folderCount = journalImportFolderCount(parsed.entries);
      final session = JournalImportSession._(
        documents,
        staging,
        (mode) => buildJournalImportPayload(
          source,
          parsed.entries,
          moodOptions: moodOptions,
          tagColors: tagColors,
          folderMode: mode,
          existingNotebooks: existingNotebooks,
          now: now,
        ),
        folderMode: folderMode,
        sourceFolderCount: folderCount,
      );
      // 预检统计（标签数、已存在的日记本数）随落地方式变化，且要读库，在这里
      // 一次算好：导入方式面板切换时同步取用，不再等待也不重新解析。没有来源
      // 文件夹时三种方式的载荷相同，只算一份。跳过 / 只有摘要 / 部分内容的
      // 篇数来自解析，与落地方式无关，每种方式的预检都带上。
      for (final mode
          in folderCount > 0
              ? JournalImportFolderMode.values
              : <JournalImportFolderMode>[folderMode]) {
        session._previews[mode] = await DataArchiveService.previewPayload(
          database: database,
          kind: BackupArchiveKind.journalExport,
          payload: session.payloadFor(mode),
          journalSource: source,
          missingMediaCount: parsed.missingMediaCount,
          skippedNotes: parsed.skippedNotes,
          summaryOnlyCount: parsed.summaryOnlyCount,
          partialContentCount: parsed.partialContentCount,
        );
      }
      return session;
    } catch (_) {
      await _discard(staging);
      rethrow;
    }
  }

  /// 单独的函数只捕获可发送的参数，避免闭包连带捕获数据库等对象。
  static Future<JournalImportParseResult> _parseInBackground(
    JournalImportSource source,
    JournalImportInput input,
    String stagingPath,
  ) => Isolate.run(() => parseJournalExport(source, input, stagingPath));

  static Future<bool> _isZip(String path) async {
    final handle = await File(path).open();
    try {
      final head = await handle.read(4);
      return head.length == 4 &&
          head[0] == 0x50 &&
          head[1] == 0x4B &&
          ((head[2] == 0x03 && head[3] == 0x04) ||
              (head[2] == 0x05 && head[3] == 0x06));
    } finally {
      await handle.close();
    }
  }

  static Future<void> _removeStaleStaging(Directory documents) async {
    try {
      await for (final entity in documents.list(followLinks: false)) {
        if (entity is Directory &&
            p.basename(entity.path).startsWith(_stagingPrefix) &&
            !_liveStaging.contains(entity.path)) {
          await entity.delete(recursive: true);
        }
      }
    } on FileSystemException {
      // 遗留目录清理失败只多占空间，不能阻断本次导入。
    }
  }

  static Future<void> _discard(Directory staging) async {
    _liveStaging.remove(staging.path);
    try {
      if (await staging.exists()) await staging.delete(recursive: true);
    } on FileSystemException {
      // 见 _removeStaleStaging：下次导入前会再清理。
    }
  }
}

/// 一次已解析、待确认的导入。[apply] 至多调用一次；无论是否导入，结束时
/// 都要调用 [dispose]。
///
/// 会话保留解析出的条目：来源日记本 / 文件夹的落地方式
/// （[JournalImportFolderMode]）可以在确认前改选，[payloadFor] 由条目重建
/// 载荷（纯计算，按方式缓存），不重新解析文件或读取云端。
class JournalImportSession {
  JournalImportSession._(
    this._documents,
    this._staging,
    this._build, {
    required this.folderMode,
    required this.sourceFolderCount,
  });

  final Directory _documents;
  final Directory _staging;
  final BackupPayload Function(JournalImportFolderMode mode) _build;
  final Map<JournalImportFolderMode, BackupPayload> _payloads = {};
  final Map<JournalImportFolderMode, BackupArchivePreview> _previews = {};

  /// 准备时指定的落地方式，[preview] 与不传方式的 [apply] 按它进行。
  final JournalImportFolderMode folderMode;

  /// 条目里出现的来源日记本 / 文件夹个数（按规整后的名称去重）。
  final int sourceFolderCount;
  bool _applied = false;
  bool _disposed = false;
  Future<BackupImportResult>? _application;
  Future<void>? _disposal;

  /// 是否有来源日记本 / 文件夹，没有时三种落地方式没有区别，界面不必询问。
  bool get hasSourceFolders => sourceFolderCount > 0;

  BackupArchivePreview get preview => previewFor(folderMode);

  /// [mode] 下的预检结果；没有来源文件夹时各方式相同。
  BackupArchivePreview previewFor(JournalImportFolderMode mode) =>
      _previews[mode] ?? _previews[folderMode]!;

  /// [mode] 下要写入的载荷。
  BackupPayload payloadFor(JournalImportFolderMode mode) =>
      _payloads[mode] ??= _build(mode);

  /// 按 [mode] 合并导入，来源文件夹按 [folderMode]（缺省为准备时指定的方式）
  /// 落地；其他应用的导出不支持覆盖全部数据。
  Future<BackupImportResult> apply({
    required AppDatabase database,
    required BackupImportMode mode,
    JournalImportFolderMode? folderMode,
  }) {
    if (mode == BackupImportMode.replaceAll) {
      throw ArgumentError.value(mode, 'mode', '其他应用的导出只能合并导入');
    }
    if (_applied) throw StateError('导入会话已执行过');
    if (_disposed) throw StateError('导入会话已释放');
    _applied = true;
    final payload = payloadFor(folderMode ?? this.folderMode);
    return _application = DataArchiveService.runSerialized(
      () => BackupMerge(
        documents: _documents,
        staging: _staging,
      ).apply(database: database, payload: payload, mode: mode),
    );
  }

  Future<void> dispose() {
    _disposed = true;
    return _disposal ??= _dispose();
  }

  Future<void> _dispose() async {
    // 合并可能尚在备份队列中等待，媒体必须留到事务提交或回滚之后。
    // apply 的异常仍交给原调用方，释放只保证暂存区最终被清理。
    try {
      await _application;
    } catch (_) {
      // 原调用方持有同一个 Future，不在资源释放时重复抛出。
    } finally {
      await JournalImportService._discard(_staging);
    }
  }
}

/// 按来源解析导出（在后台 isolate 中执行，使用同步 IO）。
JournalImportParseResult parseJournalExport(
  JournalImportSource source,
  JournalImportInput input,
  String stagingPath,
) {
  final media = JournalMediaStager(stagingPath);
  return switch (source) {
    JournalImportSource.dayOne => parseDayOneExport(input, media),
    JournalImportSource.journey => parseJourneyExport(input, media),
    JournalImportSource.diarium => parseDiariumExport(input, media),
    JournalImportSource.daylio => parseDaylioExport(input, media),
    JournalImportSource.appleJournal => parseAppleJournalExport(input, media),
    JournalImportSource.diaro => parseDiaroExport(input, media),
    JournalImportSource.evernote => parseEvernoteExport(input, media),
    JournalImportSource.googleKeep => parseGoogleKeepExport(input, media),
    JournalImportSource.joplin => parseJoplinExport(input, media),
    JournalImportSource.memos => parseMemosExport(input, media),
    JournalImportSource.markdown => parseMarkdownFilesExport(input, media),
    JournalImportSource.xiaomiNotes ||
    JournalImportSource.huaweiNotepad ||
    JournalImportSource.oppoNotes ||
    JournalImportSource.vivoNotes ||
    JournalImportSource.honorNotes ||
    JournalImportSource.meizuNotes ||
    JournalImportSource.wpsNotes => throw ArgumentError.value(
      source,
      'source',
      '云端来源经 prepareCloud 读取，没有导出文件',
    ),
  };
}
