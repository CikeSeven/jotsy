import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';
import 'diary_media_sweeper.dart';
import 'settings_service.dart';

/// 按引用回收日记媒体文件（图片、视频、附件、录音、封面）与选择器缓存。
///
/// 为什么不在编辑时直接删：移除图片、替换封面之后，用户仍可能撤销或放弃
/// 修改，已保存的日记也还指向旧文件；复制粘贴还会让多篇日记共用同一文件。
/// 所以编辑期只改文档，文件统一在这里回收：
/// - 引用来源：全部日记（含归档、回收站、时间胶囊）的正文/封面/metadata，
///   以及新建日记草稿；
/// - 宽限期：[gracePeriod] 内写入的文件一律保留，覆盖“刚导入还没保存”的会话；
/// - 触发：启动后延迟一次（[scheduleStartupSweep]）、回收站彻底删除后一次。
///   请求串行执行，后一次一定读取到前一次之后的引用快照。
///
/// 主 isolate 只查询数据库和读取草稿；JSON 遍历与文件扫描在后台 isolate 中
/// 进行。任何一步失败都整轮放弃、不删除任何文件。
class DiaryMediaCleanupService {
  DiaryMediaCleanupService({
    required this._database,
    required this._settings,
    Future<Directory> Function()? documentsDirectory,
    Future<Directory> Function()? temporaryDirectory,
    DateTime Function()? clock,
    this.gracePeriod = const Duration(hours: 24),
    this.startupDelay = const Duration(seconds: 30),
  }) : _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _clock = clock ?? DateTime.now;

  final AppDatabase _database;
  final Future<SettingsService> Function() _settings;
  final Future<Directory> Function() _documentsDirectory;
  final Future<Directory> Function() _temporaryDirectory;
  final DateTime Function() _clock;
  final Duration gracePeriod;
  final Duration startupDelay;

  Future<DiaryMediaSweepReport?> _tail = Future.value();
  Timer? _startupTimer;
  bool _startupScheduled = false;
  bool _disposed = false;

  /// 启动后只安排一次，延迟执行以免与首屏加载争抢 IO。
  void scheduleStartupSweep() {
    if (_startupScheduled || _disposed) return;
    _startupScheduled = true;
    _startupTimer = Timer(startupDelay, () {
      _startupTimer = null;
      unawaited(sweep());
    });
  }

  /// 排队执行一轮回收；失败返回 null，不向调用方抛出。
  Future<DiaryMediaSweepReport?> sweep() =>
      _tail = _tail.then((_) => _sweepSafely());

  Future<DiaryMediaSweepReport?> _sweepSafely() async {
    if (_disposed) return null;
    try {
      final report = await _runInBackground(await _buildRequest());
      if (report.deletedFiles > 0) {
        debugPrint(
          'Diary media cleanup removed ${report.deletedFiles} files '
          '(${report.freedBytes} bytes).',
        );
      }
      return report;
    } catch (error, stackTrace) {
      debugPrint('Diary media cleanup skipped: $error\n$stackTrace');
      return null;
    }
  }

  Future<DiaryMediaSweepRequest> _buildRequest() async {
    final diaries = _database.diaries;
    final rows = await (_database.selectOnly(
      diaries,
    )..addColumns([diaries.content, diaries.cover, diaries.metadata])).get();
    final settings = await _settings();
    return DiaryMediaSweepRequest(
      documentsPath: (await _documentsDirectory()).path,
      temporaryPath: (await _temporaryDirectory()).path,
      referenceSources: [
        for (final row in rows) ...[
          row.read(diaries.content),
          row.read(diaries.cover),
          row.read(diaries.metadata),
        ],
        settings.createDiaryDraftRaw,
      ],
      now: _clock(),
      gracePeriod: gracePeriod,
    );
  }

  /// 静态方法保证闭包只捕获请求本身，不会把数据库等不可发送对象带进 isolate。
  static Future<DiaryMediaSweepReport> _runInBackground(
    DiaryMediaSweepRequest request,
  ) => Isolate.run(() => sweepDiaryMediaFiles(request));

  void dispose() {
    _disposed = true;
    _startupTimer?.cancel();
    _startupTimer = null;
  }
}
