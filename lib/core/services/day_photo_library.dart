import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'day_photo_library_photo_manager.dart';

/// 补写日记时“这天拍的照片”的相册读取接口。
///
/// 职责边界：
/// - 输入：某一天（按本地日历日）；
/// - 输出：这天拍摄的图片列表、缩略图、导入用的文件副本；
/// - 副作用：查询与申请相册读取权限、打开系统设置；只读相册，从不写入或
///   删除相册里的任何文件。
///
/// UI 与编排层只依赖这个接口，测试用假实现替换，不需要模拟平台插件。
abstract class DayPhotoLibrary {
  /// 当前平台是否能按日期读取相册（Android / iOS）；其余平台整块功能不出现。
  bool get isSupported;

  /// 只读取当前授权状态，不弹任何系统对话框。
  Future<DayPhotoAccess> checkAccess();

  /// 申请读取权限（会弹系统对话框）；只能由用户的点按触发。
  Future<DayPhotoAccess> requestAccess();

  /// 打开本应用的系统设置页，供用户在拒绝后手动开启权限。
  Future<void> openSettings();

  /// 部分授权（Android 14+ / iOS 14+）时重新挑选允许访问的照片。
  Future<void> manageLimitedSelection();

  /// [day] 当天（本地 00:00 至次日 00:00）拍摄的图片，按拍摄时间升序。
  Future<List<DayPhoto>> photosOn(DateTime day);

  /// 显示用缩略图（只解码到格子尺寸）。
  ImageProvider thumbnailOf(DayPhoto photo);

  /// 取出原图供导入日记私有目录；照片已被删除或无法读取时返回 null。
  ///
  /// 返回的路径可能是相册原文件，调用方只能读取，不得删除或移动。
  Future<PlatformFile?> fileOf(DayPhoto photo);

  /// 导入结束后释放插件为读取原图生成的缓存副本。
  Future<void> releaseFiles();
}

/// 相册读取权限状态。
enum DayPhotoAccess {
  /// 可读取全部照片。
  granted,

  /// 只能读取用户挑选过的部分照片（Android 14+ / iOS 14+）。
  limited,

  /// 未授权。Android 无法区分“从未询问”与“已拒绝”，两者都归到这里。
  denied;

  bool get canRead => this != DayPhotoAccess.denied;
}

/// 相册里的一张照片：只保留界面与导入需要的字段，不暴露插件类型。
@immutable
class DayPhoto {
  const DayPhoto({
    required this.id,
    required this.takenAt,
    this.width = 0,
    this.height = 0,
  });

  /// 平台相册里的稳定 id（Android MediaStore `_id`，iOS localIdentifier）。
  final String id;

  /// 拍摄时间（本地时间）；没有拍摄时间的图片取加入相册的时间。
  final DateTime takenAt;
  final int width;
  final int height;

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
