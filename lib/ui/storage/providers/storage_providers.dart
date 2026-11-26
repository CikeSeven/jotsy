import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/app_data_location.dart';
import '../../../core/services/app_data_location_migrator.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/desktop_save_service.dart';
import '../../../core/services/storage/storage_duplicates.dart';
import '../../../core/services/storage/storage_media_service.dart';
import '../../../core/services/storage/storage_usage_models.dart';
import '../models/storage_preferences.dart';
import '../viewmodels/storage_media_view.dart';

/// 存储管理的编排服务（单例：视频元数据与缩略图的缓存跨页面保留）。
final storageMediaServiceProvider = Provider<StorageMediaService>(
  (Ref ref) => StorageMediaService(
    database: ref.watch(appDatabaseProvider),
    settings: () => ref.read(settingsServiceProvider.future),
    mediaCleanup: ref.watch(diaryMediaCleanupServiceProvider),
  ),
);

/// 一次占用扫描。一次性读取同步数据：登记在 `syncedDataRefreshProvider`，
/// 局域网同步写库后重新扫描；删除、压缩、清理之后由流程主动失效。
final storageReportProvider = FutureProvider.autoDispose<StorageUsageReport>(
  (Ref ref) => ref.watch(storageMediaServiceProvider).scan(),
);

/// 重复文件（内容逐字节相同的托管媒体）。跟着占用扫描走：扫描重新读取时
/// 一起重算（同步写库后、删除 / 压缩 / 合并之后）；只给同一目录范围里大小
/// 相同的文件算哈希，算过的有缓存。
final storageDuplicatesProvider = FutureProvider.autoDispose<StorageDuplicates>(
  (Ref ref) async {
    final report = await ref.watch(storageReportProvider.future);
    return ref.watch(storageMediaServiceProvider).findDuplicates(report);
  },
);

/// 设置首页“存储管理”行的“已用”（只累加文件大小，不解析日记）。
final storageQuickTotalProvider = FutureProvider.autoDispose<int>(
  (Ref ref) => ref.watch(storageMediaServiceProvider).quickTotal(),
);

/// 存储管理页的本机偏好（见 [StoragePreferences]）。
final storagePreferencesProvider =
    NotifierProvider<StoragePreferencesNotifier, StoragePreferences>(
      StoragePreferencesNotifier.new,
    );

class StoragePreferencesNotifier extends Notifier<StoragePreferences> {
  @override
  StoragePreferences build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    return StoragePreferences.decode(settings?.storagePreferencesRaw);
  }

  /// 立即生效并写入设置；写入失败只影响下次打开时的默认值。
  Future<void> save(StoragePreferences next) async {
    if (next == state) return;
    state = next;
    final settings = ref.read(settingsServiceProvider).asData?.value;
    await settings?.setStoragePreferencesRaw(next.encode());
  }
}

/// 当前的压缩档位与平台能否压缩。
final storageCompressContextProvider =
    Provider.autoDispose<StorageCompressContext>((Ref ref) {
      final preferences = ref.watch(storagePreferencesProvider);
      return StorageCompressContext(
        supported: ref
            .watch(storageMediaServiceProvider)
            .compressor
            .supportsCompression,
        imagePreset: preferences.imagePreset,
        videoPreset: preferences.videoPreset,
      );
    });

/// 桌面端数据存储位置服务（非桌面平台不展示自定义路径入口）。
final storageLocationStoreProvider = Provider<AppDataLocationStore>(
  (Ref ref) => AppDataLocationStore.instance,
);

/// 桌面端当前解析出的数据位置；非桌面端或测试未挂载路径插件时为 null。
final storageLocationProvider =
    FutureProvider.autoDispose<AppDataLocationResolution?>((Ref ref) async {
      if (!AppPlatform.supportsCustomDataDirectory) return null;
      try {
        return await ref.watch(storageLocationStoreProvider).resolve();
      } on MissingPluginException {
        return null;
      }
    });

/// 桌面端迁移器（测试可注入假实例）。
final storageLocationMigratorProvider = Provider<AppDataLocationMigrator>(
  (Ref ref) =>
      AppDataLocationMigrator(store: ref.watch(storageLocationStoreProvider)),
);

/// 选择文件夹对话框（测试可覆盖）。
final storageDirectoryPickerProvider = Provider<DesktopDirectoryPicker>(
  (Ref ref) =>
      ({required String dialogTitle}) =>
          FilePicker.platform.getDirectoryPath(dialogTitle: dialogTitle),
);

/// 打开本地文件夹（测试可覆盖）。
final storageFolderOpenerProvider = Provider<Future<bool> Function(String)>(
  (Ref ref) => (String path) async {
    await Directory(path).create(recursive: true);
    return launchUrl(Uri.directory(path), mode: LaunchMode.externalApplication);
  },
);

/// 删除、压缩、合并、清理之后：总览、媒体页、重复文件页与设置首页的
/// “已用”一起重新读取（重复文件跟着扫描重算）。
void refreshStorageViews(WidgetRef ref) {
  ref
    ..invalidate(storageReportProvider)
    ..invalidate(storageQuickTotalProvider)
    ..invalidate(storageLocationProvider);
}
