// 局域网同步服务的可注入部件与计时（lan_sync_service.dart 的构造参数）。
//
// 职责边界：只是参数的默认值与类型；默认值是生产行为（真实套接字、真实发现、
// 系统时钟、`EditingSessionRegistry.instance`），测试注入回环地址、假发现、
// 假时钟与很短的计时，在一个进程里跑两三台“设备”。无副作用。
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../editing_session_registry.dart';
import 'lan_sync_discovery.dart';
import 'lan_sync_network.dart';
import 'lan_sync_session_types.dart';

/// TCP 同步端口的首选值（占用时改用随机端口，信标里广播实际端口）。
const int kLanSyncPreferredPort = 47562;

/// 计时器工厂（测试换成可手动推进的假计时器）。
typedef LanSyncTimerFactory =
    Timer Function(Duration duration, void Function() callback);

/// 自动同步的计时（docs §9）。
@immutable
class LanSyncAutoTimings {
  const LanSyncAutoTimings({
    this.dataDebounce = const Duration(seconds: 20),
    this.rateLimit = const Duration(seconds: 60),
    this.mutualRetry = const Duration(seconds: 10),
    this.busyRetry = const Duration(seconds: 10),
  });

  /// 本机数据变化后、编辑结束后再等多久才同步（期间再有变化重新计时）。
  final Duration dataDebounce;

  /// 同一台设备两次自动同步之间的最短间隔（两个方向合计）。
  final Duration rateLimit;

  /// deviceId 较大的一方等多久没有等到对方发起，才自己发起。
  final Duration mutualRetry;

  /// 到点时正与别的设备同步，隔多久再试一次（只再试一次）。
  final Duration busyRetry;
}

/// 服务的计时。
@immutable
class LanSyncServiceTimings {
  const LanSyncServiceTimings({
    this.connectTimeout = const Duration(seconds: 4),
    this.handshakeStep = const Duration(seconds: 15),
    this.sasTimeout = const Duration(seconds: 60),
    this.handshakeLinger = const Duration(seconds: 2),
    this.session = const LanSyncSessionTimeouts(),
    this.pageBeaconInterval = kLanSyncBeaconIntervalPage,
    this.autoBeaconInterval = kLanSyncBeaconIntervalAuto,
    this.addressRefresh = const Duration(seconds: 15),
    this.auto = const LanSyncAutoTimings(),
  });

  /// 建立 TCP 连接的上限（每个候选地址）。
  final Duration connectTimeout;

  /// 握手每一步、核对码确认、拒绝后收尾的上限（见 [LanSyncHandshake]）。
  final Duration handshakeStep;
  final Duration sasTimeout;
  final Duration handshakeLinger;

  final LanSyncSessionTimeouts session;

  /// 同步页打开时 / 前台自动模式的信标间隔。
  final Duration pageBeaconInterval;
  final Duration autoBeaconInterval;

  /// 同步页打开期间多久重新读一次本机地址（换了 Wi-Fi 时二维码与英雄卡跟着变）。
  final Duration addressRefresh;

  final LanSyncAutoTimings auto;
}

/// 编辑会话的接口：现在能不能同步、开始前冲刷、什么时候编辑结束。
@immutable
class LanSyncEditingGate {
  const LanSyncEditingGate({
    required this.isEditing,
    required this.flushAll,
    this.changes,
  });

  /// 生产接线：进程内的 [EditingSessionRegistry]。
  factory LanSyncEditingGate.of(EditingSessionRegistry registry) =>
      LanSyncEditingGate(
        isEditing: () => registry.isEditing,
        flushAll: registry.flushAll,
        changes: registry.activeEditors,
      );

  final bool Function() isEditing;
  final Future<void> Function() flushAll;

  /// 阻塞者个数变化时通知（自动同步据此在编辑结束后开始去抖计时）。
  final Listenable? changes;
}

/// 服务用到的外部能力（套接字、发现、地址、设备名、时钟、计时器）。
@immutable
class LanSyncServiceHooks {
  const LanSyncServiceHooks({
    this.clock = DateTime.now,
    this.preferredPort = kLanSyncPreferredPort,
    this.bindServer = _bindAny,
    this.connect = _connect,
    this.discovery = LanSyncDiscovery.new,
    this.localAddresses = _addresses,
    this.defaultDeviceName = lanSyncDefaultDeviceName,
    this.platformId = lanSyncPlatformId,
    this.timer = Timer.new,
  });

  final DateTime Function() clock;

  /// 首选的 TCP 端口；0 表示总是随机端口（测试）。
  final int preferredPort;

  /// 在 [port] 上监听（0 为随机端口）；端口被占用时抛错。
  final Future<ServerSocket> Function(int port) bindServer;

  /// 连接 [host]:[port]，超过 [timeout] 抛错。
  final Future<Socket> Function(String host, int port, Duration timeout)
  connect;

  /// 新建发现（服务在需要时创建一次，之后反复启停）。
  final LanSyncDiscovery Function() discovery;

  /// 本机可供连接的地址（字符串字面量，最可能连得上的在前）。
  final Future<List<String>> Function() localAddresses;

  /// 用户没起名字时的默认设备名。
  final Future<String> Function() defaultDeviceName;

  /// 本机平台标识（信标与握手里的 `platform`）。
  final String Function() platformId;

  final LanSyncTimerFactory timer;

  static Future<ServerSocket> _bindAny(int port) =>
      ServerSocket.bind(InternetAddress.anyIPv4, port);

  static Future<Socket> _connect(String host, int port, Duration timeout) =>
      Socket.connect(host, port, timeout: timeout);

  static Future<List<String>> _addresses() async => [
    for (final address in await lanSyncLocalAddresses()) address.address,
  ];
}
