// `store.json` 里的数据类型：偏好与已配对设备（docs/lan_sync.md §3；同步
// 记录见 lan_sync_session_record.dart）。
//
// 纯数据，无副作用：不可变、按值比较，JSON 读写逐字段容错——单个字段类型
// 不对只让这个字段回到默认值，缺了身份必需字段（deviceId、公钥）的配对设备
// 整条丢弃（没有公钥就无法认证，留着也同步不了）。时间一律存 UTC 毫秒。
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'lan_sync_crypto.dart';

/// 本机偏好（同步页的开关与设备名）。
@immutable
class LanSyncPrefs {
  const LanSyncPrefs({
    this.deviceName,
    this.discoverable = true,
    this.autoSync = true,
    this.syncSettings = false,
  });

  factory LanSyncPrefs.fromJson(Object? json) {
    final map = json is Map ? json : const <String, Object?>{};
    final name = map['deviceName'];
    return LanSyncPrefs(
      deviceName: name is String && name.trim().isNotEmpty ? name : null,
      discoverable: _bool(map['discoverable'], true),
      autoSync: _bool(map['autoSync'], true),
      syncSettings: _bool(map['syncSettings'], false),
    );
  }

  /// 用户起的设备名；null 表示没改过，用系统默认名。
  final String? deviceName;

  /// 是否广播信标、允许附近的设备发现本机。
  final bool discoverable;

  /// 全局“自动同步”开关（前台时与已配对设备自动同步）。
  final bool autoSync;

  /// “同步设置”：两端都开启时设置才参与同步。
  final bool syncSettings;

  LanSyncPrefs copyWith({
    String? Function()? deviceName,
    bool? discoverable,
    bool? autoSync,
    bool? syncSettings,
  }) => LanSyncPrefs(
    deviceName: deviceName == null ? this.deviceName : deviceName(),
    discoverable: discoverable ?? this.discoverable,
    autoSync: autoSync ?? this.autoSync,
    syncSettings: syncSettings ?? this.syncSettings,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'deviceName': deviceName,
    'discoverable': discoverable,
    'autoSync': autoSync,
    'syncSettings': syncSettings,
  };

  @override
  bool operator ==(Object other) =>
      other is LanSyncPrefs &&
      other.deviceName == deviceName &&
      other.discoverable == discoverable &&
      other.autoSync == autoSync &&
      other.syncSettings == syncSettings;

  @override
  int get hashCode =>
      Object.hash(deviceName, discoverable, autoSync, syncSettings);
}

/// 一台已配对的设备。
@immutable
class LanSyncPairedDevice {
  LanSyncPairedDevice({
    required this.deviceId,
    required this.name,
    required this.platform,
    required List<int> publicKey,
    required this.pairedAt,
    this.lastSyncAt,
    this.lastHost,
    this.lastPort,
    this.autoSync = true,
    this.alias,
    this.needsAttention = false,
    this.restoredPending = false,
  }) : publicKey = List<int>.unmodifiable(publicKey);

  /// 解析一条；缺 deviceId 或公钥不是 32 字节时为 null（整条丢弃）。
  static LanSyncPairedDevice? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['deviceId'];
    final key = json['publicKey'];
    if (id is! String || id.isEmpty || key is! String) return null;
    final List<int> publicKey;
    try {
      publicKey = base64.decode(key);
    } on FormatException {
      return null;
    }
    if (publicKey.length != 32) return null;
    final name = json['name'];
    final platform = json['platform'];
    final port = json['lastPort'];
    final host = json['lastHost'];
    final alias = json['alias'];
    return LanSyncPairedDevice(
      deviceId: id,
      name: name is String && name.isNotEmpty ? name : id,
      platform: platform is String ? platform : 'unknown',
      publicKey: publicKey,
      pairedAt: _time(json['pairedAt']) ?? DateTime.utc(1970),
      lastSyncAt: _time(json['lastSyncAt']),
      lastHost: host is String && host.isNotEmpty ? host : null,
      lastPort: port is int && port > 0 && port < 65536 ? port : null,
      autoSync: _bool(json['autoSync'], true),
      alias: alias is String && alias.trim().isNotEmpty ? alias : null,
      needsAttention: _bool(json['needsAttention'], false),
      restoredPending: _bool(json['restoredPending'], false),
    );
  }

  final String deviceId;

  /// 对方自己起的名字（握手与信标里的最新值）。
  final String name;

  /// 平台标识（`android` / `linux` / `windows` / `macos` …）。
  final String platform;

  /// 对方的 Ed25519 身份公钥（32 字节）。
  final List<int> publicKey;
  final DateTime pairedAt;

  /// 上次成功同步的时间；从没同步过为 null（下次同步是“首次同步”）。
  final DateTime? lastSyncAt;

  /// 上次连上它的地址与端口（离线时“立即同步”用它）。
  final String? lastHost;
  final int? lastPort;

  /// 单设备的自动同步开关。
  final bool autoSync;

  /// 本机给它起的备注名。
  final String? alias;

  /// 自动同步遇到需要确认的情况、还没处理（同步页显示“查看”）。
  final bool needsAttention;

  /// 本机做过覆盖恢复之后还没和它成功同步过：下次同步按“以哪边为准”处理。
  final bool restoredPending;

  String get fingerprint => lanSyncFingerprint(publicKey);

  /// deviceId 与公钥都一致才算同一台已配对设备。
  bool matches(String id, List<int> key) =>
      id == deviceId && lanSyncBytesEqual(key, publicKey);

  LanSyncPairedDevice copyWith({
    String? name,
    String? platform,
    List<int>? publicKey,
    DateTime? pairedAt,
    DateTime? Function()? lastSyncAt,
    String? Function()? lastHost,
    int? Function()? lastPort,
    bool? autoSync,
    String? Function()? alias,
    bool? needsAttention,
    bool? restoredPending,
  }) => LanSyncPairedDevice(
    deviceId: deviceId,
    name: name ?? this.name,
    platform: platform ?? this.platform,
    publicKey: publicKey ?? this.publicKey,
    pairedAt: pairedAt ?? this.pairedAt,
    lastSyncAt: lastSyncAt == null ? this.lastSyncAt : lastSyncAt(),
    lastHost: lastHost == null ? this.lastHost : lastHost(),
    lastPort: lastPort == null ? this.lastPort : lastPort(),
    autoSync: autoSync ?? this.autoSync,
    alias: alias == null ? this.alias : alias(),
    needsAttention: needsAttention ?? this.needsAttention,
    restoredPending: restoredPending ?? this.restoredPending,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'deviceId': deviceId,
    'name': name,
    'platform': platform,
    'publicKey': base64.encode(publicKey),
    'pairedAt': pairedAt.millisecondsSinceEpoch,
    'lastSyncAt': lastSyncAt?.millisecondsSinceEpoch,
    'lastHost': lastHost,
    'lastPort': lastPort,
    'autoSync': autoSync,
    'alias': alias,
    'needsAttention': needsAttention,
    'restoredPending': restoredPending,
  };

  @override
  bool operator ==(Object other) =>
      other is LanSyncPairedDevice &&
      other.deviceId == deviceId &&
      other.name == name &&
      other.platform == platform &&
      listEquals(other.publicKey, publicKey) &&
      other.pairedAt == pairedAt &&
      other.lastSyncAt == lastSyncAt &&
      other.lastHost == lastHost &&
      other.lastPort == lastPort &&
      other.autoSync == autoSync &&
      other.alias == alias &&
      other.needsAttention == needsAttention &&
      other.restoredPending == restoredPending;

  @override
  int get hashCode => Object.hash(
    deviceId,
    name,
    platform,
    Object.hashAll(publicKey),
    pairedAt,
    lastSyncAt,
    lastHost,
    lastPort,
    autoSync,
    alias,
    needsAttention,
    restoredPending,
  );
}

bool _bool(Object? value, bool fallback) => value is bool ? value : fallback;

DateTime? _time(Object? value) => value is int && value >= 0
    ? DateTime.fromMillisecondsSinceEpoch(value, isUtc: true)
    : null;
