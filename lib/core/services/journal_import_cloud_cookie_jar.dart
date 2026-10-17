import 'dart:io';

/// 最小 Cookie 罐：按域名（含子域）与路径匹配，吸收 Set-Cookie 的新增、
/// 覆盖与删除（Max-Age<=0 或已过期）。
class CloudCookieJar {
  final List<_JarCookie> _cookies = <_JarCookie>[];

  /// 从网页视图读到的 `name=value; …`（只知道它对 [host] 生效），按仅限
  /// 该主机的 Cookie 加入。
  ///
  /// 同名同值的 Cookie 已从 [host] 的父域名主机（或子域名主机）读到时，它
  /// 是覆盖两者的域 Cookie（如荣耀以 `Domain=cloud.honor.com` 下发的登录
  /// Cookie 也发往文件服务 `fileproxy-drcn.cloud.honor.com`），合并为父主机
  /// 的一条域 Cookie：服务端按该域轮换 Set-Cookie 时替换的是同一条，不会
  /// 在子主机上留下旧值，让 [value] 因多个不同值读不到。
  void addHeader(String host, String header) {
    final target = host.toLowerCase();
    for (final pair in header.split(';')) {
      final index = pair.indexOf('=');
      if (index <= 0) continue;
      final name = pair.substring(0, index).trim();
      final value = pair.substring(index + 1).trim();
      final shared = _cookies
          .where(
            (cookie) =>
                cookie.name == name &&
                cookie.value == value &&
                cookie.path == '/' &&
                (_isSubdomain(target, cookie.domain) ||
                    _isSubdomain(cookie.domain, target)),
          )
          .firstOrNull;
      if (shared == null) {
        _put(_JarCookie(name, value, target, hostOnly: true));
        continue;
      }
      _cookies.remove(shared);
      _put(
        _JarCookie(
          name,
          value,
          _isSubdomain(target, shared.domain) ? shared.domain : target,
          hostOnly: false,
        ),
      );
    }
  }

  static bool _isSubdomain(String host, String parent) =>
      host.endsWith('.$parent');

  /// 写入或替换只对 [host] 生效的 Cookie；同名的其他条目一并移除，罐中
  /// 只留这一个值。
  void set(String name, String value, String host) {
    _cookies.removeWhere((cookie) => cookie.name == name);
    _put(_JarCookie(name, value, host.toLowerCase(), hostOnly: true));
  }

  /// 直接加入一条 Cookie（对 [domain] 及其子域生效）。
  void add(String name, String value, String domain, {String path = '/'}) {
    final normalized = domain.toLowerCase();
    _put(
      _JarCookie(
        name,
        value,
        normalized.replaceFirst(RegExp(r'^\.'), ''),
        hostOnly: false,
        path: path,
      ),
    );
  }

  String? header(Uri url) {
    final host = url.host.toLowerCase();
    final path = url.path.isEmpty ? '/' : url.path;
    final matched = [
      for (final cookie in _cookies)
        if (cookie.matches(host, path)) cookie,
    ];
    if (matched.isEmpty) return null;
    return matched.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
  }

  void absorb(Uri url, List<String> setCookies) {
    for (final raw in setCookies) {
      final parts = raw.split(';');
      final first = parts.first;
      final index = first.indexOf('=');
      if (index <= 0) continue;
      var domain = url.host.toLowerCase();
      var hostOnly = true;
      var path = '/';
      var expired = false;
      for (final attribute in parts.skip(1)) {
        final separator = attribute.indexOf('=');
        final key =
            (separator < 0 ? attribute : attribute.substring(0, separator))
                .trim()
                .toLowerCase();
        final value = separator < 0
            ? ''
            : attribute.substring(separator + 1).trim();
        switch (key) {
          case 'domain' when value.isNotEmpty:
            domain = value.toLowerCase().replaceFirst(RegExp(r'^\.'), '');
            hostOnly = false;
          case 'path' when value.startsWith('/'):
            path = value;
          case 'max-age':
            if ((int.tryParse(value) ?? 1) <= 0) expired = true;
          case 'expires':
            final date = _parseHttpDate(value);
            if (date != null && date.isBefore(DateTime.now())) expired = true;
        }
      }
      final cookie = _JarCookie(
        first.substring(0, index).trim(),
        first.substring(index + 1).trim(),
        domain,
        hostOnly: hostOnly,
        path: path,
      );
      if (expired) {
        _cookies.removeWhere((item) => item.sameSlot(cookie));
      } else {
        _put(cookie);
      }
    }
  }

  String? value(String name) {
    final values = {
      for (final cookie in _cookies)
        if (cookie.name == name) cookie.value,
    };
    return values.length == 1 ? values.single : null;
  }

  void clear() => _cookies.clear();

  void _put(_JarCookie cookie) {
    _cookies
      ..removeWhere((item) => item.sameSlot(cookie))
      ..add(cookie);
  }

  static DateTime? _parseHttpDate(String value) {
    try {
      return HttpDate.parse(value);
    } on FormatException {
      return null;
    }
  }
}

class _JarCookie {
  _JarCookie(
    this.name,
    this.value,
    this.domain, {
    required this.hostOnly,
    this.path = '/',
  });

  final String name;
  final String value;
  final String domain;
  final bool hostOnly;
  final String path;

  bool matches(String host, String requestPath) {
    final domainOk = hostOnly
        ? host == domain
        : host == domain || host.endsWith('.$domain');
    return domainOk && requestPath.startsWith(path);
  }

  bool sameSlot(_JarCookie other) =>
      name == other.name && domain == other.domain && path == other.path;
}
