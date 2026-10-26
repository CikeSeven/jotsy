import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show TextDirection;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/backup_file_save_service.dart';
import '../../../core/services/data_archive_service.dart';
import '../../../core/services/diary_typography.dart';
import '../export/diary_export_book.dart';
import '../export/diary_export_code.dart';
import '../export/diary_export_docx.dart';
import '../export/diary_export_entry.dart';
import '../export/diary_export_font.dart';
import '../export/diary_export_format.dart';
import '../export/diary_export_html.dart';
import '../export/diary_export_markdown.dart';
import '../export/diary_export_media.dart';
import '../export/diary_export_naming.dart';
import '../export/diary_export_pdf.dart';
import '../export/diary_export_text.dart';

typedef DiaryExportFileSaver =
    Future<String?> Function({
      required File file,
      required String fileName,
      required String dialogTitle,
      required String mimeType,
      required String extension,
    });

typedef DiaryExportFileSharer =
    Future<void> Function(File file, {required String mimeType});

/// 生成好、等待保存或分享的导出文件。
@immutable
class DiaryExportArtifact {
  const DiaryExportArtifact({
    required this.file,
    required this.mimeType,
    required this.exportedCount,
    required this.skippedCapsules,
  });

  /// 暂存目录里已按最终文件名命名的文件。
  final File file;
  final String mimeType;
  final int exportedCount;

  /// 因尚未解封而没有导出的时间胶囊篇数。
  final int skippedCapsules;

  String get fileName => p.basename(file.path);
  String get extension => p.extension(file.path).replaceFirst('.', '');
}

/// 选中的日记全是未解封的时间胶囊（或本来就没有日记）时抛出。
class DiaryExportEmptyException implements Exception {
  const DiaryExportEmptyException(this.skippedCapsules);

  final int skippedCapsules;
}

/// 日记导出的执行链路：筛选 → 排序 → 按格式写出 → 落盘 → 保存或分享。
///
/// - 未解封的时间胶囊一律不导出（连同 Jotsy 日记文件）：导出文件会离开
///   应用、在别处被打开，胶囊内容不能借此提前看到；完整备份不受影响。
/// - 导出成书（给了 [DiaryExportBook]）时顺序以书为准，不按日期重排、不看
///   导出选项里的先后；文件名与文档标题用书名。[build] 的 `bookStructure`
///   为 true 且格式支持时再解析成书版式（扉页、目录与章节标题），整章都是
///   胶囊时连同章节标题一起去掉；关掉时与普通的多篇导出相同，只是仍按书序。
/// - 产物写在缓存 `diary_export/<时间戳>/` 下，以最终文件名命名，保存
///   对话框与分享面板都直接显示这个名字。每次生成前清空上一次的暂存：
///   分享出去的文件由目标应用在被拉起时读取，那时上一次早已结束；保存
///   完成（含取消、失败）后立即删除本次暂存。
/// - 多文件的产物（带媒体的 Markdown、多篇带图的网页、Word 文档本身）
///   打包成 zip 容器，媒体经 [ZipFileEncoder] 流式写入，照片与视频不整段
///   读进内存。
/// - 正文字体跟随正文排版：[loadBodyFont] 给出用户选的导入字体（见
///   [DiaryExportFont]），PDF 嵌入它，Word 与网页按字族名引用；只在这三种
///   格式下读取。没给或读不到时各格式保持原有字体。
/// - Word 正文数值由 [build] 的 `typography` 快照给出，写出器只换算单位，
///   不自行读取设置，避免生成途中混入另一份排版参数。
/// - 代码高亮跟随代码块样式：[build] 的 `code` 交给 PDF、Word 与网页写出器；
///   没给时代码块只是等宽文字。
class DiaryExportController {
  DiaryExportController({
    required this._database,
    DiaryExportMediaLibrary Function()? createMediaLibrary,
    Future<DiaryExportFont?> Function()? loadBodyFont,
    this._loadFonts = DiaryPdfFonts.load,
    this._cacheDirectory = getTemporaryDirectory,
    this._now = DateTime.now,
    this._saveFile = BackupFileSaveService.saveFile,
    DiaryExportFileSharer? shareFile,
  }) : _createMediaLibrary = createMediaLibrary ?? DiaryExportMediaLibrary.new,
       _loadBodyFont = loadBodyFont ?? _noBodyFont,
       _shareFile = shareFile ?? _shareWithSystemSheet;

  static const String stagingDirectoryName = 'diary_export';

  final AppDatabase _database;
  final DiaryExportMediaLibrary Function() _createMediaLibrary;
  final Future<DiaryExportFont?> Function() _loadBodyFont;
  final Future<DiaryPdfFonts> Function(DiaryExportFont? bodyFont) _loadFonts;
  final Future<Directory> Function() _cacheDirectory;
  final DateTime Function() _now;
  final DiaryExportFileSaver _saveFile;
  final DiaryExportFileSharer _shareFile;

  /// 导入字体文件可达十几 MB，同一个控制器内只读一次。
  Future<DiaryExportFont?>? _bodyFont;

  /// PDF 字体（内置字体约 16MB），同一个控制器内只解析一次。
  Future<DiaryPdfFonts>? _fonts;

  Future<DiaryExportFont?> _resolveBodyFont() => _bodyFont ??= _loadBodyFont();

  /// Word 与网页引用的字族名；没有导入字体时为空。
  Future<List<String>> _bodyFontFamilies() async =>
      (await _resolveBodyFont())?.families ?? const <String>[];

  Future<DiaryExportArtifact> build(
    List<DiaryWithTags> diaries, {
    required DiaryExportOptions options,
    required DiaryExportLabels labels,
    required String languageTag,
    TextDirection textDirection = TextDirection.ltr,
    String? password,
    DiaryExportBook? book,
    bool bookStructure = true,
    DiaryExportCodeTheme? code,
    DiaryTypography typography = const DiaryTypography(),
  }) async {
    final now = _now();
    var exportable = diaries.where((DiaryWithTags detail) {
      final unlockAt = detail.diary.capsuleUnlockAt;
      return unlockAt == null || !now.isBefore(unlockAt);
    }).toList();
    final skipped = diaries.length - exportable.length;
    if (exportable.isEmpty) {
      throw DiaryExportEmptyException(skipped);
    }
    if (book != null) {
      exportable = book.arrange(
        exportable,
        (DiaryWithTags detail) => detail.diary.diaryId,
      );
    } else {
      exportable.sort((DiaryWithTags a, DiaryWithTags b) {
        final order = a.diary.createdAt.compareTo(b.diary.createdAt);
        return options.order == DiaryExportOrder.oldestFirst ? order : -order;
      });
    }
    var entries = exportable.map(DiaryExportEntry.fromDetail).toList();
    DiaryExportBookLayout? layout;
    if (book != null && bookStructure && options.format.supportsBookStructure) {
      final bookLabels = labels.book;
      if (bookLabels == null) {
        throw ArgumentError.value(labels, 'labels', '导出成书需要成书文案');
      }
      layout = DiaryExportBookLayout.resolve(
        book,
        entries,
        labels: bookLabels,
        exportedAt: now,
      );
      // 与书序相同；以版式为准，写出器的篇目与目录不会错位。
      entries = layout.entries;
    }
    final bookStem = book == null ? '' : DiaryExportNaming.sanitize(book.title);
    final stem = bookStem.isNotEmpty
        ? bookStem
        : DiaryExportNaming.exportStem(entries);
    final documentTitle = book != null && book.title.trim().isNotEmpty
        ? book.title.trim()
        : entries.length == 1
        ? labels.titleOf(entries.single)
        : stem;

    final directory = await _prepareStaging();
    final format = options.format;
    File file;
    var mimeType = format.mimeType;
    if (format == DiaryExportFormat.diaryFile) {
      final zip = await DataArchiveService.exportDiariesToZip(
        database: _database,
        diaryIds: exportable.map((DiaryWithTags d) => d.diary.diaryId),
        zipPassword: password,
      );
      file = await _move(zip, p.join(directory.path, '$stem.zip'));
    } else {
      final media = _createMediaLibrary();
      final output = switch (format) {
        DiaryExportFormat.pdf => await DiaryPdfWriter.write(
          entries,
          options: options,
          labels: labels,
          media: media,
          fonts: await (_fonts ??= _resolveBodyFont().then(_loadFonts)),
          documentTitle: documentTitle,
          textDirection: textDirection,
          book: layout,
          code: code,
        ),
        DiaryExportFormat.word => await DiaryDocxWriter.write(
          entries,
          options: options,
          labels: labels,
          media: media,
          documentTitle: documentTitle,
          languageTag: languageTag,
          fontFamilies: await _bodyFontFamilies(),
          typography: typography,
          now: now,
          book: layout,
          code: code,
        ),
        DiaryExportFormat.markdown => await DiaryMarkdownWriter.write(
          entries,
          options: options,
          labels: labels,
          media: media,
          book: layout,
          documentStem: stem,
        ),
        DiaryExportFormat.html => await DiaryHtmlWriter.write(
          entries,
          options: options,
          labels: labels,
          media: media,
          documentTitle: documentTitle,
          languageTag: languageTag,
          fontFamilies: await _bodyFontFamilies(),
          book: layout,
          code: code,
        ),
        DiaryExportFormat.text => DiaryTextWriter.write(
          entries,
          options: options,
          labels: labels,
          book: layout,
        ),
        DiaryExportFormat.csv => DiaryCsvWriter.write(entries, labels: labels),
        DiaryExportFormat.diaryFile => throw StateError('handled above'),
      };
      if (output.isBundle) {
        mimeType = output.containerMimeType!;
        file = await _zip(
          output.files!,
          p.join(directory.path, '$stem.${output.containerExtension}'),
        );
      } else {
        file = File(p.join(directory.path, '$stem.${format.extension}'));
        await file.writeAsBytes(output.bytes!, flush: true);
      }
    }
    return DiaryExportArtifact(
      file: file,
      mimeType: mimeType,
      exportedCount: entries.length,
      skippedCapsules: skipped,
    );
  }

  /// 交给系统保存；返回是否已保存（取消为 false）。暂存无论结果都删除。
  Future<bool> save(
    DiaryExportArtifact artifact, {
    required String dialogTitle,
  }) async {
    try {
      final savePath = await _saveFile(
        file: artifact.file,
        fileName: artifact.fileName,
        dialogTitle: dialogTitle,
        mimeType: artifact.mimeType,
        extension: artifact.extension,
      );
      return savePath != null && savePath.trim().isNotEmpty;
    } finally {
      await _deleteQuietly(artifact.file.parent);
    }
  }

  /// 交给系统分享面板；暂存留到下次导出时清理（见类注释）。
  Future<void> share(DiaryExportArtifact artifact) =>
      _shareFile(artifact.file, mimeType: artifact.mimeType);

  Future<Directory> _prepareStaging() async {
    final root = Directory(
      p.join((await _cacheDirectory()).path, stagingDirectoryName),
    );
    await _deleteQuietly(root);
    final directory = Directory(
      p.join(root.path, '${_now().microsecondsSinceEpoch}'),
    );
    await directory.create(recursive: true);
    return directory;
  }

  static Future<File> _move(File source, String target) async {
    try {
      return await source.rename(target);
    } on FileSystemException {
      // 跨文件系统时 rename 失败，退回复制后删除。
      final copy = await source.copy(target);
      await _deleteQuietly(source);
      return copy;
    }
  }

  static Future<File> _zip(
    List<DiaryExportBundleFile> files,
    String target,
  ) async {
    final encoder = ZipFileEncoder()..create(target);
    try {
      for (final entry in files) {
        if (entry.file != null) {
          await encoder.addFile(entry.file!, entry.path);
        } else {
          encoder.addArchiveFile(
            ArchiveFile(entry.path, entry.bytes!.length, entry.bytes!),
          );
        }
      }
    } finally {
      await encoder.close();
    }
    return File(target);
  }

  static Future<DiaryExportFont?> _noBodyFont() async => null;

  static Future<void> _deleteQuietly(FileSystemEntity entity) async {
    try {
      if (await entity.exists()) {
        await entity.delete(recursive: true);
      }
    } on FileSystemException {
      // 系统会回收缓存目录；清理失败不应把已完成的导出报告为失败。
    }
  }

  static Future<void> _shareWithSystemSheet(
    File file, {
    required String mimeType,
  }) async {
    // Linux 的 share_plus 没有实现文件分享：导出面板不提供“分享”，这里兜底。
    if (!AppPlatform.supportsSystemFileShare) {
      throw UnsupportedError('System share is unavailable on this platform');
    }
    await Share.shareXFiles(<XFile>[XFile(file.path, mimeType: mimeType)]);
  }
}
