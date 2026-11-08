import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
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

/// 删除、压缩、清理之后：总览、媒体页与设置首页的“已用”一起重新读取。
void refreshStorageViews(WidgetRef ref) {
  ref
    ..invalidate(storageReportProvider)
    ..invalidate(storageQuickTotalProvider);
}
