import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'lan_sync_network.dart';

// 局域网同步的 UDP 发现（docs/lan_sync.md §5.1）。
//
// - 输入：调用方给出的信标生成函数（每次发送都重新取，TCP 端口、名称变了
//   下一拍就生效）与发送间隔；
// - 输出：在线表 [LanSyncDiscovery.peers]（按 deviceId）与运行状态
//   [LanSyncDiscovery.status]；
// - 副作用：绑定 UDP 端口、加入组播组、周期性发送广播 / 组播（[LanSyncDiscovery
//   .advertise] 关闭时只听不发）；Android 上运行期间持有 Wi-Fi 组播锁。

/// 发现端口（信标收发）。
const int kLanSyncDiscoveryPort = 47561;

/// 发现用的组播组（管理范围组播 239/8，只在本地网络内有效）。
final InternetAddress kLanSyncMulticastGroup = InternetAddress('239.255.47.61');

/// 同步页打开时的信标间隔。
const Duration kLanSyncBeaconIntervalPage = Duration(seconds: 2);

/// 应用在前台、自动同步模式下的信标间隔。
const Duration kLanSyncBeaconIntervalAuto = Duration(seconds: 5);

/// 多久没收到信标即视为离线。比自动模式间隔的 1.5 倍略长，丢一个包不掉线。
const Duration kLanSyncPresenceTimeout = Duration(seconds: 8);

/// 信标包的上限；超过的包直接丢弃（正常信标不到 300 字节）。
const int kLanSyncBeaconMaxBytes = 1024;

/// 发现信标：`{"j":"jotsy-lan","v":1,"id","n","p","port","fp","f"}`。
///
/// 解码严格校验：魔数与版本必须完全一致，字段齐全且类型、取值范围正确，
/// 否则整包丢弃——信标来自局域网里任何人，宁可看不到也不让畸形数据进入
/// 在线表。未知的额外字段忽略（同一 `v` 内向后兼容地加字段）。
@immutable
class LanSyncBeacon {
  LanSyncBeacon({
    required this.deviceId,
    required String name,
    required this.platform,
    required this.port,
    required this.fingerprint,
    required this.formatVersion,
  }) : name = truncateLanSyncDeviceName(name);

  static const String magic = 'jotsy-lan';
  static const int version = 1;

  static final RegExp _idPattern = RegExp(r'^[A-Za-z0-9._-]{1,64}$');
  static final RegExp _platformPattern = RegExp(r'^[a-z0-9_]{1,16}$');
  static final RegExp _fingerprintPattern = RegExp(r'^[0-9a-f]{16}$');

  /// 设备 id（`identity.json` 里的 UUID）。
  final String deviceId;

  /// 显示名，已截断到 [kLanSyncDeviceNameMaxLength] 个字符。
  final String name;

  /// 平台标识（`android` / `linux` / `windows` / `macos`），见 `lanSyncPlatformId`。
  final String platform;

  /// 同步服务端实际监听的 TCP 端口。
  final int port;

  /// 身份公钥指纹的前 8 字节（16 位小写十六进制）。
  final String fingerprint;

  /// 同步格式版本（`kSyncFormatVersion`）。
  final int formatVersion;

  Map<String, Object> toJson() => <String, Object>{
    'j': magic,
    'v': version,
    'id': deviceId,
    'n': name,
    'p': platform,
    'port': port,
    'fp': fingerprint,
    'f': formatVersion,
  };

  /// UTF-8 JSON 字节。字段都有上限（名称 40 字符最多 160 字节），不会超过
  /// [kLanSyncBeaconMaxBytes]。
  Uint8List encode() {
    final bytes = utf8.encode(jsonEncode(toJson()));
    assert(bytes.length <= kLanSyncBeaconMaxBytes);
    return bytes;
  }

  /// 解码一个 UDP 包；任何不合规的情况都返回 null。
  static LanSyncBeacon? decode(List<int> bytes) {
    if (bytes.isEmpty || bytes.length > kLanSyncBeaconMaxBytes) {
      return null;
    }
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null;
    }
    if (json is! Map<String, Object?>) {
      return null;
    }
    if (json['j'] != magic || json['v'] != version) {
      return null;
    }
    final id = json['id'];
    final name = json['n'];
    final platform = json['p'];
    final port = json['port'];
    final fingerprint = json['fp'];
    final format = json['f'];
    if (id is! String || !_idPattern.hasMatch(id)) return null;
    if (name is! String || name.trim().isEmpty) return null;
    if (platform is! String || !_platformPattern.hasMatch(platform)) {
      return null;
    }
    if (port is! int || port < 1 || port > 65535) return null;
    if (fingerprint is! String || !_fingerprintPattern.hasMatch(fingerprint)) {
      return null;
    }
    if (format is! int || format < 1) return null;
    return LanSyncBeacon(
      deviceId: id,
      name: name,
      platform: platform,
      port: port,
      fingerprint: fingerprint,
      formatVersion: format,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LanSyncBeacon &&
      other.deviceId == deviceId &&
      other.name == name &&
      other.platform == platform &&
      other.port == port &&
      other.fingerprint == fingerprint &&
      other.formatVersion == formatVersion;

  @override
  int get hashCode =>
      Object.hash(deviceId, name, platform, port, fingerprint, formatVersion);

  @override
  String toString() => 'LanSyncBeacon(${jsonEncode(toJson())})';
}

/// 在线表里的一台设备：最近一次信标、发出它的地址与收到的时间。
@immutable
class LanSyncPresence {
  const LanSyncPresence({
    required this.beacon,
    required this.address,
    required this.lastSeen,
  });

  final LanSyncBeacon beacon;

  /// 信标包的源地址；连接时用它 + `beacon.port`。
  final InternetAddress address;

  final DateTime lastSeen;
}

/// 发现的运行状态。
@immutable
class LanSyncDiscoveryStatus {
  const LanSyncDiscoveryStatus({
    required this.running,
    required this.listening,
    this.boundPort,
  });

  static const LanSyncDiscoveryStatus stopped = LanSyncDiscoveryStatus(
    running: false,
    listening: false,
  );

  /// 是否在运行（有可用的套接字在发信标）。
  final bool running;

  /// 是否在发现端口上监听。false 而 [running] 为 true 时，端口被占用、退到了
  /// 随机端口：本机照常发信标，别人收到后的单播回复也能收到，但收不到别人
  /// 主动广播的信标——界面据此说明“其他设备可能看不到 / 发现较慢”。
  final bool listening;

  /// 实际绑定的本地端口（测试与诊断用）。
  final int? boundPort;

  @override
  bool operator ==(Object other) =>
      other is LanSyncDiscoveryStatus &&
      other.running == running &&
      other.listening == listening &&
      other.boundPort == boundPort;

  @override
  int get hashCode => Object.hash(running, listening, boundPort);
}

/// 信标的发送目标。
typedef LanSyncDiscoveryTarget = ({InternetAddress address, int port});

/// UDP 发现：周期性广播本机信标，收集他人的信标形成在线表。
///
/// 状态机：stopped →（[start]）running →（[stop]）stopped，可反复启停；
/// [dispose] 后不可再用。运行期间：
/// - 启动时立即发一次信标，之后每 [start] 给出的间隔发一次（[setInterval]
///   可随时改，例如同步页打开 2 秒、回到自动模式 5 秒）；
/// - 收到一台新设备（在线表里没有，或已过期被移除）的信标时，立刻向它的源
///   地址与源端口单播回复一次本机信标：双方不必等下一拍就能互相看到；对方
///   端口被占用、退到随机端口时，这个回复也是它唯一能收到我们的途径；
/// - 每 [sweepInterval] 清扫一次，超过 [presenceTimeout] 没收到信标的设备移除；
/// - 自己的 deviceId（广播 / 组播回环收到自己的包）一律忽略；
/// - [advertise] 关闭时只听不发：照常绑定端口、收信标、维护在线表，但既不
///   周期发送，也不给新设备单播回复——别人看不到本机（“不可被发现”），本机
///   仍能看到别人。可在运行中切换，打开时立即补发一次。
///
/// 测试注入 [port]（0 为随机端口）、[targets]（如 127.0.0.1:对方端口）、
/// 关闭组播，并注入时钟 [now] 后用 [sweepNow] 驱动过期，不需要真实等待。
class LanSyncDiscovery {
  LanSyncDiscovery({
    this.port = kLanSyncDiscoveryPort,
    List<LanSyncDiscoveryTarget>? targets,
    this.joinMulticast = true,
    LanSyncNativeChannel? nativeChannel,
    DateTime Function()? now,
    this.presenceTimeout = kLanSyncPresenceTimeout,
    this.sweepInterval = const Duration(seconds: 1),
    this._advertise = true,
  }) : targets =
           targets ??
           <LanSyncDiscoveryTarget>[
             (address: InternetAddress('255.255.255.255'), port: port),
             (address: kLanSyncMulticastGroup, port: port),
           ],
       _nativeChannel = nativeChannel ?? LanSyncNativeChannel.instance,
       _now = now ?? DateTime.now;

  /// 期望绑定的端口；0 表示随机端口（测试用）。
  final int port;

  /// 信标的发送目标；默认为受限广播与组播组（端口同 [port]）。
  final List<LanSyncDiscoveryTarget> targets;

  /// 是否加入组播组接收组播信标（测试关闭）。
  final bool joinMulticast;

  final Duration presenceTimeout;
  final Duration sweepInterval;

  final LanSyncNativeChannel _nativeChannel;
  final DateTime Function() _now;

  final ValueNotifier<Map<String, LanSyncPresence>> _peers =
      ValueNotifier<Map<String, LanSyncPresence>>(
        const <String, LanSyncPresence>{},
      );
  final ValueNotifier<LanSyncDiscoveryStatus> _status =
      ValueNotifier<LanSyncDiscoveryStatus>(LanSyncDiscoveryStatus.stopped);
  final StreamController<void> _handled = StreamController<void>.broadcast();

  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _socketSubscription;
  Timer? _beaconTimer;
  Timer? _sweepTimer;
  LanSyncBeacon Function()? _beacon;
  Duration _interval = kLanSyncBeaconIntervalAuto;
  String? _selfId;
  bool _lockHeld = false;
  bool _disposed = false;
  bool _advertise;

  /// 每次 [stop] 递增；[start] 的异步步骤之间据此判断是否已被停止，
  /// 避免“启动到一半被停止”后又把套接字挂上去。
  int _generation = 0;
  Future<void>? _starting;

  /// 已经报过错的发送目标，同一目标的发送失败只打印一次日志（没连 Wi-Fi 时
  /// 广播每拍都会失败）。
  final Set<String> _loggedSendFailures = <String>{};

  /// 在线表（deviceId → 在线信息），不含本机。
  ValueListenable<Map<String, LanSyncPresence>> get peers => _peers;

  ValueListenable<LanSyncDiscoveryStatus> get status => _status;

  /// 当前的信标间隔。
  Duration get interval => _interval;

  /// 是否发本机信标（周期发送与对新设备的单播回复）；见类注释。
  bool get advertise => _advertise;

  set advertise(bool value) {
    if (value == _advertise) return;
    _advertise = value;
    if (value && _socket != null) _sendBeacon();
  }

  /// 每处理完一个收到的数据包（无论是否接受）触发一次，供测试确定性地等待。
  @visibleForTesting
  Stream<void> get onDatagramHandled => _handled.stream;

  /// 开始发现。重复调用时只更新信标函数与间隔。
  ///
  /// 顺序：（Android）持有组播锁 → 绑定端口（失败则退到随机端口，再失败则
  /// 保持 stopped 并返回，不抛错）→ 开广播、加入组播组 → 立即发一次信标 →
  /// 启动发送与清扫计时器。
  Future<void> start({
    required LanSyncBeacon Function() beacon,
    required Duration interval,
  }) {
    assert(!_disposed, 'LanSyncDiscovery used after dispose');
    assert(interval > Duration.zero);
    _beacon = beacon;
    if (_socket != null) {
      setInterval(interval);
      return Future<void>.value();
    }
    _interval = interval;
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    final generation = _generation;
    _lockHeld = await _nativeChannel.acquireMulticastLock() || _lockHeld;
    if (generation != _generation || _disposed) {
      return;
    }
    final bound = await _bind();
    if (bound == null) {
      // 套接字都建不起来就不必占着组播锁（耗电）；状态保持 stopped。
      if (_lockHeld && generation == _generation) {
        _lockHeld = false;
        await _nativeChannel.releaseMulticastLock();
      }
      return;
    }
    final (socket, listening) = bound;
    if (generation != _generation || _disposed) {
      socket.close();
      return;
    }
    _socket = socket;
    socket.broadcastEnabled = true;
    _socketSubscription = socket.listen(
      (event) {
        if (event == RawSocketEvent.read) {
          _drain(socket);
        }
      },
      onError: (Object error) {
        debugPrint('LanSyncDiscovery socket error: $error');
      },
    );
    if (joinMulticast && listening) {
      await _joinMulticastGroup(socket);
      if (generation != _generation || _disposed) {
        return;
      }
    }
    _status.value = LanSyncDiscoveryStatus(
      running: true,
      listening: listening,
      boundPort: socket.port,
    );
    _sendBeacon();
    _restartBeaconTimer();
    _sweepTimer = Timer.periodic(sweepInterval, (_) => sweepNow());
  }

  /// 依次尝试：发现端口 + reusePort（同一台机器上多开时也能都收到广播）、
  /// 发现端口不带 reusePort（Windows 等不支持该选项会直接报错）、随机端口。
  /// 返回套接字与“是否在期望端口上监听”；全部失败（如没有网络栈）时为 null。
  Future<(RawDatagramSocket, bool)?> _bind() async {
    if (port != 0) {
      for (final reusePort in const [true, false]) {
        try {
          final socket = await RawDatagramSocket.bind(
            InternetAddress.anyIPv4,
            port,
            reuseAddress: true,
            reusePort: reusePort,
          );
          return (socket, true);
        } on Object catch (error) {
          debugPrint(
            'LanSyncDiscovery: bind $port (reusePort: $reusePort) '
            'failed: $error',
          );
        }
      }
    }
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      // 请求的就是随机端口（测试）时算作在监听。
      return (socket, port == 0);
    } on Object catch (error) {
      debugPrint('LanSyncDiscovery: bind failed: $error');
      return null;
    }
  }

  /// 在默认接口与每块 IPv4 接口上加入组播组。多网卡时内核只在默认接口上
  /// 收组播，所以逐个接口再加一遍；某个接口不支持（如 VPN）或已加入时会
  /// 报错，忽略即可——广播仍在兜底。
  Future<void> _joinMulticastGroup(RawDatagramSocket socket) async {
    var joined = false;
    try {
      socket.joinMulticast(kLanSyncMulticastGroup);
      joined = true;
    } on Object catch (error) {
      debugPrint('LanSyncDiscovery: joinMulticast (default) failed: $error');
    }
    List<NetworkInterface> interfaces;
    try {
      interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
    } on Object {
      interfaces = const <NetworkInterface>[];
    }
    for (final networkInterface in interfaces) {
      try {
        socket.joinMulticast(kLanSyncMulticastGroup, networkInterface);
        joined = true;
      } on Object catch (error) {
        debugPrint(
          'LanSyncDiscovery: joinMulticast on ${networkInterface.name} '
          'failed: $error',
        );
      }
    }
    if (!joined) {
      debugPrint('LanSyncDiscovery: multicast unavailable, broadcast only.');
    }
  }

  /// 改变信标间隔；只重排计时器，不额外立即发送。
  void setInterval(Duration interval) {
    assert(interval > Duration.zero);
    if (interval == _interval) {
      return;
    }
    _interval = interval;
    if (_socket != null) {
      _restartBeaconTimer();
    }
  }

  void _restartBeaconTimer() {
    _beaconTimer?.cancel();
    _beaconTimer = Timer.periodic(_interval, (_) => _sendBeacon());
  }

  /// 停止发现：关闭套接字与计时器、清空在线表、释放组播锁。
  Future<void> stop() async {
    _generation++;
    _beaconTimer?.cancel();
    _beaconTimer = null;
    _sweepTimer?.cancel();
    _sweepTimer = null;
    final subscription = _socketSubscription;
    _socketSubscription = null;
    _socket?.close();
    _socket = null;
    _loggedSendFailures.clear();
    if (!_disposed) {
      _peers.value = const <String, LanSyncPresence>{};
      _status.value = LanSyncDiscoveryStatus.stopped;
    }
    await subscription?.cancel();
    if (_lockHeld) {
      _lockHeld = false;
      await _nativeChannel.releaseMulticastLock();
    }
  }

  /// 停止并释放监听器；之后不可再调用 [start]。
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    final stopping = stop();
    _disposed = true;
    _peers.dispose();
    _status.dispose();
    await stopping;
    await _handled.close();
  }

  void _sendBeacon() {
    if (!_advertise) return;
    final bytes = _currentBeaconBytes();
    if (bytes == null) {
      return;
    }
    for (final target in targets) {
      _send(bytes, target.address, target.port);
    }
  }

  Uint8List? _currentBeaconBytes() {
    final factory = _beacon;
    if (factory == null) {
      return null;
    }
    final beacon = factory();
    _selfId = beacon.deviceId;
    return beacon.encode();
  }

  void _send(Uint8List bytes, InternetAddress address, int port) {
    final socket = _socket;
    if (socket == null) {
      return;
    }
    try {
      // 返回 0 表示发送缓冲区暂满，信标下一拍还会再发，不必重试。
      socket.send(bytes, address, port);
    } on SocketException catch (error) {
      // 没连网络、没有到广播 / 组播地址的路由时会失败；只记一次。
      if (_loggedSendFailures.add('${address.address}:$port')) {
        debugPrint(
          'LanSyncDiscovery: send to ${address.address}:$port failed: '
          '${error.message}',
        );
      }
    }
  }

  void _drain(RawDatagramSocket socket) {
    for (
      var datagram = socket.receive();
      datagram != null;
      datagram = socket.receive()
    ) {
      _handleDatagram(datagram);
      if (!_handled.isClosed) {
        _handled.add(null);
      }
    }
  }

  void _handleDatagram(Datagram datagram) {
    if (_disposed || _socket == null) {
      return;
    }
    final beacon = LanSyncBeacon.decode(datagram.data);
    if (beacon == null) {
      return;
    }
    final selfId = _selfId ?? _beacon?.call().deviceId;
    if (beacon.deviceId == selfId) {
      return;
    }
    final current = _peers.value;
    final isNew = !current.containsKey(beacon.deviceId);
    _peers.value = <String, LanSyncPresence>{
      ...current,
      beacon.deviceId: LanSyncPresence(
        beacon: beacon,
        address: datagram.address,
        lastSeen: _now(),
      ),
    };
    if (isNew && _advertise) {
      final bytes = _currentBeaconBytes();
      if (bytes != null) {
        _send(bytes, datagram.address, datagram.port);
      }
    }
  }

  /// 移除超过 [presenceTimeout] 没有收到信标的设备。由清扫计时器调用；
  /// 测试注入时钟后直接调用。
  @visibleForTesting
  void sweepNow() {
    if (_disposed) {
      return;
    }
    final now = _now();
    final current = _peers.value;
    final kept = <String, LanSyncPresence>{
      for (final entry in current.entries)
        if (now.difference(entry.value.lastSeen) <= presenceTimeout)
          entry.key: entry.value,
    };
    if (kept.length != current.length) {
      _peers.value = kept;
    }
  }
}
