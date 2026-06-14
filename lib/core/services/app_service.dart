import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'app_update_service.dart';
import 'settings_service.dart';
import 'tag_order_codec.dart';
import 'webdav_settings_service.dart';
import 'webdav_sync_service.dart';

/// 全局数据库 provider。
///
/// 生命周期与 ProviderContainer 绑定，在 dispose 时关闭数据库连接，
/// 避免页面销毁后遗留文件句柄。
final appDatabaseProvider = Provider<AppDatabase>((Ref ref) {
  final database = AppDatabase();
  ref.onDispose(() {
    database.close();
  });
  return database;
});

/// 全局设置服务 provider。
///
/// 采用 FutureProvider 异步初始化 SharedPreferences，并在 UI 层通过
/// `AsyncValue` 处理加载/错误态。
final settingsServiceProvider = FutureProvider<SettingsService>((
  Ref ref,
) async {
  return SettingsService.create();
});

/// WebDAV 配置服务 provider。
///
/// 与常规 SettingsService 分离，避免 WebDAV 凭据进入 ZIP 备份 payload。
final webDavSettingsServiceProvider = FutureProvider<WebDavSettingsService>((
  Ref ref,
) async {
  final service = await WebDavSettingsService.create();
  ref.onDispose(service.dispose);
  return service;
});

/// WebDAV 备份式同步服务 provider。
final webDavSyncServiceProvider = FutureProvider<WebDavSyncService>((
  Ref ref,
) async {
  final database = ref.watch(appDatabaseProvider);
  final settings = await ref.watch(settingsServiceProvider.future);
  final webDavSettings = await ref.watch(webDavSettingsServiceProvider.future);
  return WebDavSyncService(
    database: database,
    settingsService: settings,
    webDavSettingsService: webDavSettings,
  );
});

/// 应用更新检查服务 provider。
final appUpdateServiceProvider = Provider<AppUpdateService>((Ref ref) {
  return AppUpdateService();
});

/// 标签流 provider，供列表页/编辑页/设置页复用。
///
/// 保持单一数据源，避免多页面分别拉取导致状态不一致。
final tagListProvider = StreamProvider<List<Tag>>((Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return ref.watch(settingsServiceProvider.future).asStream().asyncExpand((
    settings,
  ) {
    return db.watchAllTags().map((tags) {
      final order = decodeTagOrder(settings.tagOrderRaw);
      return sortTagsByCustomOrder(tags, order);
    });
  });
});

/// 归档日记流 provider。
final archivedDiariesProvider = StreamProvider<List<DiaryWithTags>>((Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchArchivedDiaries();
});

/// 回收站日记流 provider（仅软删除记录）。
final deletedDiariesProvider = StreamProvider<List<DiaryWithTags>>((Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchDeletedDiaries();
});
