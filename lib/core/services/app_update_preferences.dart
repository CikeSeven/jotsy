import 'dart:convert';

import 'package:meta/meta.dart';

/// 应用更新的本机偏好，存为单个 JSON 设置键（`app.update.preferences`，
/// 见 `SettingsService.appUpdatePreferencesRaw`）。
///
/// 只描述这台设备：检查时间、跳过的版本与线路测速结果换台设备都不成立，
/// 所以**不随备份导出**。逐字段容错解析，坏掉的字段回落默认值而不影响其他字段。
@immutable
class AppUpdatePreferences {
  const AppUpdatePreferences({
    this.autoCheck = true,
    this.lastCheckedAt,
    this.skippedVersion,
    this.sourceId = autoSource,
    this.customMirror,
    this.lastGoodSourceId,
  });

  /// [sourceId] 取此值时自动选择线路（测速择优）。
  static const String autoSource = 'auto';

  /// 自动检查的最短间隔：冷启动或回到前台时，距上次检查不足这么久就不请求。
  /// 清单走 Release 附件下载（不占 GitHub 接口配额），一次只有几 KB。
  static const Duration autoCheckInterval = Duration(hours: 2);

  /// 冷启动与回到前台时自动检查（间隔见 [autoCheckInterval]）。默认开启：应用不经应用商店分发，
  /// 不自动检查的话多数人永远不知道有新版本；请求只读取公开的版本信息。
  final bool autoCheck;

  /// 上次成功完成检查（无论有无新版本）的时间。
  final DateTime? lastCheckedAt;

  /// 用户选择“跳过此版本”的版本号；自动检查不再提示它，手动检查照常显示。
  final String? skippedVersion;

  /// 下载线路：[autoSource] 或 `AppUpdateSource.id`。
  final String sourceId;

  /// 自定义镜像前缀；内置镜像都失效时由用户填写。
  final String? customMirror;

  /// 上次成功使用的线路，自动模式下排在最前面先试。
  final String? lastGoodSourceId;

  bool shouldAutoCheck(DateTime now) {
    final last = lastCheckedAt;
    return autoCheck &&
        (last == null ||
            now.difference(last) >= autoCheckInterval ||
            // 设备时间被往回调过：不让一次错误时间永久挡住检查。
            last.isAfter(now));
  }

  static AppUpdatePreferences decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const AppUpdatePreferences();
    }
    Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return const AppUpdatePreferences();
    }
    if (json is! Map) {
      return const AppUpdatePreferences();
    }
    final map = json;
    String? text(String key) {
      final value = map[key];
      return value is String && value.trim().isNotEmpty ? value.trim() : null;
    }

    final autoCheck = map['autoCheck'];
    final lastCheckedAt = text('lastCheckedAt');
    return AppUpdatePreferences(
      autoCheck: autoCheck is bool ? autoCheck : true,
      // 以 UTC 存储，读回本地时间：与 DateTime.now() 比较、相等判断都一致。
      lastCheckedAt: lastCheckedAt == null
          ? null
          : DateTime.tryParse(lastCheckedAt)?.toLocal(),
      skippedVersion: text('skippedVersion'),
      sourceId: text('sourceId') ?? autoSource,
      customMirror: text('customMirror'),
      lastGoodSourceId: text('lastGoodSourceId'),
    );
  }

  String encode() {
    return jsonEncode(<String, Object?>{
      'autoCheck': autoCheck,
      if (lastCheckedAt != null)
        'lastCheckedAt': lastCheckedAt!.toUtc().toIso8601String(),
      'skippedVersion': ?skippedVersion,
      'sourceId': sourceId,
      'customMirror': ?customMirror,
      'lastGoodSourceId': ?lastGoodSourceId,
    });
  }

  AppUpdatePreferences copyWith({
    bool? autoCheck,
    DateTime? lastCheckedAt,
    String? Function()? skippedVersion,
    String? sourceId,
    String? Function()? customMirror,
    String? lastGoodSourceId,
  }) {
    return AppUpdatePreferences(
      autoCheck: autoCheck ?? this.autoCheck,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      skippedVersion: skippedVersion == null
          ? this.skippedVersion
          : skippedVersion(),
      sourceId: sourceId ?? this.sourceId,
      customMirror: customMirror == null ? this.customMirror : customMirror(),
      lastGoodSourceId: lastGoodSourceId ?? this.lastGoodSourceId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppUpdatePreferences &&
      other.autoCheck == autoCheck &&
      other.lastCheckedAt == lastCheckedAt &&
      other.skippedVersion == skippedVersion &&
      other.sourceId == sourceId &&
      other.customMirror == customMirror &&
      other.lastGoodSourceId == lastGoodSourceId;

  @override
  int get hashCode => Object.hash(
    autoCheck,
    lastCheckedAt,
    skippedVersion,
    sourceId,
    customMirror,
    lastGoodSourceId,
  );
}
