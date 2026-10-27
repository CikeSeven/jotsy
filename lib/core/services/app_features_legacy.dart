import '../database/app_database.dart';
import 'app_features.dart';
import 'settings_service.dart';

/// 纪念日改为默认关闭之前，功能管理从没改过的用户没有存过开关（当时全部
/// 开启不落盘）。升级后、或从这样的备份覆盖恢复后，没有这个键会按新的
/// 默认值把纪念日藏起来，已经建过纪念日的用户会以为数据丢了。
///
/// 这里只在设置里没有这个键、库里又有纪念日时写入“纪念日开启”（其余开关
/// 保持默认）。之后开关一律整份落盘（[AppFeatures.encode]），有了这个键就
/// 不再改动，用户自己关掉纪念日不会被重新打开；库里没有纪念日的用户沿用
/// 新默认值。冷启动时与导入备份（合并或覆盖）写库后各执行一次。
Future<void> keepLegacyAnniversariesVisible({
  required AppDatabase database,
  required SettingsService settings,
}) async {
  if (settings.appFeaturesRaw != null) return;
  if (!await database.hasAnniversaries()) return;
  await settings.setAppFeaturesRaw(
    AppFeatures.defaults.copyWith(anniversaries: true).encode(),
  );
}
