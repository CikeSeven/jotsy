import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import '../database/diary_blocks/diary_blocks_codec.dart';
import '../database/diary_blocks/diary_blocks_media.dart';
import 'app_background_storage_service.dart';
import 'app_data_directory.dart';
import 'diary_media_storage_service.dart';
import 'editing_session_registry.dart';
import 'heif_image_converter.dart';
import 'settings_service.dart';

/// 一轮修复的结果（诊断与测试用）。
class HeifMediaRepairReport {
  const HeifMediaRepairReport({
    required this.convertedFiles,
    required this.updatedRows,
    required this.updatedBackgrounds,
  });

  static const empty = HeifMediaRepairReport(
    convertedFiles: 0,
    updatedRows: 0,
    updatedBackgrounds: false,
  );

  /// 本轮转成 JPEG 的文件数。
  final int convertedFiles;

  /// 改写了引用的日记与日记本行数。
  final int updatedRows;

  /// 背景与材质设置是否改写。
  final bool updatedBackgrounds;
}

/// 把已经存进来的 HEIF 系图片（HEIC / HEIF / AVIF）转成 JPEG 并改写引用。
///
/// 为什么：桌面版解码不了这些格式（见 [HeifImageConverter]）。新图在进库时
/// 就转码，但旧版本插入的、从其他日记应用导入的、或经局域网同步从旧版设备
/// 收到的 HEIC 已经在库里了，只有能解码的一端（Android 9+）能把它们换掉；
/// 改写后的正文与 JPEG 随下一次同步或备份到桌面。
///
/// - 输入：全部日记（含归档、回收站与胶囊）的正文图片与封面、日记本封面、
///   背景与材质设置里的背景图——只认托管目录里的文件，外部路径不碰；
/// - 输出：同目录写出 `<主名>.jpg`（[HeifImageConverter.jpegSiblingPath]），
///   引用经 `applyMediaPathRepairs` 一次事务改写（前置条件不符的行跳过）；
/// - 原 HEIC 不删，只把修改时间刷新为现在：此刻打开着的编辑页、撤销提示
///   可能还握着旧路径，之后写回时文件得还在；没有引用后由媒体回收在宽限期
///   （24 小时）之后删除。下次启动仍被引用的会再转一次（新文件名不覆盖已有
///   的 JPEG）；
/// - 触发：冷启动后延迟一次（[scheduleStartupRepair]），有编辑页开着时等它们
///   关闭再开始，避免整份写回的页面立刻把改写盖掉。请求串行执行，任何一步
///   失败都只记日志，不影响启动。
class HeifMediaRepairService {
  HeifMediaRepairService({
    required this._database,
    required this._settings,
    Future<Directory> Function()? dataRoot,
    EditingSessionRegistry? registry,
    DateTime Function()? clock,
    this.startupDelay = const Duration(seconds: 15),
  }) : _dataRoot = dataRoot ?? appDataRootDirectory,
       _registry = registry ?? EditingSessionRegistry.instance,
       _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final Future<SettingsService> Function() _settings;
  final Future<Directory> Function() _dataRoot;
  final EditingSessionRegistry _registry;
  final DateTime Function() _clock;
  final Duration startupDelay;

  static const List<String> _imageDirectories = [
    DiaryMediaStorageService.imagesDirectoryName,
  ];
  static const List<String> _coverDirectories = [
    'diary_covers',
    DiaryMediaStorageService.imagesDirectoryName,
  ];

  Future<HeifMediaRepairReport?> _tail = Future.value();
  Timer? _startupTimer;
  bool _startupScheduled = false;
  bool _disposed = false;
  Completer<void>? _idle;

  /// 冷启动后只安排一次；不能转码的平台什么都不做。
  void scheduleStartupRepair() {
    if (_startupScheduled || _disposed || !HeifImageConverter.canConvert) {
      return;
    }
    _startupScheduled = true;
    _startupTimer = Timer(startupDelay, () {
      _startupTimer = null;
      unawaited(repair());
    });
  }

  /// 排队执行一轮修复；不能转码或失败时返回 null，不抛出。
  Future<HeifMediaRepairReport?> repair() =>
      _tail = _tail.then((_) => _repairSafely());

  Future<HeifMediaRepairReport?> _repairSafely() async {
    if (_disposed || !HeifImageConverter.canConvert) return null;
    try {
      await _waitUntilNoEditors();
      if (_disposed) return null;
      final report = await _repair();
      if (report.convertedFiles > 0) {
        debugPrint(
          'HEIF repair converted ${report.convertedFiles} images, '
          'updated ${report.updatedRows} rows'
          '${report.updatedBackgrounds ? ' and backgrounds' : ''}.',
        );
      }
      return report;
    } catch (error, stackTrace) {
      debugPrint('HEIF repair skipped: $error\n$stackTrace');
      return null;
    }
  }

  /// 有阻塞者（编辑页、发布页等握着整份内存副本的页面）时等到全部关闭。
  Future<void> _waitUntilNoEditors() async {
    if (!_registry.isEditing) return;
    final idle = _idle = Completer<void>();
    void listener() {
      if (!_registry.isEditing && !idle.isCompleted) idle.complete();
    }

    _registry.activeEditors.addListener(listener);
    try {
      await idle.future;
    } finally {
      _registry.activeEditors.removeListener(listener);
      _idle = null;
    }
  }

  Future<HeifMediaRepairReport> _repair() async {
    final root = p.normalize((await _dataRoot()).path);
    final diaries = await _database.getDiaryMediaSources();
    final notebooks = await _database.getNotebookMediaSources();
    final settings = await _settings();
    final surfaceRaw = settings.appSurfaceRaw;

    // 解析全部正文、读文件头都在后台 isolate：日记与图片多时，上千次 JSON
    // 解码与小读取不占界面线程。只把路径与字符串送过去。
    final scan = await _scanInBackground((
      root: root,
      diaries: [for (final d in diaries) (d.id, d.content, d.cover)],
      notebookPayloads: [for (final n in notebooks) n.payload],
      surfaceRaw: surfaceRaw,
    ));
    if (scan.heif.isEmpty) return HeifMediaRepairReport.empty;

    final converted = <String, String>{};
    for (final source in scan.heif) {
      if (_disposed) break;
      final target = HeifImageConverter.jpegSiblingPath(source);
      if (!await HeifImageConverter.toJpeg(source, target)) continue;
      converted[source] = target;
      try {
        await File(source).setLastModified(_clock());
      } on FileSystemException catch (error) {
        debugPrint('HEIF source touch failed: $error');
      }
    }
    if (converted.isEmpty || _disposed) {
      return HeifMediaRepairReport(
        convertedFiles: converted.length,
        updatedRows: 0,
        updatedBackgrounds: false,
      );
    }

    String? replacement(String? raw, List<String> directories) {
      final path = _managedPath(raw, root, directories);
      return path == null ? null : converted[path];
    }

    final diaryRepairs = <DiaryMediaPathRepair>[];
    for (final diary in diaries) {
      if (!scan.diaryIds.contains(diary.id)) continue;
      var touched = false;
      final document = decodeStoredDiaryBlocks(diary.content);
      await rewriteDiaryBlocksMediaPaths(document, (kind, path) async {
        if (kind != DiaryBlockMediaKind.image) return path;
        final target = replacement(path, _imageDirectories);
        if (target == null) return path;
        touched = true;
        return target;
      });
      final cover = replacement(diary.cover, _coverDirectories);
      if (!touched && cover == null) continue;
      diaryRepairs.add(
        DiaryMediaPathRepair(
          id: diary.id,
          expectedContent: diary.content,
          expectedCover: diary.cover,
          content: touched ? encodeDiaryBlocks(document) : diary.content,
          cover: cover ?? diary.cover,
        ),
      );
    }
    final notebookRepairs = <NotebookMediaPathRepair>[];
    for (final notebook in notebooks) {
      final target = replacement(
        _notebookCover(notebook.payload),
        _coverDirectories,
      );
      if (target == null) continue;
      // 只改 cover 一项、其余键原样保留（含本版本认不出的键）；取景
      // （coverStyle）不重置：转码不改变画面的尺寸与方向。
      final json = jsonDecode(notebook.payload) as Map<String, Object?>;
      json['cover'] = target;
      notebookRepairs.add(
        NotebookMediaPathRepair(
          id: notebook.id,
          expectedPayload: notebook.payload,
          payload: jsonEncode(json),
        ),
      );
    }
    final updatedRows = diaryRepairs.isEmpty && notebookRepairs.isEmpty
        ? 0
        : await _database.applyMediaPathRepairs(
            diaryRepairs: diaryRepairs,
            notebookRepairs: notebookRepairs,
          );

    final updatedBackgrounds = await _repairBackgrounds(
      settings,
      surfaceRaw,
      root,
      converted,
    );
    return HeifMediaRepairReport(
      convertedFiles: converted.length,
      updatedRows: updatedRows,
      updatedBackgrounds: updatedBackgrounds,
    );
  }

  /// 背景设置只存文件名：把转好的名字换进 JSON 里所有 `image` 项。设置在
  /// 读取之后被改过（用户正好在换背景）时放弃，下次启动再处理。
  Future<bool> _repairBackgrounds(
    SettingsService settings,
    String? raw,
    String root,
    Map<String, String> converted,
  ) async {
    if (raw == null) return false;
    final directory = p.join(root, AppBackgroundStorageService.directoryName);
    final names = <String, String>{
      for (final entry in converted.entries)
        if (p.equals(p.dirname(entry.key), directory))
          p.basename(entry.key): p.basename(entry.value),
    };
    if (names.isEmpty) return false;
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return false;
    }
    if (!_replaceImageNames(json, names)) return false;
    if (settings.appSurfaceRaw != raw) return false;
    await settings.setAppSurfaceRaw(jsonEncode(json));
    return true;
  }

  /// 静态方法保证闭包只捕获请求本身，不会把数据库等不可发送的对象带进
  /// isolate。
  static Future<_HeifScanResult> _scanInBackground(_HeifScanRequest request) =>
      Isolate.run(() => _scanHeifReferences(request));

  void dispose() {
    _disposed = true;
    _startupTimer?.cancel();
    _startupTimer = null;
    final idle = _idle;
    if (idle != null && !idle.isCompleted) idle.complete();
  }

  /// [raw]（本地路径或 `file:` 地址）位于托管根目录下 [directories] 之一里时
  /// 返回规整后的绝对路径，否则为 null。
  static String? _managedPath(
    String? raw,
    String root,
    List<String> directories,
  ) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    String path;
    if (value.startsWith('file:')) {
      try {
        path = File.fromUri(Uri.parse(value)).path;
      } catch (_) {
        return null;
      }
    } else {
      path = value;
    }
    if (!p.isAbsolute(path)) return null;
    path = p.normalize(path);
    for (final directory in directories) {
      if (p.isWithin(p.join(root, directory), path)) return path;
    }
    return null;
  }

  static String? _notebookCover(String payload) {
    try {
      final json = jsonDecode(payload);
      final cover = json is Map ? json['cover'] : null;
      return cover is String ? cover : null;
    } on FormatException {
      return null;
    }
  }

  /// 背景与材质设置里出现的全部背景图文件名（全局与各区域）。
  static Set<String> _backgroundNames(String? raw) {
    if (raw == null) return const <String>{};
    final names = <String>{};
    void walk(Object? node) {
      if (node is Map) {
        final image = node['image'];
        if (image is String && AppBackgroundStorageService.isValidName(image)) {
          names.add(image);
        }
        node.values.forEach(walk);
      } else if (node is List) {
        node.forEach(walk);
      }
    }

    try {
      walk(jsonDecode(raw));
    } on FormatException {
      return const <String>{};
    }
    return names;
  }

  static bool _replaceImageNames(Object? node, Map<String, String> names) {
    var changed = false;
    if (node is Map) {
      final image = node['image'];
      if (image is String && names.containsKey(image)) {
        node['image'] = names[image];
        changed = true;
      }
      for (final value in node.values.toList(growable: false)) {
        changed = _replaceImageNames(value, names) || changed;
      }
    } else if (node is List) {
      for (final value in node) {
        changed = _replaceImageNames(value, names) || changed;
      }
    }
    return changed;
  }
}

typedef _HeifScanRequest = ({
  String root,
  List<(int, String, String?)> diaries,
  List<String> notebookPayloads,
  String? surfaceRaw,
});

/// 后台扫描的结果：托管目录里被引用的 HEIF 文件，与引用了其中任何一个的
/// 日记（本地 id；正文图片或封面）。
typedef _HeifScanResult = ({List<String> heif, Set<int> diaryIds});

/// 后台 isolate 入口：收集托管目录里被引用的图片，按文件头挑出 HEIF。
_HeifScanResult _scanHeifReferences(_HeifScanRequest request) {
  final root = request.root;
  final byDiary = <int, Set<String>>{};
  final candidates = <String>{};
  for (final (id, content, cover) in request.diaries) {
    final paths = <String>{
      for (final media in diaryContentMedia(content))
        if (media.kind == DiaryBlockMediaKind.image)
          ?HeifMediaRepairService._managedPath(
            media.path,
            root,
            HeifMediaRepairService._imageDirectories,
          ),
      ?HeifMediaRepairService._managedPath(
        cover,
        root,
        HeifMediaRepairService._coverDirectories,
      ),
    };
    if (paths.isEmpty) continue;
    byDiary[id] = paths;
    candidates.addAll(paths);
  }
  for (final payload in request.notebookPayloads) {
    final cover = HeifMediaRepairService._managedPath(
      HeifMediaRepairService._notebookCover(payload),
      root,
      HeifMediaRepairService._coverDirectories,
    );
    if (cover != null) candidates.add(cover);
  }
  for (final name in HeifMediaRepairService._backgroundNames(
    request.surfaceRaw,
  )) {
    candidates.add(
      p.join(root, AppBackgroundStorageService.directoryName, name),
    );
  }
  final heif = <String>{
    for (final path in candidates)
      if (HeifImageConverter.isHeifFileSync(path)) path,
  };
  return (
    heif: heif.toList(growable: false),
    diaryIds: <int>{
      for (final entry in byDiary.entries)
        if (entry.value.any(heif.contains)) entry.key,
    },
  );
}
