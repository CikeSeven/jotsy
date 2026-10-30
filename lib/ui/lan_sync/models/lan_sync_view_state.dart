// 局域网同步页的整页视图状态（不可变、按值比较）。
//
// 由同步控制器（`LanSyncUiController.state`）给出，页面、设置入口副标题与
// 设备详情页只读它，不自行推算在线、配对或会话状态。

import 'package:flutter/foundation.dart';

import 'lan_sync_platform.dart';
import 'lan_sync_session_view.dart';

/// 本机：英雄卡的设备名、平台、地址与发现状态。
@immutable
class LanSyncLocalDeviceView {
  const LanSyncLocalDeviceView({
    required this.name,
    required this.platform,
    this.addresses = const <String>[],
    this.port,
    this.discoverable = true,
    this.discoveryListening = true,
  });

  /// 用户起的设备名；空串表示还没取到（界面显示默认名）。
  final String name;
  final LanSyncPlatform platform;

  /// 本机的局域网地址（私有 IPv4，优先 Wi-Fi / 以太网，见 docs §5.1）；
  /// 第一项显示在英雄卡上。为空表示没有连上局域网。
  final List<String> addresses;

  /// 同步服务实际监听的 TCP 端口；服务没起来时为 null。
  final int? port;

  /// 是否广播自己、允许附近的设备发现（用户开关）。
  final bool discoverable;

  /// 发现端口是否绑定成功；false 表示被其他程序占用，排障面板顶部说明。
  final bool discoveryListening;

  /// 本机的首选地址；没有地址时为 null。
  String? get primaryAddress => addresses.isEmpty ? null : addresses.first;

  /// 英雄卡上显示的地址：实际端口不是默认端口时（默认端口被占用、服务端
  /// 退到了别的端口）写成 `ip:port`，否则只写 ip——别人照着输入时，端口框
  /// 的默认值就对。没有地址时为 null。
  String? get displayAddress {
    final address = primaryAddress;
    final port = this.port;
    if (address == null) return null;
    if (port == null || port == LanSyncPorts.preferredSync) return address;
    return '$address:$port';
  }

  LanSyncLocalDeviceView copyWith({
    String? name,
    LanSyncPlatform? platform,
    List<String>? addresses,
    int? port,
    bool? discoverable,
    bool? discoveryListening,
  }) {
    return LanSyncLocalDeviceView(
      name: name ?? this.name,
      platform: platform ?? this.platform,
      addresses: addresses ?? this.addresses,
      port: port ?? this.port,
      discoverable: discoverable ?? this.discoverable,
      discoveryListening: discoveryListening ?? this.discoveryListening,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LanSyncLocalDeviceView &&
      other.name == name &&
      other.platform == platform &&
      listEquals(other.addresses, addresses) &&
      other.port == port &&
      other.discoverable == discoverable &&
      other.discoveryListening == discoveryListening;

  @override
  int get hashCode => Object.hash(
    name,
    platform,
    Object.hashAll(addresses),
    port,
    discoverable,
    discoveryListening,
  );
}

/// 一台已配对的设备。
@immutable
class LanSyncPeerView {
  const LanSyncPeerView({
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.pairedAt,
    this.alias,
    this.online = false,
    this.address,
    this.lastAddressKnown = false,
    this.lastSyncAt,
    this.autoSync = true,
    this.needsAttention = false,
    this.session,
    this.history = const <LanSyncHistoryEntryView>[],
  });

  final String deviceId;

  /// 对方自己起的设备名（信标与握手里带来的最新值）。
  final String name;

  /// 本机给它起的备注名（只在本机显示）；null 表示没有。
  final String? alias;
  final LanSyncPlatform platform;

  /// 现在是否在线（最近收到过它的信标）。
  final bool online;

  /// 在线时的地址；离线时可能是上次见到的地址或 null。
  final String? address;

  /// 知道上次连上它的地址与端口：离线时仍可手动同步（按上次的地址连接）。
  final bool lastAddressKnown;
  final DateTime pairedAt;

  /// 上次成功同步的时间；从没同步过为 null。
  final DateTime? lastSyncAt;

  /// 这台设备是否参与自动同步（单设备开关，全局自动同步关闭时不生效）。
  final bool autoSync;

  /// 有一次同步等待用户确认（以哪边为准 / 删除保护），见
  /// `LanSyncUiController.reviewPendingConfirmation`。
  final bool needsAttention;

  /// 正在进行的同步会话；没有时为 null。
  final LanSyncSessionView? session;

  /// 同步记录，新的在前（设备详情页最多显示 20 条）。
  final List<LanSyncHistoryEntryView> history;

  /// 能不能点“同步”：在线，或离线但知道上次的地址。
  bool get canSync => online || lastAddressKnown;

  /// 界面上显示的名称：本机备注名优先，空白备注按没有处理。
  String get displayName {
    final trimmed = alias?.trim();
    return trimmed == null || trimmed.isEmpty ? name : trimmed;
  }

  LanSyncPeerView copyWith({
    String? name,
    String? Function()? alias,
    LanSyncPlatform? platform,
    bool? online,
    String? Function()? address,
    bool? lastAddressKnown,
    DateTime? pairedAt,
    DateTime? Function()? lastSyncAt,
    bool? autoSync,
    bool? needsAttention,
    LanSyncSessionView? Function()? session,
    List<LanSyncHistoryEntryView>? history,
  }) {
    return LanSyncPeerView(
      deviceId: deviceId,
      name: name ?? this.name,
      alias: alias == null ? this.alias : alias(),
      platform: platform ?? this.platform,
      online: online ?? this.online,
      address: address == null ? this.address : address(),
      lastAddressKnown: lastAddressKnown ?? this.lastAddressKnown,
      pairedAt: pairedAt ?? this.pairedAt,
      lastSyncAt: lastSyncAt == null ? this.lastSyncAt : lastSyncAt(),
      autoSync: autoSync ?? this.autoSync,
      needsAttention: needsAttention ?? this.needsAttention,
      session: session == null ? this.session : session(),
      history: history ?? this.history,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LanSyncPeerView &&
      other.deviceId == deviceId &&
      other.name == name &&
      other.alias == alias &&
      other.platform == platform &&
      other.online == online &&
      other.address == address &&
      other.lastAddressKnown == lastAddressKnown &&
      other.pairedAt == pairedAt &&
      other.lastSyncAt == lastSyncAt &&
      other.autoSync == autoSync &&
      other.needsAttention == needsAttention &&
      other.session == session &&
      listEquals(other.history, history);

  @override
  int get hashCode => Object.hash(
    deviceId,
    name,
    alias,
    platform,
    online,
    address,
    lastAddressKnown,
    pairedAt,
    lastSyncAt,
    autoSync,
    needsAttention,
    session,
    Object.hashAll(history),
  );
}

/// 附近发现的、还没配对的设备。
@immutable
class LanSyncNearbyView {
  const LanSyncNearbyView({
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.address,
  });

  final String deviceId;
  final String name;
  final LanSyncPlatform platform;
  final String address;

  @override
  bool operator ==(Object other) =>
      other is LanSyncNearbyView &&
      other.deviceId == deviceId &&
      other.name == name &&
      other.platform == platform &&
      other.address == address;

  @override
  int get hashCode => Object.hash(deviceId, name, platform, address);
}

/// 同步页的整页状态。
@immutable
class LanSyncViewState {
  const LanSyncViewState({
    required this.local,
    this.peers = const <LanSyncPeerView>[],
    this.nearby = const <LanSyncNearbyView>[],
    this.autoSyncEnabled = true,
    this.syncSettingsEnabled = false,
    this.searching = false,
  });

  final LanSyncLocalDeviceView local;

  /// 已配对的设备，按控制器给出的顺序显示。
  final List<LanSyncPeerView> peers;

  /// 附近发现、还没配对的设备（不含已配对的）。
  final List<LanSyncNearbyView> nearby;

  /// 全局“自动同步”开关。
  final bool autoSyncEnabled;

  /// “同步设置”开关（两端都开启才同步设置，docs §0）。
  final bool syncSettingsEnabled;

  /// 是否正在发现附近的设备（同步页打开且发现在运行）。
  final bool searching;

  /// 是否有设备正在同步：英雄卡据此收成一行。
  bool get hasActiveSession => peers.any((peer) => peer.session != null);

  /// 是否有同步在等用户确认：设置入口副标题据此换成提示。
  bool get needsAttention => peers.any((peer) => peer.needsAttention);

  /// 所有已配对设备里最近一次同步的时间；都没同步过为 null。
  DateTime? get lastSyncAt {
    DateTime? latest;
    for (final peer in peers) {
      final at = peer.lastSyncAt;
      if (at != null && (latest == null || at.isAfter(latest))) latest = at;
    }
    return latest;
  }

  LanSyncViewState copyWith({
    LanSyncLocalDeviceView? local,
    List<LanSyncPeerView>? peers,
    List<LanSyncNearbyView>? nearby,
    bool? autoSyncEnabled,
    bool? syncSettingsEnabled,
    bool? searching,
  }) {
    return LanSyncViewState(
      local: local ?? this.local,
      peers: peers ?? this.peers,
      nearby: nearby ?? this.nearby,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      syncSettingsEnabled: syncSettingsEnabled ?? this.syncSettingsEnabled,
      searching: searching ?? this.searching,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LanSyncViewState &&
      other.local == local &&
      listEquals(other.peers, peers) &&
      listEquals(other.nearby, nearby) &&
      other.autoSyncEnabled == autoSyncEnabled &&
      other.syncSettingsEnabled == syncSettingsEnabled &&
      other.searching == searching;

  @override
  int get hashCode => Object.hash(
    local,
    Object.hashAll(peers),
    Object.hashAll(nearby),
    autoSyncEnabled,
    syncSettingsEnabled,
    searching,
  );
}
