import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:node_diary/core/services/day_photo_library.dart';
import 'package:path/path.dart' as p;

/// 1×1 透明 PNG：缩略图占位，解码不依赖平台插件。
final Uint8List kTinyPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// [DayPhotoLibrary] 的测试替身：按日期返回预设照片，记录每次调用。
class FakeDayPhotoLibrary implements DayPhotoLibrary {
  FakeDayPhotoLibrary({
    this.access = DayPhotoAccess.granted,
    this.accessAfterRequest = DayPhotoAccess.granted,
    this.isSupported = true,
    Map<DateTime, List<DayPhoto>>? photosByDay,
  }) : photosByDay = photosByDay ?? <DateTime, List<DayPhoto>>{};

  DayPhotoAccess access;
  DayPhotoAccess accessAfterRequest;
  @override
  final bool isSupported;
  final Map<DateTime, List<DayPhoto>> photosByDay;

  /// 照片 id → 原图文件；没有登记的照片 [fileOf] 返回 null（模拟已被删除）。
  final Map<String, File> files = <String, File>{};

  /// 非空时 [photosOn] 等待对应日期的 Completer，用于测试过期结果被丢弃。
  final Map<DateTime, Completer<List<DayPhoto>>> pendingQueries =
      <DateTime, Completer<List<DayPhoto>>>{};

  Object? queryError;
  final List<DateTime> queriedDays = <DateTime>[];
  int checkCount = 0;
  int requestCount = 0;
  int openSettingsCount = 0;
  int manageLimitedCount = 0;
  int releaseCount = 0;

  @override
  Future<DayPhotoAccess> checkAccess() async {
    checkCount++;
    return access;
  }

  @override
  Future<DayPhotoAccess> requestAccess() async {
    requestCount++;
    access = accessAfterRequest;
    return access;
  }

  @override
  Future<void> openSettings() async => openSettingsCount++;

  @override
  Future<void> manageLimitedSelection() async => manageLimitedCount++;

  @override
  Future<List<DayPhoto>> photosOn(DateTime day) async {
    queriedDays.add(day);
    final error = queryError;
    if (error != null) throw error;
    final pending = pendingQueries[day];
    if (pending != null) return pending.future;
    return photosByDay[day] ?? const <DayPhoto>[];
  }

  @override
  ImageProvider thumbnailOf(DayPhoto photo) => MemoryImage(kTinyPng);

  @override
  Future<PlatformFile?> fileOf(DayPhoto photo) async {
    final file = files[photo.id];
    if (file == null || !await file.exists()) return null;
    return PlatformFile(
      name: p.basename(file.path),
      path: file.path,
      size: await file.length(),
    );
  }

  @override
  Future<void> releaseFiles() async => releaseCount++;
}
