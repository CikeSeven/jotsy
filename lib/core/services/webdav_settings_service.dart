import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'webdav_models.dart';

/// WebDAV 配置持久化服务。
///
/// 职责边界：
/// - 仅保存/读取 WebDAV 连接配置，并通过 ValueNotifier 通知 UI 刷新；
/// - 不参与 ZIP 备份 payload，避免服务器地址和凭据被导出到远程备份；
/// - 不执行网络请求，连接测试交给 WebDavSyncService。
class WebDavSettingsService {
  WebDavSettingsService._({
    required SharedPreferences prefs,
    required WebDavConfig config,
  }) : _prefs = prefs,
       configNotifier = ValueNotifier<WebDavConfig>(config);

  static const _keyServerUrl = 'app.webdav.server_url';
  static const _keyUsername = 'app.webdav.username';
  static const _keyPassword = 'app.webdav.password';
  static const _keyRemoteDirectory = 'app.webdav.remote_directory';

  final SharedPreferences _prefs;
  final ValueNotifier<WebDavConfig> configNotifier;

  static Future<WebDavSettingsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return WebDavSettingsService._(prefs: prefs, config: _readConfig(prefs));
  }

  WebDavConfig get config => configNotifier.value;

  Future<void> saveConfig(WebDavConfig config) async {
    final normalized = config.validate();
    await _prefs.setString(_keyServerUrl, normalized.baseUri.toString());
    await _prefs.setString(_keyUsername, normalized.normalizedUsername);
    await _prefs.setString(_keyPassword, normalized.password);
    await _prefs.setString(
      _keyRemoteDirectory,
      normalized.normalizedRemoteDirectory,
    );
    configNotifier.value = normalized.copyWith(
      serverUrl: normalized.baseUri.toString(),
      username: normalized.normalizedUsername,
      remoteDirectory: normalized.normalizedRemoteDirectory,
    );
  }

  Future<void> clearConfig() async {
    await _prefs.remove(_keyServerUrl);
    await _prefs.remove(_keyUsername);
    await _prefs.remove(_keyPassword);
    await _prefs.remove(_keyRemoteDirectory);
    configNotifier.value = WebDavConfig.empty();
  }

  void dispose() {
    configNotifier.dispose();
  }

  static WebDavConfig _readConfig(SharedPreferences prefs) {
    return WebDavConfig(
      serverUrl: prefs.getString(_keyServerUrl) ?? '',
      username: prefs.getString(_keyUsername) ?? '',
      password: prefs.getString(_keyPassword) ?? '',
      remoteDirectory: prefs.getString(_keyRemoteDirectory) ?? '/jotsy/',
    );
  }
}
