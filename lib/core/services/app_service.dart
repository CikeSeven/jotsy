import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'settings_service.dart';
import 'tag_order_codec.dart';

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

/// 标签流 provider，供列表页/编辑页/设置页复用。
///
/// 保持单一数据源，避免多页面分别拉取导致状态不一致。
final tagListProvider = StreamProvider<List<Tag>>((Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return ref.watch(settingsServiceProvider.future).asStream().asyncExpand((settings) {
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
