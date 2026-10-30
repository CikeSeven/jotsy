// 服务对外的状态快照、配对句柄与事件（lan_sync_service.dart 的一部分）。
part of 'lan_sync_service.dart';

/// 本机（英雄卡）。
@immutable
class LanSyncLocalDevice {
  LanSyncLocalDevice({
    required this.deviceId,
    required this.name,
    required this.platform,
    List<String> addresses = const <String>[],
    this.port,
    this.discoverable = true,
    this.discoveryListening = true,
  }) : addresses = List<String>.unmodifiable(addresses);

  final String deviceId;
  final String name;
  final String platform;

  /// 本机局域网地址（最可能连得上的在前）；空表示没连上局域网。
  final List<String> addresses;

  /// 同步服务实际监听的端口；服务没起来（后台、绑定失败）时为 null。
  final int? port;
  final bool discoverable;

  /// 发现端口是否绑定成功（被别的程序占用时为 false）。
  final bool discoveryListening;

  @override
  bool operator ==(Object other) =>
      other is LanSyncLocalDevice &&
      other.deviceId == deviceId &&
      other.name == name &&
      other.platform == platform &&
      listEquals(other.addresses, addresses) &&
      other.port == port &&
      other.discoverable == discoverable &&
      other.discoveryListening == discoveryListening;

  @override
  int get hashCode => Object.hash(
    deviceId,
    name,
    platform,
    Object.hashAll(addresses),
    port,
    discoverable,
    discoveryListening,
  );
}

/// 一台已配对设备的现状。
@immutable
class LanSyncPeerState {
  LanSyncPeerState({
    required this.device,
    this.online = false,
    this.address,
    this.session,
    this.awaitingConfirmation = false,
    List<LanSyncSessionRecord> history = const <LanSyncSessionRecord>[],
  }) : history = List<LanSyncSessionRecord>.unmodifiable(history);

  /// 配对记录（名称、备注、平台、上次同步、开关、`needsAttention`）。
  final LanSyncPairedDevice device;

  /// 最近收到过它的信标（发现不运行——后台——时为 false；本机不可被发现时
  /// 发现只听不发，照样能看到它）。
  final bool online;

  /// 在线时的地址，否则为上次连上它的地址。
  final String? address;

  /// 正在进行的会话进度；没有为 null。
  final LanSyncProgress? session;

  /// 有一次手动同步正在等用户确认（对话框没弹出或还没应答）。
  final bool awaitingConfirmation;

  /// 同步记录，新的在前。
  final List<LanSyncSessionRecord> history;

  /// 界面的“需要确认”：自动同步留下的标记，或正在等的确认。
  bool get needsAttention => device.needsAttention || awaitingConfirmation;

  @override
  bool operator ==(Object other) =>
      other is LanSyncPeerState &&
      other.device == device &&
      other.online == online &&
      other.address == address &&
      other.session == session &&
      other.awaitingConfirmation == awaitingConfirmation &&
      listEquals(other.history, history);

  @override
  int get hashCode => Object.hash(
    device,
    online,
    address,
    session,
    awaitingConfirmation,
    Object.hashAll(history),
  );
}

/// 附近发现、还没配对的设备（只在同步页打开时列出）。
@immutable
class LanSyncNearbyDevice {
  const LanSyncNearbyDevice({
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.address,
  });

  final String deviceId;
  final String name;
  final String platform;
  final String address;

  @override
  bool operator ==(Object other) =>
      other is LanSyncNearbyDevice &&
      other.deviceId == deviceId &&
      other.name == name &&
      other.platform == platform &&
      other.address == address;

  @override
  int get hashCode => Object.hash(deviceId, name, platform, address);
}

/// 服务的整体状态快照。
@immutable
class LanSyncEngineState {
  LanSyncEngineState({
    required this.local,
    List<LanSyncPeerState> peers = const <LanSyncPeerState>[],
    List<LanSyncNearbyDevice> nearby = const <LanSyncNearbyDevice>[],
    this.autoSync = true,
    this.syncSettings = false,
    this.searching = false,
  }) : peers = List<LanSyncPeerState>.unmodifiable(peers),
       nearby = List<LanSyncNearbyDevice>.unmodifiable(nearby);

  final LanSyncLocalDevice local;

  /// 已配对设备，按配对先后。
  final List<LanSyncPeerState> peers;
  final List<LanSyncNearbyDevice> nearby;
  final bool autoSync;
  final bool syncSettings;

  /// 同步页打开且发现在运行。
  final bool searching;

  LanSyncPeerState? peer(String deviceId) {
    for (final peer in peers) {
      if (peer.device.deviceId == deviceId) return peer;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is LanSyncEngineState &&
      other.local == local &&
      listEquals(other.peers, peers) &&
      listEquals(other.nearby, nearby) &&
      other.autoSync == autoSync &&
      other.syncSettings == syncSettings &&
      other.searching == searching;

  @override
  int get hashCode => Object.hash(
    local,
    Object.hashAll(peers),
    Object.hashAll(nearby),
    autoSync,
    syncSettings,
    searching,
  );
}

/// 当前显示的二维码。
@immutable
class LanSyncIssuedQr {
  const LanSyncIssuedQr({
    required this.payload,
    required this.issuedAt,
    required this.expiresAt,
  });

  /// `jotsy-lan:v1:…`。
  final String payload;
  final DateTime issuedAt;
  final DateTime expiresAt;
}

/// 服务的一次性事件（广播流，不重放）。
@immutable
sealed class LanSyncEngineEvent {
  const LanSyncEngineEvent();
}

/// 一次配对开始（本机发起或对方请求）；之后的进展看 [pairing] 的状态。
final class LanSyncPairingStarted extends LanSyncEngineEvent {
  const LanSyncPairingStarted(this.pairing);
  final LanSyncPairing pairing;
}

/// 手动同步需要用户确认（“查看”时同一个请求会再发一次）。
final class LanSyncConfirmationRequested extends LanSyncEngineEvent {
  const LanSyncConfirmationRequested(this.request);
  final LanSyncConfirmationRequest request;
}

/// 一次会话结束（成功或失败，两个角色、手动与自动都发）。
final class LanSyncSessionEnded extends LanSyncEngineEvent {
  const LanSyncSessionEnded(this.result, {required this.firstSync});
  final LanSyncSessionResult result;

  /// 是否为与这台设备的第一次同步。
  final bool firstSync;
}

/// 自动同步（任一方发起）写入了本机日记。没有变化时不发。
final class LanSyncAutoSyncApplied extends LanSyncEngineEvent {
  const LanSyncAutoSyncApplied({required this.peerId, required this.diaries});
  final String peerId;
  final int diaries;
}

/// 自动同步遇到需要确认的情况，已中止并标记这台设备。
final class LanSyncAttentionNeeded extends LanSyncEngineEvent {
  const LanSyncAttentionNeeded(this.peerId);
  final String peerId;
}
