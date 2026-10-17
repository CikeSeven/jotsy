import 'package:meta/meta.dart';

import 'app_update_preferences.dart';

/// 访问 GitHub 的一条线路：直连，或在原地址前加镜像前缀
/// （`https://ghfast.top/https://github.com/...`）。
///
/// 国内网络下 github.com 的附件下载常被限速到几 KB/s 甚至不可达，
/// api.github.com 还按出口 IP 限流（运营商 NAT 后很多人共用一个 IP），
/// 所以检查与下载都以镜像为主、直连为辅，并由用户兜底填写自定义镜像。
/// 新增内置镜像只改 [builtInSources]。
@immutable
class AppUpdateSource {
  const AppUpdateSource(this.id, this.prefix);

  /// 用户填写的镜像前缀；格式不合法时返回 null。
  static AppUpdateSource? custom(String? prefix) {
    final normalized = normalizeMirrorPrefix(prefix);
    return normalized == null ? null : AppUpdateSource(customId, normalized);
  }

  static const String directId = 'direct';
  static const String customId = 'custom';

  static const AppUpdateSource direct = AppUpdateSource(directId, null);

  /// 内置线路，顺序即没有测速记录时的默认优先级。镜像均为公共服务、
  /// 随时可能失效，因此始终多条并用，失效的在竞速里自然落选。
  static const List<AppUpdateSource> builtInSources = <AppUpdateSource>[
    AppUpdateSource('ghfast', 'https://ghfast.top/'),
    AppUpdateSource('gh-proxy', 'https://gh-proxy.com/'),
    AppUpdateSource('llkk', 'https://gh.llkk.cc/'),
    AppUpdateSource('ghproxy-net', 'https://ghproxy.net/'),
    direct,
  ];

  final String id;

  /// 镜像前缀（以 `/` 结尾），直连为 null。
  final String? prefix;

  bool get isDirect => prefix == null;

  /// 界面上显示的名称：直连由界面本地化，镜像显示域名。
  String get host => prefix == null ? 'github.com' : Uri.parse(prefix!).host;

  Uri wrap(Uri source) => prefix == null ? source : Uri.parse('$prefix$source');

  /// 校验并规范化镜像前缀：只接受 http(s) 且带域名，补齐末尾的 `/`。
  /// 用户可能粘贴整条示例地址（`https://x.com/https://github.com/...`），
  /// 只取到内层地址之前的前缀部分。
  static String? normalizeMirrorPrefix(String? raw) {
    var value = raw?.trim() ?? '';
    // 从第 8 个字符起找，跳过前缀自身的 `https://`。
    final nested = value.length <= 8
        ? -1
        : value.indexOf(RegExp('https?://', caseSensitive: false), 8);
    if (nested > 0) {
      value = value.substring(0, nested);
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    final text = uri.toString();
    return text.endsWith('/') ? text : '$text/';
  }

  /// 按偏好排出本次要用的线路。
  ///
  /// - 自动：内置线路 + 自定义镜像（填了的话），上次可用的线路排最前；
  /// - 指定线路：该线路排最前，其余仍作后备——用户指定的线路临时不可用时，
  ///   比起直接失败，换条线路继续更符合预期。
  static List<AppUpdateSource> ordered(AppUpdatePreferences preferences) {
    final custom = AppUpdateSource.custom(preferences.customMirror);
    final pool = <AppUpdateSource>[?custom, ...builtInSources];
    final preferredId = preferences.sourceId == AppUpdatePreferences.autoSource
        ? preferences.lastGoodSourceId
        : preferences.sourceId;
    final preferred = pool.where((source) => source.id == preferredId);
    return <AppUpdateSource>{...preferred, ...pool}.toList(growable: false);
  }

  @override
  bool operator ==(Object other) =>
      other is AppUpdateSource && other.id == id && other.prefix == prefix;

  @override
  int get hashCode => Object.hash(id, prefix);

  @override
  String toString() => 'AppUpdateSource($id)';
}
