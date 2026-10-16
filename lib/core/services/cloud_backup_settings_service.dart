import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_backup_models.dart';
import 'cloud_backup_target.dart';

/// 网盘备份位置的持久化服务。
///
/// 职责边界：
/// - 所有备份位置存于单个 JSON 偏好键 `app.cloud_backup.targets`，经
///   [targetsNotifier] 通知界面；
/// - 与 SettingsService 分离：地址、密码与授权令牌不进入备份 ZIP（备份只导出
///   SettingsService 白名单内的键）；
/// - 首次启动时把旧版单一 WebDAV 配置（`app.webdav.*` 四个键）迁移为一个
///   WebDAV 备份位置，迁移成功后删除旧键；
/// - 写入串行执行：令牌刷新可能与界面保存同时发生，后写的必须基于先写的
///   结果，不能互相覆盖。
class CloudBackupSettingsService {
  CloudBackupSettingsService._(this._prefs, List<CloudBackupTarget> targets)
    : targetsNotifier = ValueNotifier<List<CloudBackupTarget>>(targets);

  static const _keyTargets = 'app.cloud_backup.targets';
  static const _legacyServerUrl = 'app.webdav.server_url';
  static const _legacyUsername = 'app.webdav.username';
  static const _legacyPassword = 'app.webdav.password';
  static const _legacyRemoteDirectory = 'app.webdav.remote_directory';

  final SharedPreferences _prefs;
  final ValueNotifier<List<CloudBackupTarget>> targetsNotifier;
  Future<void> _pending = Future<void>.value();

  static Future<CloudBackupSettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final service = CloudBackupSettingsService._(
      prefs,
      CloudBackupTarget.decodeList(prefs.getString(_keyTargets)),
    );
    await service._migrateLegacyWebDav();
    return service;
  }

  List<CloudBackupTarget> get targets => targetsNotifier.value;

  CloudBackupTarget? targetById(String id) {
    for (final target in targets) {
      if (target.id == id) return target;
    }
    return null;
  }

  /// 新增或按 id 替换一个备份位置，保持原有顺序。
  Future<void> saveTarget(CloudBackupTarget target) {
    return _serialized(() async {
      final next = <CloudBackupTarget>[];
      var replaced = false;
      for (final existing in targets) {
        if (existing.id == target.id) {
          next.add(target);
          replaced = true;
        } else {
          next.add(existing);
        }
      }
      if (!replaced) next.add(target);
      await _write(next);
    });
  }

  /// 只改写某个位置的配置；位置已被删除时什么都不做（例如删除后才返回的
  /// 令牌刷新结果）。
  Future<void> updateConfig(
    String id,
    Map<String, Object?> Function(Map<String, Object?> config) update,
  ) {
    return _serialized(() async {
      final next = [
        for (final target in targets)
          target.id == id
              ? target.copyWith(config: update(target.config))
              : target,
      ];
      await _write(next);
    });
  }

  Future<void> removeTarget(String id) {
    return _serialized(() async {
      await _write([
        for (final target in targets)
          if (target.id != id) target,
      ]);
    });
  }

  void dispose() {
    targetsNotifier.dispose();
  }

  Future<void> _serialized(Future<void> Function() action) {
    final run = _pending.then((_) => action());
    _pending = run.catchError((Object _) {});
    return run;
  }

  /// 先落盘再通知：写入失败（返回 false 或抛错）时界面保持旧列表。
  Future<void> _write(List<CloudBackupTarget> next) async {
    final ok = await _prefs.setString(
      _keyTargets,
      CloudBackupTarget.encodeList(next),
    );
    if (!ok) {
      throw StateError('failed to persist cloud backup targets');
    }
    targetsNotifier.value = List<CloudBackupTarget>.unmodifiable(next);
  }

  Future<void> _migrateLegacyWebDav() async {
    final serverUrl = _prefs.getString(_legacyServerUrl)?.trim() ?? '';
    if (serverUrl.isEmpty) return;
    final config = <String, Object?>{
      'serverUrl': serverUrl,
      'username': _prefs.getString(_legacyUsername) ?? '',
      'password': _prefs.getString(_legacyPassword) ?? '',
      'remoteDirectory': _prefs.getString(_legacyRemoteDirectory) ?? '/jotsy/',
    };
    // 已有同地址同账号的位置（上次迁移写入成功、删旧键失败）时不再重复添加。
    final exists = targets.any(
      (target) =>
          target.kind == CloudBackupKind.webDav &&
          target.config['serverUrl'] == config['serverUrl'] &&
          target.config['username'] == config['username'],
    );
    try {
      if (!exists) {
        await saveTarget(
          CloudBackupTarget.create(
            kind: CloudBackupKind.webDav,
            config: config,
          ),
        );
      }
      for (final key in const [
        _legacyServerUrl,
        _legacyUsername,
        _legacyPassword,
        _legacyRemoteDirectory,
      ]) {
        await _prefs.remove(key);
      }
    } catch (_) {
      // 迁移失败保留旧键，下次启动重试；不能因此让备份页无法打开。
    }
  }
}
