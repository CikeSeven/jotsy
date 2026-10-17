import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import 'day_photo_library.dart';

/// [DayPhotoLibrary] 的 photo_manager 实现（Android / iOS）。
///
/// 按“拍摄时间”而不是“加入相册的时间”筛选：photo_manager 在 Android 上的
/// `createDate` 过滤列是 `date_added`，换机迁移、从电脑拷入的老照片都会落到
/// 拷入那天。因此 Android 直接写 MediaStore 条件，优先比较 `datetaken`（毫秒），
/// 没有拍摄时间的图片才退回 `date_added`（秒）——与插件给实体取
/// `createDateTime` 的规则一致，列表里显示的时间与筛选口径相同。
class PhotoManagerDayPhotoLibrary implements DayPhotoLibrary {
  PhotoManagerDayPhotoLibrary();

  /// 只申请图片权限：Android 13+ 只请求 READ_MEDIA_IMAGES（及 14+ 的部分
  /// 授权），不顺带要视频、音频与照片位置。
  static const PermissionRequestOption _permission = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.image,
      mediaLocation: false,
    ),
  );

  /// 单日最多列出的张数：再多也翻不完，查询与缩略图解码都按这个上限封顶。
  static const int maxPhotosPerDay = 500;

  // 面板格子最大 128dp，3 倍屏约 384px；320 兼顾清晰度与解码内存。
  static const ThumbnailSize _thumbnailSize = ThumbnailSize.square(320);

  // 最近一次查询得到的实体：缩略图与导入按 id 取回，免得逐张再查一次库。
  final Map<String, AssetEntity> _entities = <String, AssetEntity>{};

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<DayPhotoAccess> checkAccess() async {
    if (!isSupported) return DayPhotoAccess.denied;
    return _mapState(
      await PhotoManager.getPermissionState(requestOption: _permission),
    );
  }

  @override
  Future<DayPhotoAccess> requestAccess() async {
    if (!isSupported) return DayPhotoAccess.denied;
    return _mapState(
      await PhotoManager.requestPermissionExtend(requestOption: _permission),
    );
  }

  @override
  Future<void> openSettings() => PhotoManager.openSetting();

  @override
  Future<void> manageLimitedSelection() =>
      PhotoManager.presentLimited(type: RequestType.image);

  @override
  Future<List<DayPhoto>> photosOn(DateTime day) async {
    final range = dayPhotoRange(day);
    final assets = await PhotoManager.getAssetListRange(
      start: 0,
      end: maxPhotosPerDay,
      type: RequestType.image,
      filterOption: _dayFilter(range.start, range.end),
    );
    _entities
      ..clear()
      ..addEntries(assets.map((asset) => MapEntry(asset.id, asset)));
    final photos = <DayPhoto>[
      for (final asset in assets)
        DayPhoto(
          id: asset.id,
          takenAt: asset.createDateTime,
          width: asset.width,
          height: asset.height,
        ),
    ];
    // 数据库排序对“无拍摄时间、退回加入时间”的图片不准，统一在这里重排。
    photos.sort((a, b) => a.takenAt.compareTo(b.takenAt));
    return photos;
  }

  @override
  ImageProvider thumbnailOf(DayPhoto photo) {
    final entity = _entities[photo.id] ?? _placeholderEntity(photo);
    return AssetEntityImageProvider(
      entity,
      isOriginal: false,
      thumbnailSize: _thumbnailSize,
    );
  }

  @override
  Future<PlatformFile?> fileOf(DayPhoto photo) async {
    final entity = _entities[photo.id] ?? await AssetEntity.fromId(photo.id);
    if (entity == null) return null;
    // `file` 在 iOS 上把 HEIC 转成 JPEG（必要时从 iCloud 下载），Android 上
    // 直接给出原文件；两端都保证应用能解码显示。
    final file = await entity.file;
    if (file == null || !await file.exists()) return null;
    return PlatformFile(
      name: p.basename(file.path),
      path: file.path,
      size: await file.length(),
    );
  }

  @override
  Future<void> releaseFiles() async {
    try {
      await PhotoManager.clearFileCache();
    } catch (error) {
      debugPrint('Day photo cache cleanup failed: $error');
    }
  }

  static DayPhotoAccess _mapState(PermissionState state) => switch (state) {
    PermissionState.authorized => DayPhotoAccess.granted,
    PermissionState.limited => DayPhotoAccess.limited,
    _ => DayPhotoAccess.denied,
  };

  static CustomFilter _dayFilter(DateTime start, DateTime end) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // 插件会在条件后拼上 `AND (mediaType == …)`，这里不能出现顶层 OR。
      final from = CustomColumns.utils.convertDateTimeToSql(start);
      final to = CustomColumns.utils.convertDateTimeToSql(end);
      return CustomFilter.sql(
        where: 'creationDate >= $from AND creationDate < $to',
        orderBy: const <OrderByItem>[OrderByItem.asc('creationDate')],
      );
    }
    // Android 的自定义条件会整体替换插件自带的媒体类型条件，须自己限定图片。
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    final startS = startMs ~/ 1000;
    final endS = endMs ~/ 1000;
    return CustomFilter.sql(
      where:
          'media_type = ${MediaStoreMediaType.image} AND ('
          '(datetaken >= $startMs AND datetaken < $endMs) OR '
          '((datetaken IS NULL OR datetaken <= 0) AND '
          'date_added >= $startS AND date_added < $endS))',
      orderBy: const <OrderByItem>[OrderByItem.asc('datetaken')],
    );
  }

  /// 缓存里找不到实体（理论上不会发生）时按 id 构造一个最小实体，让缩略图
  /// 照常按 id 去取，而不是抛错。
  static AssetEntity _placeholderEntity(DayPhoto photo) => AssetEntity(
    id: photo.id,
    typeInt: AssetType.image.index,
    width: photo.width,
    height: photo.height,
  );
}

/// MediaStore `media_type` 列的取值（`MediaStore.Files.FileColumns`）。
abstract final class MediaStoreMediaType {
  static const int image = 1;
}
