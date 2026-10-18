import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../database/audio_embed_codec.dart';
import '../database/file_embed_codec.dart';
import 'diary_audio_storage_service.dart';
import 'diary_media_storage_service.dart';

enum JournalMediaKind { image, video, audio, attachment }

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
  final Map<String, String> _staged = <String, String>{};
  int _sequence = 0;
  int missingCount = 0;

  /// 暂存 [sourcePath] 指向的文件并返回嵌入数据；文件缺失时返回 null。
  ///
  /// [kind] 为空时按扩展名（无扩展名时按文件头）判断类型。
  Map<String, Object?>? embedFile(
    String sourcePath, {
    JournalMediaKind? kind,
    String? name,
    Duration? duration,
  }) {
    final source = File(sourcePath);
    final normalized = p.normalize(source.absolute.path);
    // 解压出的文件暂存时被直接移走，再次引用同一文件只能从缓存取，所以先查
    // 缓存再判断文件是否存在。
    final cached = _staged[normalized];
    if (cached != null) {
      return _embed(
        kind ?? journalMediaKindOf(_extensionOf(cached)),
        cached,
        name: name,
        duration: duration,
      );
    }
    if (!source.existsSync()) {
      missingCount++;
      return null;
    }
    final extension = _extensionOf(normalized) ?? _sniffExtension(source);
    final resolvedKind = kind ?? journalMediaKindOf(extension);
    final staged = _staged[normalized] = _stage(
      source,
      resolvedKind,
      _fileName(name ?? p.basename(normalized), extension),
    );
    return _embed(resolvedKind, staged, name: name, duration: duration);
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
    final extension =
        _extensionOf(name) ?? _extensionForMime(mime) ?? _sniffBytes(bytes);
    final resolvedKind = kind ?? journalMediaKindOf(extension);
    final target = _target(resolvedKind, _fileName(name, extension));
    target.parent.createSync(recursive: true);
    target.writeAsBytesSync(bytes, flush: true);
    return _embed(resolvedKind, target.path);
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

  static String? _extensionOf(String path) {
    final extension = p.extension(path).toLowerCase();
    if (extension.length < 2 || extension.length > 6) return null;
    return extension.substring(1);
  }

  static String? _sniffExtension(File file) {
    final handle = file.openSync();
    try {
      return _sniffBytes(handle.readSync(16));
    } finally {
      handle.closeSync();
    }
  }

  /// 按文件头识别常见媒体格式，用于没有扩展名的导出文件（如 Daylio 照片）。
  static String? _sniffBytes(List<int> bytes) {
    bool startsWith(List<int> magic, [int offset = 0]) {
      if (bytes.length < offset + magic.length) return false;
      for (var i = 0; i < magic.length; i++) {
        if (bytes[offset + i] != magic[i]) return false;
      }
      return true;
    }

    String ascii(int start, int end) => bytes.length < end
        ? ''
        : String.fromCharCodes(bytes.sublist(start, end));

    if (startsWith(const [0xFF, 0xD8, 0xFF])) return 'jpg';
    if (startsWith(const [0x89, 0x50, 0x4E, 0x47])) return 'png';
    if (ascii(0, 4) == 'GIF8') return 'gif';
    if (ascii(0, 4) == 'RIFF' && ascii(8, 12) == 'WEBP') return 'webp';
    if (ascii(0, 4) == 'RIFF' && ascii(8, 12) == 'WAVE') return 'wav';
    if (ascii(0, 4) == '%PDF') return 'pdf';
    if (ascii(0, 4) == 'OggS') return 'ogg';
    // 手机录音常见的 AMR（窄带 `#!AMR\n`、宽带 `#!AMR-WB\n`）。
    if (ascii(0, 5) == '#!AMR') return 'amr';
    if (ascii(0, 3) == 'ID3' ||
        (bytes.length > 1 && bytes[0] == 0xFF && bytes[1] & 0xE0 == 0xE0)) {
      return 'mp3';
    }
    if (ascii(4, 8) == 'ftyp') {
      final brand = ascii(8, 12);
      if (const {
        'heic',
        'heix',
        'hevc',
        'heim',
        'heis',
        'mif1',
        'msf1',
      }.contains(brand)) {
        return 'heic';
      }
      if (brand == 'M4A ') return 'm4a';
      if (brand == 'qt  ') return 'mov';
      return 'mp4';
    }
    return null;
  }
}

/// 常见媒体 MIME 对应的扩展名；未知或不是媒体时返回 null。
String? _extensionForMime(String? mime) {
  final type = mime?.split(';').first.trim().toLowerCase() ?? '';
  return switch (type) {
    'image/jpeg' || 'image/jpg' => 'jpg',
    'image/png' => 'png',
    'image/gif' => 'gif',
    'image/webp' => 'webp',
    'image/heic' || 'image/heif' => 'heic',
    'video/mp4' => 'mp4',
    'video/quicktime' => 'mov',
    'video/3gpp' => '3gp',
    'video/webm' => 'webm',
    'audio/mp4' ||
    'audio/m4a' ||
    'audio/x-m4a' ||
    'audio/aac' ||
    'audio/3gpp' => 'm4a',
    'audio/mpeg' || 'audio/mp3' => 'mp3',
    'audio/amr' || 'audio/amr-wb' => 'amr',
    'audio/wav' || 'audio/x-wav' || 'audio/wave' => 'wav',
    'audio/ogg' => 'ogg',
    'audio/opus' => 'opus',
    'audio/flac' => 'flac',
    'application/pdf' => 'pdf',
    _ => null,
  };
}

/// 按扩展名（不含点，小写）判断媒体类型，未知扩展名按附件处理。
JournalMediaKind journalMediaKindOf(String? extension) {
  return switch (extension) {
    'jpg' ||
    'jpeg' ||
    'png' ||
    'gif' ||
    'webp' ||
    'heic' ||
    'heif' ||
    'bmp' => JournalMediaKind.image,
    'mp4' ||
    'm4v' ||
    'mov' ||
    '3gp' ||
    'webm' ||
    'mkv' ||
    'avi' => JournalMediaKind.video,
    'm4a' ||
    'aac' ||
    'mp3' ||
    'wav' ||
    'ogg' ||
    'oga' ||
    'opus' ||
    'flac' ||
    'amr' ||
    'caf' => JournalMediaKind.audio,
    _ => JournalMediaKind.attachment,
  };
}
