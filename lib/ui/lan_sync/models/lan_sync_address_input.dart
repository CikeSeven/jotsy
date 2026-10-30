// “手动输入地址”的校验与规整（纯函数，无副作用）。

/// 规整用户输入的主机：去掉首尾空白，合法时返回规整后的主机，否则返回 null。
///
/// 接受：点分十进制 IPv4（每段 0–255、不带前导零以免被当成八进制）、带或不带
/// 方括号的 IPv6、以及 RFC 1123 主机名（字母数字与连字符，段长 1–63、总长
/// ≤ 253，段首尾不能是连字符）。“地址:端口”不在这里拆分，先经
/// [splitLanSyncHostPort]；含冒号的 IPv4 / 主机名在这里按不合法处理。
String? normalizeLanSyncHost(String input) {
  var host = input.trim();
  if (host.isEmpty) return null;
  if (host.startsWith('[') && host.endsWith(']')) {
    host = host.substring(1, host.length - 1);
  }
  if (host.contains(':')) {
    try {
      Uri.parseIPv6Address(host);
      return host;
    } on FormatException {
      return null;
    }
  }
  if (_ipv4Like.hasMatch(host)) {
    return _isValidIpv4(host) ? host : null;
  }
  if (host.length > 253) return null;
  final labels = host.split('.');
  for (final label in labels) {
    if (!_hostLabel.hasMatch(label)) return null;
  }
  return host.toLowerCase();
}

/// 把“地址:端口”拆开（英雄卡在默认端口被占用时显示、复制的就是这种形式）：
/// `192.168.1.5:24562`、`host.local:24562`、`[fe80::1]:24562`。主机与端口都
/// 合法时返回规整后的两部分，否则返回 null（不带端口的地址、裸 IPv6——它的
/// 冒号分不出端口——都不拆）。
({String host, int port})? splitLanSyncHostPort(String input) {
  final trimmed = input.trim();
  final colon = trimmed.lastIndexOf(':');
  if (colon <= 0) return null;
  final hostPart = trimmed.substring(0, colon);
  final isBracketed = hostPart.startsWith('[') && hostPart.endsWith(']');
  if (hostPart.contains(':') && !isBracketed) return null;
  final host = normalizeLanSyncHost(hostPart);
  final port = parseLanSyncPort(trimmed.substring(colon + 1));
  if (host == null || port == null) return null;
  return (host: host, port: port);
}

/// 解析端口：1–65535 的整数，否则返回 null。
int? parseLanSyncPort(String input) {
  final trimmed = input.trim();
  if (!RegExp(r'^\d{1,5}$').hasMatch(trimmed)) return null;
  final port = int.parse(trimmed);
  return port >= 1 && port <= 65535 ? port : null;
}

/// 全是数字与点的输入一律按 IPv4 校验（“192.168.1” 这类不完整地址不能被当成
/// 主机名放过）。
final RegExp _ipv4Like = RegExp(r'^[\d.]+$');
final RegExp _hostLabel = RegExp(
  r'^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?$',
);

bool _isValidIpv4(String host) {
  final parts = host.split('.');
  if (parts.length != 4) return false;
  for (final part in parts) {
    if (part.isEmpty || part.length > 3) return false;
    if (part.length > 1 && part.startsWith('0')) return false;
    final value = int.tryParse(part);
    if (value == null || value > 255) return false;
  }
  return true;
}
