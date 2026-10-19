import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../database/audio_embed_codec.dart';
import '../database/file_embed_codec.dart';
import 'diary_audio_storage_service.dart';
import 'diary_media_storage_service.dart';
import 'journal_import_media_format.dart';

export 'journal_import_media_format.dart'
    show JournalMediaKind, journalMediaKindOf;

/// 把第三方导出里的媒体放进导入暂存区，并生成本应用的正文嵌入数据。
///
/// 暂存布局与托管目录一致：`<暂存区>/<托管目录>/<序号>/<文件名>`。正文先
/// 引用暂存路径，合并导入时由 BackupMediaPaths 识别托管目录名，把实际写入
/// 的日记用到的文件搬进本机的批次目录；没写入的留在暂存区随之删除。
///
/// - 解压出的文件与暂存区在同一目录树下，直接 rename；其他位置的文件复制；
/// - 同一源文件被多篇日记引用时只暂存一次，各处共用同一路径；
/// - 引用的文件不存在时计入 [missingCount]，该引用被丢弃。
///
/// 使用同步 IO：解析在后台 isolate 中整体执行，不阻塞界面。
class JournalMediaStager {
  JournalMediaStager(this.stagingPath);

  final String stagingPath;
  final Map<String, ({String path, JournalMediaKind kind})> _staged = {};
  int _sequence = 0;
  int missingCount = 0;

  /// 暂存 [sourcePath] 指向的文件并返回嵌入数据；文件缺失时返回 null。
  ///
  /// [kind] 为空时按扩展名（无扩展名时按文件头）判断类型。
  Map<String, Object?>? embedFile(
    String sourcePath, {
    JournalMediaKind? kind,
    String? name,
    String? mime,
    Duration? duration,
  }) {
    final source = File(sourcePath);
    final normalized = p.normalize(source.absolute.path);
    // 解压出的文件暂存时被直接移走，再次引用同一文件只能从缓存取，所以先查
    // 缓存再判断文件是否存在。
    final cached = _staged[normalized];
    if (cached != null) {
      return _embed(cached.kind, cached.path, name: name, duration: duration);
    }
    if (!source.existsSync()) {
      missingCount++;
      return null;
    }
    final format = _format(
      extension: _extensionOf(normalized) ?? _extensionOf(name ?? ''),
      mime: mime,
      sniff: () => _sniffExtension(source),
      kind: kind,
    );
    final staged = _stage(
      source,
      format.kind,
      _fileName(name ?? p.basename(normalized), format.extension),
    );
    _staged[normalized] = (path: staged, kind: format.kind);
    return _embed(format.kind, staged, name: name, duration: duration);
  }

  /// 把内存中的媒体（如 Diarium 备份里的 BLOB）写进暂存区并返回嵌入数据。
  ///
  /// 类型依次按 [kind]、文件名扩展名、来源给出的 [mime]、文件头判断。云端
  /// 笔记的附件常以无扩展名的文件 ID 命名，MIME 比文件头可靠（手机录音的
  /// 3GP 容器按文件头会被认成视频），据此补上扩展名，免得录音、视频被当作
  /// 普通附件。
  Map<String, Object?> embedBytes(
    List<int> bytes, {
    required String name,
    JournalMediaKind? kind,
    String? mime,
  }) {
    final format = _format(
      extension: _extensionOf(name),
      mime: mime,
      sniff: () => sniffJournalMediaBytes(bytes),
      kind: kind,
    );
    final target = _target(format.kind, _fileName(name, format.extension));
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(bytes, flush: true);
    return _embed(format.kind, target.path, name: name);
  }

  /// 网页剪藏与 Markdown 中的内嵌媒体必须落到托管目录，避免 data URI 在
  /// 后续备份或正文渲染中丢失。损坏的内嵌内容同样进入缺失统计。
  Map<String, Object?>? embedDataUri(String source) {
    if (!source.toLowerCase().startsWith('data:')) return null;
    final comma = source.indexOf(',');
    if (comma < 0) {
      missingCount++;
      return null;
    }
    final header = source.substring(5, comma).split(';');
    try {
      final body = source.substring(comma + 1);
      final bytes = header.any((part) => part.toLowerCase() == 'base64')
          ? base64.decode(body.replaceAll(RegExp(r'\s+'), ''))
          : utf8.encode(Uri.decodeComponent(body));
      if (bytes.isEmpty) {
        missingCount++;
        return null;
      }
      return embedBytes(bytes, name: 'media', mime: header.first);
    } on FormatException {
      missingCount++;
      return null;
    } on ArgumentError {
      missingCount++;
      return null;
    }
  }

  String _stage(File source, JournalMediaKind kind, String fileName) {
    final target = _target(kind, fileName);
    target.parent.createSync(recursive: true);
    if (p.isWithin(stagingPath, source.path)) {
      source.renameSync(target.path);
    } else {
      source.copySync(target.path);
    }
    return target.path;
  }

  File _target(JournalMediaKind kind, String fileName) => File(
    p.join(stagingPath, _directoryName(kind), '${_sequence++}', fileName),
  );

  Map<String, Object?> _embed(
    JournalMediaKind kind,
    String path, {
    String? name,
    Duration? duration,
  }) {
    return switch (kind) {
      JournalMediaKind.image => {'image': path},
      JournalMediaKind.video => {'video': path},
      JournalMediaKind.audio => {
        diaryAudioEmbedType: DiaryAudioAttachment(
          path: path,
          duration: duration ?? Duration.zero,
        ).encode(),
      },
      JournalMediaKind.attachment => {
        diaryAttachmentEmbedType: DiaryFileAttachment(
          path: path,
          name: name ?? p.basename(path),
          sizeBytes: File(path).lengthSync(),
        ).encode(),
      },
    };
  }

  static String _directoryName(JournalMediaKind kind) => switch (kind) {
    JournalMediaKind.image => DiaryMediaStorageService.imagesDirectoryName,
    JournalMediaKind.video => DiaryMediaStorageService.videosDirectoryName,
    JournalMediaKind.audio => DiaryAudioStorageService.directoryName,
    JournalMediaKind.attachment =>
      DiaryMediaStorageService.attachmentsDirectoryName,
  };

  /// 去掉路径与文件系统不接受的字符，缺扩展名时补上识别出的扩展名。
  static String _fileName(String raw, String? extension) {
    var name = p.posix
        .basename(raw.replaceAll('\\', '/'))
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .trim();
    if (name.isEmpty || name == '.' || name == '..') name = 'media';
    if (extension != null && _extensionOf(name) == null) {
      name = '$name.$extension';
    }
    // 文件名按字节受限，过长时截断主名并保留扩展名。
    final ext = p.extension(name);
    var stem = p.basenameWithoutExtension(name);
    while (utf8.encode('$stem$ext').length > 200 && stem.isNotEmpty) {
      stem = String.fromCharCodes(stem.runes.toList()..removeLast());
    }
    return stem.isEmpty ? 'media$ext' : '$stem$ext';
  }

  static ({String? extension, JournalMediaKind kind}) _format({
    required String? extension,
    required String? mime,
    required String? Function() sniff,
    JournalMediaKind? kind,
  }) {
    final mimeExtension = journalMediaExtensionForMime(mime);
    final generic =
        extension == null ||
        const {'bin', 'dat', 'tmp', 'blob'}.contains(extension);
    final resolvedExtension = generic
        ? mimeExtension ?? sniff() ?? extension
        : extension;
    return (
      extension: resolvedExtension,
      kind:
          kind ??
          (mime?.toLowerCase().startsWith('audio/') == true
              ? JournalMediaKind.audio
              : journalMediaKindOf(mimeExtension ?? resolvedExtension)),
    );
  }

  static String? _extensionOf(String path) {
    final extension = p.extension(path).toLowerCase();
    if (extension.length < 2 || extension.length > 6) return null;
    return extension.substring(1);
  }

  static String? _sniffExtension(File file) {
    final handle = file.openSync();
    try {
      return sniffJournalMediaBytes(handle.readSync(16));
    } finally {
      handle.closeSync();
    }
  }
}
