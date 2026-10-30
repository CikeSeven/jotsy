import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../app_platform.dart';

// 局域网同步的原生通道（Dart 端）与本机网络信息。
//
// - 输入：原生通道 `com.jotsy.diary/lan_sync`（Android 的 `LanSyncChannel.kt`）
//   与 `NetworkInterface.list` 列出的本机接口；
// - 输出：组播锁的持有 / 释放、系统设备名、`noBackupFilesDir` 路径，
//   可用于二维码与英雄卡显示的本机私有 IPv4 地址，以及发现按网卡定向发送
//   用的子网广播地址（规格 docs/lan_sync.md §5.1）；
// - 副作用：只有 Android 上的组播锁会改变系统状态（Wi-Fi 驱动放行组播包），
//   其余都是只读查询（含 Linux 上读 `/proc/net/route`）。

/// Android 原生通道的 Dart 端。
///
/// 通道只在真机的 Android 工程里注册，所以每次调用旁都用运行时
/// `Platform.isAndroid` 判断（AGENTS.md §6 只允许在原生调用旁这样做）：
/// widget 测试会把 `defaultTargetPlatform` 覆盖成 Android，但宿主机上并没有这个
/// 通道，按 `AppPlatform` 判断就会去调用并抛 `MissingPluginException`。
/// 非 Android 一律是空操作 / 返回 null；Android 上通道缺失或原生报错同样当作
/// “不可用”，从不把异常抛给调用方——发现和同步在拿不到组播锁或设备名时仍能
/// 以降级方式工作。
class LanSyncNativeChannel {
  LanSyncNativeChannel({MethodChannel? channel, bool? isAndroid})
    : _channel = channel ?? const MethodChannel(channelName),
      _isAndroid = isAndroid ?? (!kIsWeb && Platform.isAndroid);

  static const String channelName = 'com.jotsy.diary/lan_sync';

  /// 全局实例；测试可替换为注入了假通道的实例。
  static LanSyncNativeChannel instance = LanSyncNativeChannel();

  final MethodChannel _channel;
  final bool _isAndroid;

  /// 是否会真正调用原生通道。
  bool get isAvailable => _isAndroid;

  /// 持有 Wi-Fi 组播锁：多数 Android 设备的 Wi-Fi 驱动默认丢弃发往本机以外的
  /// 组播 / 广播包以省电，不持有就收不到其他设备的信标。成功时为 true；
  /// 非 Android、通道缺失或系统拒绝时为 false。
  Future<bool> acquireMulticastLock() async =>
      await _invoke<bool>('acquireMulticastLock') ?? false;

  /// 释放组播锁；没有持有时原生侧同样是空操作。
  Future<void> releaseMulticastLock() => _invoke<void>('releaseMulticastLock');

  /// 系统里的设备名（设置 → 关于手机里用户可改的那个名字），取不到时原生侧
  /// 回落为 `Build.MODEL`；非 Android 或失败时为 null。
  Future<String?> deviceName() async {
    final name = (await _invoke<String>('deviceName'))?.trim();
    return name == null || name.isEmpty ? null : name;
  }

  /// `Context.noBackupFilesDir` 的绝对路径；非 Android 或失败时为 null。
  Future<String?> noBackupDirectory() async {
    final path = (await _invoke<String>('noBackupDirectory'))?.trim();
    return path == null || path.isEmpty ? null : path;
  }

  Future<T?> _invoke<T>(String method) async {
    if (!_isAndroid) {
      return null;
    }
    try {
      return await _channel.invokeMethod<T>(method);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('LanSyncNativeChannel.$method failed: ${error.message}');
      return null;
    }
  }
}

/// 一块网卡的名称与它的 IPv4 地址，供 [rankLanSyncAddresses] 排序；
/// 与 `NetworkInterface` 解耦，测试可以直接构造。
@immutable
class LanSyncInterfaceInfo {
  const LanSyncInterfaceInfo(this.name, this.addresses);

  final String name;
  final List<InternetAddress> addresses;
}

/// 本机可供其他设备连接的私有 IPv4 地址，按优先级排好（最可能连得上的在前）。
///
/// 只列 IPv4：信标、二维码与服务端都按 IPv4 处理，局域网里 IPv6 地址多为
/// 临时 / 链路本地地址，写进二维码只会变长、不更可靠。
Future<List<InternetAddress>> lanSyncLocalAddresses() async {
  final List<NetworkInterface> interfaces;
  try {
    interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
  } on SocketException catch (error) {
    debugPrint('lanSyncLocalAddresses failed: ${error.message}');
    return const <InternetAddress>[];
  }
  return rankLanSyncAddresses([
    for (final item in interfaces)
      LanSyncInterfaceInfo(item.name, item.addresses),
  ]);
}

/// 一块网卡上定向发送信标用的地址：本机地址与它所在子网的广播地址。
typedef LanSyncInterfaceBroadcast = ({
  InternetAddress local,
  InternetAddress broadcast,
});

/// 一条直连路由（`/proc/net/route` 里网关为 0 的一行）：网卡、网络号与前缀长度。
@immutable
class LanSyncOnLinkRoute {
  const LanSyncOnLinkRoute(this.interface, this.network, this.prefixLength);

  final String interface;

  /// 网络号（按网络字节序拼成的 32 位整数，如 192.168.100.0 → 0xC0A86400）。
  final int network;
  final int prefixLength;
}

/// 本机每块局域网网卡（Wi-Fi / 以太网与“其他”两档，不含 VPN 与被排除的
/// 虚拟网卡，见 [rankLanSyncAddresses]）上的私有 IPv4 地址与子网广播地址，
/// 供发现按网卡定向发送信标（docs/lan_sync.md §5.1）。
///
/// 子网前缀：Linux 上读 `/proc/net/route` 的直连路由；读不到（Windows、
/// Android 10 起不让应用读）时按 /24 推算——家用路由器几乎都是 /24，猜错时
/// 那个“广播地址”只是子网里一个不存在的主机，包被丢掉而已，同一个套接字
/// 发的受限广播与组播照样从这块网卡出去。
Future<List<LanSyncInterfaceBroadcast>> lanSyncInterfaceBroadcasts() async {
  final List<NetworkInterface> interfaces;
  try {
    interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
  } on SocketException catch (error) {
    debugPrint('lanSyncInterfaceBroadcasts failed: ${error.message}');
    return const <LanSyncInterfaceBroadcast>[];
  }
  var routes = const <LanSyncOnLinkRoute>[];
  if (!kIsWeb && Platform.isLinux) {
    try {
      routes = parseLanSyncProcNetRoute(
        await File('/proc/net/route').readAsString(),
      );
    } on Object {
      // 读不到就按 /24 推算。
    }
  }
  return lanSyncBroadcastsOf([
    for (final item in interfaces)
      LanSyncInterfaceInfo(item.name, item.addresses),
  ], routes: routes);
}

/// [lanSyncInterfaceBroadcasts] 的纯函数部分：按网卡算出子网广播地址。
///
/// 前缀取 [routes] 里同一网卡、网络号包含该地址的直连路由中最长的一条，
/// 没有时按 [fallbackPrefix]；/31、/32 没有广播地址，跳过。同一地址只出现
/// 一次。
List<LanSyncInterfaceBroadcast> lanSyncBroadcastsOf(
  List<LanSyncInterfaceInfo> interfaces, {
  List<LanSyncOnLinkRoute> routes = const <LanSyncOnLinkRoute>[],
  int fallbackPrefix = 24,
}) {
  final result = <LanSyncInterfaceBroadcast>[];
  final seen = <String>{};
  for (final item in interfaces) {
    final rank = _interfaceRank(item.name);
    if (rank == null || rank == _kVpnRank) continue;
    for (final address in item.addresses) {
      if (!isLanSyncPrivateIPv4(address) || !seen.add(address.address)) {
        continue;
      }
      final value = _ipv4Value(address);
      var prefix = -1;
      for (final route in routes) {
        if (route.interface != item.name) continue;
        if (_prefixMask(route.prefixLength) & value != route.network) continue;
        if (route.prefixLength > prefix) prefix = route.prefixLength;
      }
      if (prefix < 0) prefix = fallbackPrefix;
      if (prefix > 30) continue;
      final broadcast = value | (~_prefixMask(prefix) & 0xFFFFFFFF);
      result.add((local: address, broadcast: _ipv4Address(broadcast)));
    }
  }
  return result;
}

/// 解析 `/proc/net/route`：只取网关为 0（直连）、掩码非 0 的行。文件里的
/// 地址与掩码是本机字节序（小端）的十六进制，这里换回网络字节序；掩码不
/// 连续的行丢掉。格式不对的行忽略。
List<LanSyncOnLinkRoute> parseLanSyncProcNetRoute(String text) {
  final routes = <LanSyncOnLinkRoute>[];
  for (final line in text.split('\n').skip(1)) {
    final fields = line.trim().split(RegExp(r'\s+'));
    if (fields.length < 8) continue;
    final destination = int.tryParse(fields[1], radix: 16);
    final gateway = int.tryParse(fields[2], radix: 16);
    final mask = int.tryParse(fields[7], radix: 16);
    if (destination == null || gateway == null || mask == null) continue;
    if (gateway != 0 || mask == 0) continue;
    final networkMask = _swap32(mask);
    final prefix = _prefixLengthOf(networkMask);
    if (prefix == null) continue;
    routes.add(
      LanSyncOnLinkRoute(fields[0], _swap32(destination) & networkMask, prefix),
    );
  }
  return routes;
}

int _ipv4Value(InternetAddress address) {
  final bytes = address.rawAddress;
  return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
}

InternetAddress _ipv4Address(int value) => InternetAddress.fromRawAddress(
  Uint8List.fromList(<int>[
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  ]),
);

int _prefixMask(int prefix) =>
    prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;

int _swap32(int value) =>
    ((value & 0xFF) << 24) |
    ((value & 0xFF00) << 8) |
    ((value >> 8) & 0xFF00) |
    ((value >> 24) & 0xFF);

/// 连续掩码的前缀长度；不连续时为 null。
int? _prefixLengthOf(int mask) {
  for (var prefix = 0; prefix <= 32; prefix++) {
    if (_prefixMask(prefix) == mask) return prefix;
  }
  return null;
}

/// [lanSyncLocalAddresses] 的纯函数部分：过滤并排序。
///
/// 规则（为什么这样分）：
/// - 只要私有 IPv4（10/8、172.16/12、192.168/16）：公网地址说明设备直连了公网
///   或运营商网络，同一局域网的设备不会用它互连；回环与链路本地（169.254）
///   别的设备连不到。
/// - 直接排除容器 / 虚拟机网桥（docker、veth、br-、virbr、vmnet、vboxnet、
///   Hyper-V 的 vEthernet 等）与手机蜂窝接口（rmnet、ccmni、wwan 等）：前者只在
///   本机内部可达，后者在运营商的私网里（常见 10.x），都不可能是对面设备的
///   局域网地址，列出来只会让二维码里多一个必然超时的候选。
/// - VPN 与覆盖网络（tun、utun、tap、wg、ppp、ham(achi)、zt(ZeroTier)、
///   tailscale）排到最后但保留：有人确实用 ZeroTier / Hamachi 组“虚拟局域网”，
///   这时它们是唯一能连通的地址。
/// - Wi-Fi / 以太网（wlan*、wl*、en*、eth*、ap*（热点）、Windows 的“Wi-Fi”、
///   “WLAN”、“以太网”、“Ethernet”）排最前，其余（USB 共享等）居中。
/// - 同档内保持系统列出的顺序（系统通常把默认路由的接口放前面），重复地址
///   只留第一次出现的。
List<InternetAddress> rankLanSyncAddresses(
  List<LanSyncInterfaceInfo> interfaces,
) {
  final ranked = <({int rank, int order, InternetAddress address})>[];
  var order = 0;
  for (final item in interfaces) {
    final rank = _interfaceRank(item.name);
    if (rank == null) {
      continue;
    }
    for (final address in item.addresses) {
      if (isLanSyncPrivateIPv4(address)) {
        ranked.add((rank: rank, order: order++, address: address));
      }
    }
  }
  ranked.sort((a, b) {
    final byRank = a.rank.compareTo(b.rank);
    return byRank != 0 ? byRank : a.order.compareTo(b.order);
  });
  final seen = <String>{};
  return [
    for (final entry in ranked)
      if (seen.add(entry.address.address)) entry.address,
  ];
}

/// 是否为 RFC 1918 私有 IPv4 地址。
bool isLanSyncPrivateIPv4(InternetAddress address) {
  if (address.type != InternetAddressType.IPv4) {
    return false;
  }
  final bytes = address.rawAddress;
  if (bytes.length != 4) {
    return false;
  }
  final a = bytes[0];
  final b = bytes[1];
  return a == 10 || (a == 172 && b >= 16 && b <= 31) || (a == 192 && b == 168);
}

const List<String> _excludedInterfacePrefixes = [
  'docker',
  'veth',
  'br-',
  'virbr',
  'vmnet',
  'vboxnet',
  'virtualbox',
  'vmware',
  'vethernet', // Hyper-V / WSL 的虚拟交换机（Windows 友好名 “vEthernet (WSL)”）
  'lxc',
  'lxd',
  'cni',
  'flannel',
  'podman',
  'rmnet',
  'ccmni',
  'pdp',
  'wwan',
  'clat',
  'dummy',
];

const List<String> _vpnInterfacePrefixes = [
  'tun',
  'utun',
  'tap',
  'wg',
  'ppp',
  'ipsec',
  'ham',
  'zt',
  'tailscale',
  'zerotier',
];

const List<String> _preferredInterfacePrefixes = [
  'swlan',
  'wl',
  'en',
  'eth',
  'ap',
  'wi-fi',
  'wifi',
  'ethernet',
  '以太网',
  '无线',
];

/// [_interfaceRank] 里 VPN 与覆盖网络的一档。
const int _kVpnRank = 2;

/// 接口名的优先档：0 Wi-Fi / 以太网，1 其他，2 VPN；null 为排除。
///
/// 先判断排除与 VPN：`vethernet` 也以 “veth” 开头、`tun` 不能被 “en” 误配，
/// 按前缀匹配时顺序很重要。
int? _interfaceRank(String rawName) {
  final name = rawName.trim().toLowerCase();
  if (_excludedInterfacePrefixes.any(name.startsWith)) {
    return null;
  }
  if (_vpnInterfacePrefixes.any(name.startsWith) ||
      name.contains('vpn') ||
      name.contains('tailscale') ||
      name.contains('zerotier')) {
    return _kVpnRank;
  }
  if (_preferredInterfacePrefixes.any(name.startsWith) ||
      name.contains('wi-fi')) {
    return 0;
  }
  return 1;
}

/// 设备名的最大长度（按字符）；信标与配对设备列表都按这个上限截断。
const int kLanSyncDeviceNameMaxLength = 40;

/// 默认设备名：Android 取系统设备名（原生侧回落为机型），桌面取主机名，
/// 都取不到时用平台名。只是初始值，用户可在同步页改名（存于 `store.json`）。
Future<String> lanSyncDefaultDeviceName({
  LanSyncNativeChannel? channel,
  String Function()? hostname,
}) async {
  final native = await (channel ?? LanSyncNativeChannel.instance).deviceName();
  if (native != null) {
    return truncateLanSyncDeviceName(native);
  }
  if (AppPlatform.isDesktop) {
    String? host;
    try {
      host = (hostname ?? () => Platform.localHostname)();
    } on Object {
      host = null;
    }
    final cleaned = host == null ? '' : cleanLanSyncHostname(host);
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
  }
  return lanSyncPlatformLabel();
}

/// 主机名去掉域后缀（macOS 的 `xxx.local`、带域的 `pc.corp.example`），
/// 只留第一段并截断。
String cleanLanSyncHostname(String hostname) {
  final first = hostname.trim().split('.').first.trim();
  return truncateLanSyncDeviceName(first);
}

/// 按字符（Unicode 码点）截断到 [kLanSyncDeviceNameMaxLength]，避免切开代理对。
String truncateLanSyncDeviceName(String name) {
  final trimmed = name.trim();
  final runes = trimmed.runes;
  if (runes.length <= kLanSyncDeviceNameMaxLength) {
    return trimmed;
  }
  return String.fromCharCodes(runes.take(kLanSyncDeviceNameMaxLength)).trim();
}

/// 本机平台在信标里的标识（`p` 字段），也是设备名的最后回落。
String lanSyncPlatformId() {
  if (AppPlatform.isAndroid) return 'android';
  if (AppPlatform.isWindows) return 'windows';
  if (AppPlatform.isLinux) return 'linux';
  if (AppPlatform.isMacOS) return 'macos';
  if (AppPlatform.isIOS) return 'ios';
  return 'unknown';
}

/// 平台的显示名，用作设备名的最后回落（产品名不翻译）。
String lanSyncPlatformLabel() => switch (lanSyncPlatformId()) {
  'android' => 'Android',
  'windows' => 'Windows',
  'linux' => 'Linux',
  'macos' => 'macOS',
  'ios' => 'iOS',
  _ => 'Jotsy',
};
