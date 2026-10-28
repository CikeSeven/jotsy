import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 写出器能带上的媒体范围。
enum DiaryExportMediaSupport {
  /// 不带任何媒体（纯文本、表格）。
  none,

  /// 只内嵌图片；录音、视频、附件写成一行名称。
  images,

  /// 图片、录音、视频与附件原文件一起打包。
  all,
}

/// 导出格式。顺序即导出面板中的排列顺序。
enum DiaryExportFormat {
  /// 适合阅读与打印；版式固定，图片内嵌。
  pdf(
    extension: 'pdf',
    mimeType: 'application/pdf',
    media: DiaryExportMediaSupport.images,
  ),

  /// Word 文档，可继续编辑与排版打印。
  word(
    extension: 'docx',
    mimeType:
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    media: DiaryExportMediaSupport.images,
  ),

  /// 每篇一个 `.md`（带 YAML front matter），媒体放在 `media/`；有媒体或
  /// 多篇时打包成 zip。Obsidian 等笔记软件可直接打开，也能导回 Jotsy。
  markdown(
    extension: 'md',
    mimeType: 'text/markdown',
    media: DiaryExportMediaSupport.all,
  ),

  /// 网页：单篇为自包含 HTML（图片以 data URI 内嵌）；多篇带图时打包成
  /// `index.html` + `media/`，避免把全部照片转成 base64 读进内存。
  html(
    extension: 'html',
    mimeType: 'text/html',
    media: DiaryExportMediaSupport.images,
  ),

  /// 纯文本，所有日记写进同一个文件。
  text(
    extension: 'txt',
    mimeType: 'text/plain',
    media: DiaryExportMediaSupport.none,
  ),

  /// 表格：每篇一行，含日期、心情、精力、天气、地点、标签与正文。
  csv(
    extension: 'csv',
    mimeType: 'text/csv',
    media: DiaryExportMediaSupport.none,
  ),

  /// Jotsy 日记文件（含标签与全部媒体的 zip，可设密码），可在任意设备
  /// 导回且不丢信息。
  diaryFile(
    extension: 'zip',
    mimeType: 'application/zip',
    media: DiaryExportMediaSupport.none,
  );

  const DiaryExportFormat({
    required this.extension,
    required this.mimeType,
    required this.media,
  });

  final String extension;
  final String mimeType;
  final DiaryExportMediaSupport media;

  /// 是否提供“包含心情、天气、地点等信息”开关：表格每列本就各占一列，
  /// 日记文件总是完整保留，二者不提供。
  bool get supportsMetaToggle =>
      this != DiaryExportFormat.csv && this != DiaryExportFormat.diaryFile;

  /// 是否提供“包含留言”开关（留言功能开启时才显示）：日记文件经日记包
  /// 导出，本就原样带着留言，不受开关影响。
  bool get supportsCommentsToggle => this != DiaryExportFormat.diaryFile;

  bool get supportsMediaToggle => media != DiaryExportMediaSupport.none;

  /// 导出顺序对日记文件没有意义（导入后按日期排列）。
  bool get supportsOrder => this != DiaryExportFormat.diaryFile;

  /// 导出成书时能否写出书籍结构（扉页、目录与章节标题）：表格每篇一行，
  /// 日记文件本身已带日记本归属，二者照常导出。
  bool get supportsBookStructure =>
      this != DiaryExportFormat.csv && this != DiaryExportFormat.diaryFile;
}

enum DiaryExportOrder { oldestFirst, newestFirst }

/// 导出面板上次的选择（单个 JSON 设置键 `app.settings.diary_export_options`，
/// 随备份导出）；逐字段容错，未知格式名回落 PDF。
@immutable
class DiaryExportOptions {
  const DiaryExportOptions({
    this.format = DiaryExportFormat.pdf,
    this.includeMedia = true,
    this.includeMeta = true,
    this.includeComments = true,
    this.order = DiaryExportOrder.oldestFirst,
  });

  static const DiaryExportOptions defaults = DiaryExportOptions();

  final DiaryExportFormat format;

  /// 是否带上图片（Markdown 还包括录音、视频与附件）。
  final bool includeMedia;

  /// 是否写出心情、天气、地点、精力与标签。
  final bool includeMeta;

  /// 是否在每篇正文后写出它的留言。只在留言功能开启、格式支持
  /// （[DiaryExportFormat.supportsCommentsToggle]）时生效；功能关闭时保留
  /// 这一选择，重新开启后沿用。
  final bool includeComments;

  /// 多篇导出时的排列顺序；默认从旧到新，读起来像一本日记。
  final DiaryExportOrder order;

  factory DiaryExportOptions.fromRaw(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return defaults;
    }
    Object? decoded;
    try {
      decoded = jsonDecode(normalized);
    } on FormatException {
      return defaults;
    }
    if (decoded is! Map) {
      return defaults;
    }
    T byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((T value) => value.name == name).firstOrNull ?? fallback;
    bool flag(String key, bool fallback) {
      final value = decoded is Map ? decoded[key] : null;
      return value is bool ? value : fallback;
    }

    return DiaryExportOptions(
      format: byName(
        DiaryExportFormat.values,
        decoded['format'],
        defaults.format,
      ),
      includeMedia: flag('media', defaults.includeMedia),
      includeMeta: flag('meta', defaults.includeMeta),
      includeComments: flag('comments', defaults.includeComments),
      order: byName(DiaryExportOrder.values, decoded['order'], defaults.order),
    );
  }

  String toRaw() => jsonEncode(<String, Object>{
    'format': format.name,
    'media': includeMedia,
    'meta': includeMeta,
    'comments': includeComments,
    'order': order.name,
  });

  DiaryExportOptions copyWith({
    DiaryExportFormat? format,
    bool? includeMedia,
    bool? includeMeta,
    bool? includeComments,
    DiaryExportOrder? order,
  }) {
    return DiaryExportOptions(
      format: format ?? this.format,
      includeMedia: includeMedia ?? this.includeMedia,
      includeMeta: includeMeta ?? this.includeMeta,
      includeComments: includeComments ?? this.includeComments,
      order: order ?? this.order,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DiaryExportOptions &&
      other.format == format &&
      other.includeMedia == includeMedia &&
      other.includeMeta == includeMeta &&
      other.includeComments == includeComments &&
      other.order == order;

  @override
  int get hashCode =>
      Object.hash(format, includeMedia, includeMeta, includeComments, order);
}

/// 打包进 zip 的一个文件：文本类内容给 [bytes]，大文件（视频等）给
/// [file] 以便流式写入，不整段读进内存。
@immutable
class DiaryExportBundleFile {
  const DiaryExportBundleFile.bytes(this.path, List<int> this.bytes)
    : file = null;

  const DiaryExportBundleFile.file(this.path, File this.file) : bytes = null;

  /// zip 内的相对路径（`/` 分隔）。
  final String path;
  final List<int>? bytes;
  final File? file;
}

/// 写出器产物：单个文件内容，或需要打包的多个文件。
///
/// 打包产物默认是 zip；Word 文档本身就是 zip 容器，经 [containerExtension]
/// 与 [containerMimeType] 指定为 `.docx`，由控制器流式写出，图片不整份
/// 读进内存。
@immutable
class DiaryExportOutput {
  const DiaryExportOutput.single(List<int> this.bytes)
    : files = null,
      containerExtension = null,
      containerMimeType = null;

  const DiaryExportOutput.bundle(
    List<DiaryExportBundleFile> this.files, {
    String this.containerExtension = 'zip',
    String this.containerMimeType = 'application/zip',
  }) : bytes = null;

  final List<int>? bytes;
  final List<DiaryExportBundleFile>? files;
  final String? containerExtension;
  final String? containerMimeType;

  bool get isBundle => files != null;
}

/// 图片总量超过写出器能在内存里处理的上限（目前只有 PDF：排版库需要
/// 同时持有全部图片）。与其让应用因内存不足被系统结束，不如提前停下，
/// 请用户缩小范围或关闭图片。
class DiaryExportTooLargeException implements Exception {
  const DiaryExportTooLargeException(this.imageBytes);

  final int imageBytes;
}
