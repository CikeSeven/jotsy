import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'amap_config_channel.dart';
import 'app_update_service.dart';
import 'cloud_backup_service.dart';
import 'cloud_backup_settings_service.dart';
import 'diary_font_storage_service.dart';
import 'diary_media_cleanup_service.dart';
import 'location_resolver_service.dart';
import 'qweather_weather_service.dart';
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

/// 导入的正文字体存储服务；单例保证导入与删除串行写清单。
final diaryFontStorageServiceProvider = Provider<DiaryFontStorageService>(
  (Ref ref) => DiaryFontStorageService(),
);

/// 日记媒体回收服务；随容器销毁取消尚未触发的启动回收。
final diaryMediaCleanupServiceProvider = Provider<DiaryMediaCleanupService>((
  Ref ref,
) {
  final service = DiaryMediaCleanupService(
    database: ref.watch(appDatabaseProvider),
    settings: () => ref.read(settingsServiceProvider.future),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// 自动定位服务；高德 Web 服务 key 由原生层注入（见 [AMapConfigChannel]），
/// 未配置或非 Android 平台时为 null。key 是构建期配置，进程内只读一次。
/// 测试可覆盖为假服务，不必再模拟平台通道与网络。
final locationResolverServiceProvider =
    FutureProvider<LocationResolverService?>((Ref ref) async {
      final apiKey = await AMapConfigChannel.getAmapWebApiKey();
      if (apiKey == null || apiKey.isEmpty) {
        return null;
      }
      return LocationResolverService(webApiKey: apiKey);
    });

/// 和风天气服务；未配置 key 时为 null，其余同 [locationResolverServiceProvider]。
final weatherServiceProvider = FutureProvider<QWeatherWeatherService?>((
  Ref ref,
) async {
  final apiKey = await AMapConfigChannel.getQWeatherApiKey();
  if (apiKey == null || apiKey.trim().isEmpty) {
    return null;
  }
  return QWeatherWeatherService(
    config: QWeatherConfig(
      apiKey: apiKey,
      credentialId: await AMapConfigChannel.getQWeatherCredentialId(),
      apiHost: await AMapConfigChannel.getQWeatherApiHost(),
    ),
  );
});

/// 当前心情符号配置 provider。
///
/// SettingsService 通过 ValueNotifier 暴露局部设置变化，这里桥接成 Riverpod
/// StreamProvider，让发布/编辑面板、日历和探索页能在用户保存配置后即时刷新。
final moodOptionsProvider = StreamProvider<List<String>>((Ref ref) async* {
  final settings = await ref.watch(settingsServiceProvider.future);
  yield settings.moodOptions;

  final controller = StreamController<List<String>>();
  void listener() {
    controller.add(settings.moodOptions);
  }

  settings.moodOptionsRawNotifier.addListener(listener);
  ref.onDispose(() {
    settings.moodOptionsRawNotifier.removeListener(listener);
    unawaited(controller.close());
  });

  yield* controller.stream;
});

/// 日记卡片展示的标签数量上限 provider。
///
/// 将 SettingsService 的 ValueNotifier 桥接为 Riverpod StreamProvider，确保设置
/// 变更后所有日记列表能即时刷新。
final diaryCardTagLimitProvider = StreamProvider<int>((Ref ref) async* {
  final settings = await ref.watch(settingsServiceProvider.future);
  final initialValue = settings.diaryCardTagLimit;
  final controller = StreamController<int>();
  void listener() {
    controller.add(settings.diaryCardTagLimit);
  }

  settings.diaryCardTagLimitNotifier.addListener(listener);
  ref.onDispose(() {
    settings.diaryCardTagLimitNotifier.removeListener(listener);
    unawaited(controller.close());
  });

  yield initialValue;
  yield* controller.stream;
});

/// 网盘备份位置的配置服务 provider。
///
/// 与常规 SettingsService 分离，避免地址、密码与授权令牌进入 ZIP 备份 payload。
final cloudBackupSettingsServiceProvider =
    FutureProvider<CloudBackupSettingsService>((Ref ref) async {
      final service = await CloudBackupSettingsService.create();
      ref.onDispose(service.dispose);
      return service;
    });

/// 网盘备份编排服务 provider。
final cloudBackupServiceProvider = FutureProvider<CloudBackupService>((
  Ref ref,
) async {
  final database = ref.watch(appDatabaseProvider);
  final settings = await ref.watch(settingsServiceProvider.future);
  final targets = await ref.watch(cloudBackupSettingsServiceProvider.future);
  return CloudBackupService(
    database: database,
    settingsService: settings,
    targets: targets,
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
