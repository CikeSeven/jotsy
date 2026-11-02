import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/ai/ai_provider_config.dart';
import '../../../core/services/ai/ai_provider_store.dart';
import '../../../core/services/ai/ai_service.dart';
import '../../../core/services/ai/ai_usage_ledger.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../settings/providers/app_features_provider.dart';
import '../models/ai_preference_parts.dart';
import '../models/ai_preferences.dart';

/// AI 本机配置服务（服务商、密钥、路由、用量）。与 SettingsService 分离，
/// 内容不进备份、不同步。
final aiProviderStoreProvider = FutureProvider<AiProviderStore>((
  Ref ref,
) async {
  final store = await AiProviderStore.create();
  ref.onDispose(store.dispose);
  return store;
});

/// 服务商与任务路由。同步 Notifier：存储未就绪时为空配置（入口暂不出现），
/// 就绪后跟随 [AiProviderStore.configNotifier]。
final aiLocalConfigProvider =
    NotifierProvider<AiLocalConfigNotifier, AiLocalConfig>(
      AiLocalConfigNotifier.new,
    );

class AiLocalConfigNotifier extends Notifier<AiLocalConfig> {
  @override
  AiLocalConfig build() {
    final store = ref.watch(aiProviderStoreProvider).asData?.value;
    if (store == null) return AiLocalConfig.empty;
    final notifier = store.configNotifier;
    void listener() => state = notifier.value;
    notifier.addListener(listener);
    ref.onDispose(() => notifier.removeListener(listener));
    return notifier.value;
  }
}

/// 本机用量账本。
final aiUsageProvider = NotifierProvider<AiUsageNotifier, AiUsageLedger>(
  AiUsageNotifier.new,
);

class AiUsageNotifier extends Notifier<AiUsageLedger> {
  @override
  AiUsageLedger build() {
    final store = ref.watch(aiProviderStoreProvider).asData?.value;
    if (store == null) return AiUsageLedger.empty;
    final notifier = store.usageNotifier;
    void listener() => state = notifier.value;
    notifier.addListener(listener);
    ref.onDispose(() => notifier.removeListener(listener));
    return notifier.value;
  }
}

/// AI 偏好。同步 Notifier：settings 未就绪时给默认值；设置页写入、备份恢复
/// 与失败回滚都会改写 raw notifier，这里监听并按 `==` 去重。
final aiPreferencesProvider =
    NotifierProvider<AiPreferencesNotifier, AiPreferences>(
      AiPreferencesNotifier.new,
    );

class AiPreferencesNotifier extends Notifier<AiPreferences> {
  @override
  AiPreferences build() {
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) return AiPreferences.defaults;
    final rawNotifier = settings.aiPrefsRawNotifier;
    void listener() {
      final next = AiPreferences.decode(rawNotifier.value);
      if (next != state) state = next;
    }

    rawNotifier.addListener(listener);
    ref.onDispose(() => rawNotifier.removeListener(listener));
    return AiPreferences.decode(rawNotifier.value);
  }
}

/// 持久化 AI 偏好；与默认完全相同时移除设置键。
Future<void> saveAiPreferences(
  SettingsService settings,
  AiPreferences preferences,
) {
  return settings.setAiPrefsRaw(preferences.encode());
}

/// 在最新的偏好上执行一次修改并保存（设置页各项共用）。设置服务的 raw
/// notifier 在写入前就同步更新，所以连续两次修改不会互相覆盖。
Future<void> updateAiPreferences(
  WidgetRef ref,
  AiPreferences Function(AiPreferences current) change,
) async {
  final settings = await ref.read(settingsServiceProvider.future);
  await saveAiPreferences(settings, change(ref.read(aiPreferencesProvider)));
}

/// 在最新的本机配置上执行一次修改并保存。
Future<void> updateAiLocalConfig(
  WidgetRef ref,
  AiLocalConfig Function(AiLocalConfig current) change,
) async {
  final store = await ref.read(aiProviderStoreProvider.future);
  await store.update(change);
}

/// 功能管理里的 AI 助手开关（决定设置首页的“AI 助手”入口）。
final aiFeatureEnabledProvider = Provider<bool>(
  (Ref ref) => ref.watch(appFeaturesProvider.select((f) => f.ai)),
);

/// AI 可以用：开关打开，且至少配好了一个可用的服务商与模型。
///
/// **所有功能入口只看它**（再叠加各自模块的开关）：没配好服务商时，开关
/// 打开也不在编辑器、预览页等处放一堆点了只会报错的按钮，用户先去设置里
/// 配好即可。
final aiAvailableProvider = Provider<bool>((Ref ref) {
  if (!ref.watch(aiFeatureEnabledProvider)) return false;
  return ref.watch(aiLocalConfigProvider.select((config) => config.isReady));
});

/// 某个模块的入口是否出现：AI 可用且该模块开启。
final aiModuleAvailableProvider = Provider.family<bool, AiModule>((
  Ref ref,
  AiModule module,
) {
  if (!ref.watch(aiAvailableProvider)) return false;
  return ref.watch(
    aiPreferencesProvider.select((prefs) => prefs.isModuleEnabled(module)),
  );
});

/// AI 请求编排服务。
final aiServiceProvider = FutureProvider<AiService>((Ref ref) async {
  final store = await ref.watch(aiProviderStoreProvider.future);
  return AiService(store: store);
});

/// AI 助手主页的入口（日记 Tab 顶栏、探索卡片、AI 设置页）是否出现：对话
/// 或回顾至少有一个可用。
final aiHubAvailableProvider = Provider<bool>(
  (Ref ref) =>
      ref.watch(aiModuleAvailableProvider(AiModule.chat)) ||
      ref.watch(aiModuleAvailableProvider(AiModule.recap)),
);
