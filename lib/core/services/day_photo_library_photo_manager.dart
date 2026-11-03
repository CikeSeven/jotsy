import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import 'app_platform.dart';
import 'day_photo_library.dart';

/// [DayPhotoLibrary] 的 photo_manager 实现（Android / iOS）。
///
/// 按“拍摄时间”而不是“加入相册的时间”筛选：photo_manager 在 Android 上的
/// `createDate` 过滤列是 `date_added`，换机迁移、从电脑拷入的老照片都会落到
/// 拷入那天。因此 Android 直接写 MediaStore 条件，优先比较 `datetaken`（毫秒），
/// 没有拍摄时间的才退回 `date_added`（秒）——与插件给实体取
/// `createDateTime` 的规则一致，列表里显示的时间与筛选口径相同。图片与视频
/// 都有这两列，同一条件一起查。
class PhotoManagerDayPhotoLibrary implements DayPhotoLibrary {
  PhotoManagerDayPhotoLibrary();

  /// 申请图片与视频权限：Android 13+ 请求 READ_MEDIA_IMAGES 与
  /// READ_MEDIA_VIDEO（同属“照片和视频”一组，系统只弹一次）及 14+ 的部分
  /// 授权，不顺带要音频与照片位置。
  static const PermissionRequestOption _permission = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.common,
      mediaLocation: false,
    ),
  );

  /// 只看图片 / 只看视频的授权状态：两者在 Android 13+ 是两项权限，合并成
  /// 一个状态见 [combineDayPhotoAccess]。
  static const PermissionRequestOption _imagePermission =
      PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
      );
  static const PermissionRequestOption _videoPermission =
      PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.video,
          mediaLocation: false,
        ),
      );

  /// 单日最多列出的条数：再多也翻不完，查询与缩略图解码都按这个上限封顶。
  static const int maxPhotosPerDay = 500;

  // 面板格子最大 128dp，3 倍屏约 384px；320 兼顾清晰度与解码内存。
  static const ThumbnailSize _thumbnailSize = ThumbnailSize.square(320);

  // 最近一次查询得到的实体：缩略图、预览与导入按 id 取回，免得逐张再查一次库。
  final Map<String, AssetEntity> _entities = <String, AssetEntity>{};

  @override
  bool get isSupported => AppPlatform.isMobile;

  @override
  Future<DayPhotoAccess> checkAccess() async {
    if (!isSupported) return DayPhotoAccess.denied;
    final images = await PhotoManager.getPermissionState(
      requestOption: _imagePermission,
    );
    final videos = await PhotoManager.getPermissionState(
      requestOption: _videoPermission,
    );
    return combineDayPhotoAccess(
      images: _mapState(images),
      videos: _mapState(videos),
    );
  }

  @override
  Future<DayPhotoAccess> requestAccess() async {
    if (!isSupported) return DayPhotoAccess.denied;
    // 插件把“图片已授权、视频被拒”合并报成部分授权，与本类的口径不同：
    // 申请完按两项分别重新读取。
    await PhotoManager.requestPermissionExtend(requestOption: _permission);
    final access = await checkAccess();
    if (access != DayPhotoAccess.imagesOnly ||
        defaultTargetPlatform != TargetPlatform.android) {
      return access;
    }
    // Android 14+ 授予“全部照片”时系统同时授予 READ_MEDIA_VISUAL_USER_SELECTED，
    // 插件见到它就直接报已授权、不向系统申请：只申请过图片的旧用户点“允许
    // 访问视频”会毫无反应。presentLimited 总是真正发起请求（图片 + 视频 +
    // 部分授权），由系统弹框；Android 13 上它什么也不做，上面的申请已经弹过。
    try {
      await PhotoManager.presentLimited(type: RequestType.common);
    } catch (error) {
      debugPrint('Day photo video permission request failed: $error');
    }
    return checkAccess();
  }

  @override
  Future<void> openSettings() => PhotoManager.openSetting();

  @override
  Future<void> manageLimitedSelection() =>
      PhotoManager.presentLimited(type: RequestType.common);

  @override
  Future<List<DayPhoto>> photosOn(
    DateTime day, {
    bool includeVideos = true,
  }) async {
    final range = dayPhotoRange(day);
    final assets = await PhotoManager.getAssetListRange(
      start: 0,
      end: maxPhotosPerDay,
      type: includeVideos ? RequestType.common : RequestType.image,
      filterOption: _dayFilter(
        range.start,
        range.end,
        includeVideos: includeVideos,
      ),
    );
    _entities
      ..clear()
      ..addEntries(assets.map((asset) => MapEntry(asset.id, asset)));
    final photos = <DayPhoto>[
      for (final asset in assets)
        if (asset.type == AssetType.image || asset.type == AssetType.video)
          DayPhoto(
            id: asset.id,
            takenAt: asset.createDateTime,
            // 按显示方向：竖拍的照片 EXIF 旋转 90° 时宽高互换，预览的
            // 解码尺寸与画面比例都以它为准。
            width: asset.orientatedWidth,
            height: asset.orientatedHeight,
            isVideo: asset.type == AssetType.video,
            duration: asset.type == AssetType.video
                ? asset.videoDuration
                : Duration.zero,
          ),
    ];
    // 数据库排序对“无拍摄时间、退回加入时间”的条目不准，统一在这里重排。
    photos.sort((a, b) => a.takenAt.compareTo(b.takenAt));
    return photos;
  }

  @override
  ImageProvider thumbnailOf(DayPhoto photo) => AssetEntityImageProvider(
    _entityOf(photo),
    isOriginal: false,
    thumbnailSize: _thumbnailSize,
  );

  @override
  ImageProvider previewOf(DayPhoto photo, {required int maxExtent}) =>
      AssetEntityImageProvider(
        _entityOf(photo),
        // 不取原图：原图按原尺寸解码，大照片动辄上百 MB；缩略图接口按
        // 请求尺寸缩小解码、保持比例。
        isOriginal: false,
        thumbnailSize: dayPhotoPreviewSize(photo, maxExtent),
      );

  @override
  Future<String?> videoSourceOf(DayPhoto photo) async {
    if (!photo.isVideo) return null;
    final entity = _entities[photo.id] ?? await AssetEntity.fromId(photo.id);
    if (entity == null) return null;
    return entity.getMediaUrl();
  }

  @override
  Future<PlatformFile?> fileOf(DayPhoto photo) async {
    final entity = _entities[photo.id] ?? await AssetEntity.fromId(photo.id);
    if (entity == null) return null;
    // `file` 在 iOS 上把 HEIC 转成 JPEG（必要时从 iCloud 下载），Android 上
    // 直接给出原文件（可能是 HEIC，插入时由 DiaryMediaStorageService 转成
    // JPEG，桌面版才显示得了）。视频同样给出可读的文件。
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

  /// 缓存里找不到实体（理论上不会发生）时按 id 构造一个最小实体，让缩略图
  /// 照常按 id 去取，而不是抛错。
  AssetEntity _entityOf(DayPhoto photo) =>
      _entities[photo.id] ??
      AssetEntity(
        id: photo.id,
        typeInt: (photo.isVideo ? AssetType.video : AssetType.image).index,
        width: photo.width,
        height: photo.height,
        duration: photo.duration.inSeconds,
      );

  static DayPhotoAccess _mapState(PermissionState state) => switch (state) {
    PermissionState.authorized => DayPhotoAccess.granted,
    PermissionState.limited => DayPhotoAccess.limited,
    _ => DayPhotoAccess.denied,
  };

  static CustomFilter _dayFilter(
    DateTime start,
    DateTime end, {
    required bool includeVideos,
  }) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // 插件会在条件后拼上 `AND (mediaType == …)`（按请求的类型限定图片或
      // 图片 + 视频），这里不能出现顶层 OR。
      final from = CustomColumns.utils.convertDateTimeToSql(start);
      final to = CustomColumns.utils.convertDateTimeToSql(end);
      return CustomFilter.sql(
        where: 'creationDate >= $from AND creationDate < $to',
        orderBy: const <OrderByItem>[OrderByItem.asc('creationDate')],
      );
    }
    // Android 的自定义条件会整体替换插件自带的媒体类型条件，须自己限定类型。
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    final startS = startMs ~/ 1000;
    final endS = endMs ~/ 1000;
    final types = includeVideos
        ? 'media_type IN (${MediaStoreMediaType.image}, '
              '${MediaStoreMediaType.video})'
        : 'media_type = ${MediaStoreMediaType.image}';
    return CustomFilter.sql(
      where:
          '$types AND ('
          '(datetaken >= $startMs AND datetaken < $endMs) OR '
          '((datetaken IS NULL OR datetaken <= 0) AND '
          'date_added >= $startS AND date_added < $endS))',
      orderBy: const <OrderByItem>[OrderByItem.asc('datetaken')],
    );
  }
}

/// 预览大图的解码尺寸：保持 [photo] 的显示比例，长边不超过 [maxExtent]，
/// 也不超过原图（小图不放大）。尺寸未知时按方形请求，平台按原比例缩放。
ThumbnailSize dayPhotoPreviewSize(DayPhoto photo, int maxExtent) {
  final width = photo.width;
  final height = photo.height;
  if (width <= 0 || height <= 0) return ThumbnailSize.square(maxExtent);
  final longest = width > height ? width : height;
  if (longest <= maxExtent) return ThumbnailSize(width, height);
  final scale = maxExtent / longest;
  return ThumbnailSize(
    (width * scale).round().clamp(1, maxExtent),
    (height * scale).round().clamp(1, maxExtent),
  );
}

/// MediaStore `media_type` 列的取值（`MediaStore.Files.FileColumns`）。
abstract final class MediaStoreMediaType {
  static const int image = 1;
  static const int video = 3;
}
