import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_models.dart';
import 'ai_provider_config.dart';
import 'ai_usage_ledger.dart';

/// AI 的本机配置与用量账本。
///
/// 职责边界：
/// - 服务商（含 API 密钥）、任务路由、已确认的发送目标存于单个 JSON 偏好键
///   `app.ai.providers`，用量账本存于 `app.ai.usage`；两者都**只存本机**：
///   与 SettingsService 分离，不进备份白名单（`BackupSettings.capture`），
///   也不参与局域网同步——密钥不能随备份文件或同步离开这台设备；
/// - 写入串行执行：生成结束时记账可能与界面保存同时发生，后写的必须基于
///   先写的结果；
/// - 先落盘再通知：写入失败时界面保持旧值。
class AiProviderStore {
  AiProviderStore._(this._prefs, AiLocalConfig config, AiUsageLedger usage)
    : configNotifier = ValueNotifier<AiLocalConfig>(config),
      usageNotifier = ValueNotifier<AiUsageLedger>(usage);

  static const String keyConfig = 'app.ai.providers';
  static const String keyUsage = 'app.ai.usage';

  final SharedPreferences _prefs;
  final ValueNotifier<AiLocalConfig> configNotifier;
  final ValueNotifier<AiUsageLedger> usageNotifier;
  Future<void> _pending = Future<void>.value();

  static Future<AiProviderStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AiProviderStore._(
      prefs,
      AiLocalConfig.decode(prefs.getString(keyConfig)),
      AiUsageLedger.decode(prefs.getString(keyUsage)),
    );
  }

  AiLocalConfig get config => configNotifier.value;

  AiUsageLedger get usage => usageNotifier.value;

  /// 在最新配置上执行一次修改并落盘。
  Future<void> update(AiLocalConfig Function(AiLocalConfig current) change) {
    return _serialized(() async {
      final next = change(config);
      if (next == config) return;
      final ok = await _prefs.setString(keyConfig, next.encode());
      if (!ok) throw StateError('failed to persist AI providers');
      configNotifier.value = next;
    });
  }

  /// 新增或按 id 替换一个服务商，保持原有顺序。
  Future<void> saveProvider(AiProviderConfig provider) {
    return update((current) {
      final providers = [...current.providers];
      final index = providers.indexWhere((item) => item.id == provider.id);
      if (index < 0) {
        providers.add(provider);
      } else {
        providers[index] = provider;
      }
      return current.copyWith(providers: providers);
    });
  }

  Future<void> removeProvider(String id) =>
      update((current) => current.withoutProvider(id));

  Future<void> reorderProviders(List<String> orderedIds) {
    return update((current) {
      final byId = {
        for (final provider in current.providers) provider.id: provider,
      };
      final ordered = <AiProviderConfig>[
        for (final id in orderedIds)
          if (byId.remove(id) case final provider?) provider,
        ...byId.values,
      ];
      return current.copyWith(providers: ordered);
    });
  }

  Future<void> acknowledgeHost(String host) {
    return update(
      (current) => current.copyWith(
        acknowledgedHosts: {...current.acknowledgedHosts, host},
      ),
    );
  }

  /// 记一次请求（成功或失败）。记账失败不影响生成本身。
  Future<void> recordUsage({
    required AiResolvedModel model,
    required bool failed,
    AiUsage? usage,
    DateTime? at,
  }) {
    return _serialized(() async {
      final next = this.usage.record(
        at: at ?? DateTime.now(),
        providerId: model.provider.id,
        providerName: model.provider.name,
        model: model.model.id,
        failed: failed,
        usage: usage,
      );
      final ok = await _prefs.setString(keyUsage, next.encode());
      if (!ok) return;
      usageNotifier.value = next;
    });
  }

  Future<void> clearUsage() {
    return _serialized(() async {
      await _prefs.remove(keyUsage);
      usageNotifier.value = AiUsageLedger.empty;
    });
  }

  void dispose() {
    configNotifier.dispose();
    usageNotifier.dispose();
  }

  Future<void> _serialized(Future<void> Function() action) {
    final run = _pending.then((_) => action());
    _pending = run.catchError((Object _) {});
    return run;
  }
}
