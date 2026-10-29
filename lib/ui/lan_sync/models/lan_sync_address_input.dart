// “手动输入地址”的校验与规整（纯函数，无副作用）。

/// 规整用户输入的主机：去掉首尾空白，合法时返回规整后的主机，否则返回 null。
///
/// 接受：点分十进制 IPv4（每段 0–255、不带前导零以免被当成八进制）、带或不带
/// 方括号的 IPv6、以及 RFC 1123 主机名（字母数字与连字符，段长 1–63、总长
/// ≤ 253，段首尾不能是连字符）。用户常把“地址:端口”一起粘贴进来，这种情况
/// 不在这里拆分——端口有单独的输入框，含冒号的 IPv4 / 主机名按不合法提示。
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
