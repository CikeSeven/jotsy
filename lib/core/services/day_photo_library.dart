import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'day_photo_library_photo_manager.dart';

/// 补写日记时“这天拍的照片”（含视频）的相册读取接口。
///
/// 职责边界：
/// - 输入：某一天（按本地日历日）；
/// - 输出：这天拍摄的图片与视频列表、缩略图、预览用的大图与视频播放地址、
///   导入用的文件副本；
/// - 副作用：查询与申请相册读取权限、打开系统设置；只读相册，从不写入或
///   删除相册里的任何文件。
///
/// UI 与编排层只依赖这个接口，测试用假实现替换，不需要模拟平台插件。
abstract class DayPhotoLibrary {
  /// 当前平台是否能按日期读取相册（Android / iOS）；其余平台整块功能不出现。
  bool get isSupported;

  /// 只读取当前授权状态，不弹任何系统对话框。
  Future<DayPhotoAccess> checkAccess();

  /// 申请图片与视频的读取权限（会弹系统对话框）；只能由用户的点按触发。
  /// 返回申请之后的状态（与 [checkAccess] 同一口径）。
  Future<DayPhotoAccess> requestAccess();

  /// 打开本应用的系统设置页，供用户在拒绝后手动开启权限。
  Future<void> openSettings();

  /// 部分授权（Android 14+ / iOS 14+）时重新挑选允许访问的照片与视频。
  Future<void> manageLimitedSelection();

  /// [day] 当天（本地 00:00 至次日 00:00）拍摄的图片（[includeVideos] 时连同
  /// 视频），按拍摄时间升序。
  Future<List<DayPhoto>> photosOn(DateTime day, {bool includeVideos = true});

  /// 显示用缩略图（只解码到格子尺寸）；视频为它的封面帧。
  ImageProvider thumbnailOf(DayPhoto photo);

  /// 预览页显示的大图：保持比例缩小到长边不超过 [maxExtent] 像素再解码
  /// （不解码原图：五千万像素的照片原样解码要两百多 MB）。视频为封面帧。
  ImageProvider previewOf(DayPhoto photo, {required int maxExtent});

  /// 视频的播放地址（Android 为 `content://` 地址，iOS 为文件地址），直接
  /// 交给播放器读取相册原文件，不复制；不是视频或已读不到时返回 null。
  Future<String?> videoSourceOf(DayPhoto photo);

  /// 取出原文件供导入日记私有目录；已被删除或无法读取时返回 null。
  ///
  /// 返回的路径可能是相册原文件，调用方只能读取，不得删除或移动。
  Future<PlatformFile?> fileOf(DayPhoto photo);

  /// 导入结束后释放插件为读取原文件生成的缓存副本。
  Future<void> releaseFiles();
}

/// 相册读取权限状态（图片与视频合起来看）。
enum DayPhotoAccess {
  /// 图片与视频都可读取。
  granted,

  /// 只能读取用户挑选过的部分照片与视频（Android 14+ / iOS 14+）。
  limited,

  /// 全部图片可读，视频未授权：只申请过图片权限的旧版本升级上来的
  /// Android 13+ 设备（图片与视频是两项权限）。照片照常列出，另给一行
  /// “允许访问视频”，点按才申请。
  imagesOnly,

  /// 未授权。Android 无法区分“从未询问”与“已拒绝”，两者都归到这里。
  denied;

  bool get canRead => this != DayPhotoAccess.denied;

  /// 能否列出视频：[imagesOnly] 时只查图片。
  bool get canReadVideos =>
      this == DayPhotoAccess.granted || this == DayPhotoAccess.limited;
}

/// 把图片与视频各自的授权状态合成一个 [DayPhotoAccess]。
///
/// iOS 的相册授权与 Android 12 及以下的读外部存储本就一项管两种，两边总是
/// 相同；只有 Android 13+ 会出现“图片已授权、视频没有”（[imagesOnly]）。
/// 两边都读不了才算 [DayPhotoAccess.denied]；其余不一致的组合（任一边部分
/// 授权、只授权了视频）都按部分授权处理：能读到什么就列出什么，并给出
/// “选择更多”。
DayPhotoAccess combineDayPhotoAccess({
  required DayPhotoAccess images,
  required DayPhotoAccess videos,
}) {
  if (!images.canRead && !videos.canRead) return DayPhotoAccess.denied;
  if (images == DayPhotoAccess.granted) {
    return switch (videos) {
      DayPhotoAccess.granted => DayPhotoAccess.granted,
      DayPhotoAccess.denied => DayPhotoAccess.imagesOnly,
      _ => DayPhotoAccess.limited,
    };
  }
  return DayPhotoAccess.limited;
}

/// 相册里的一张照片或一段视频：只保留界面与导入需要的字段，不暴露插件类型。
@immutable
class DayPhoto {
  const DayPhoto({
    required this.id,
    required this.takenAt,
    this.width = 0,
    this.height = 0,
    this.isVideo = false,
    this.duration = Duration.zero,
  });

  /// 平台相册里的稳定 id（Android MediaStore `_id`，iOS localIdentifier）。
  final String id;

  /// 拍摄时间（本地时间）；没有拍摄时间的取加入相册的时间。
  final DateTime takenAt;
  final int width;
  final int height;

  /// 是视频：插入为视频块、不能设为封面、预览页里播放。
  final bool isVideo;

  /// 视频时长；图片为 0。
  final Duration duration;

  @override
  bool operator ==(Object other) => other is DayPhoto && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// [day] 所在本地日历日的起止时间：[start, end)。
///
/// 按日历加一天而不是加 24 小时，夏令时切换日也只覆盖这一天。
({DateTime start, DateTime end}) dayPhotoRange(DateTime day) {
  final start = DateTime(day.year, day.month, day.day);
  return (start: start, end: DateTime(day.year, day.month, day.day + 1));
}

/// 相册读取服务；测试覆盖为假实现。
final dayPhotoLibraryProvider = Provider<DayPhotoLibrary>(
  (Ref ref) => PhotoManagerDayPhotoLibrary(),
);
