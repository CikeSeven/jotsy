import 'dart:convert';

import 'saved_style.dart';

/// 样式码解析结果的类别。
enum StyleCodeStatus {
  ok,

  /// 新版本应用导出的样式码：按当前版本逐字段容错解析，认不出的字段回退
  /// 默认值，界面应提示“部分样式可能未生效”。
  newerVersion,
  invalid,
  empty,
}

class StyleCodeResult<S> {
  const StyleCodeResult(this.status, {this.style, this.name});

  final StyleCodeStatus status;
  final S? style;

  /// 导出时附带的样式名（可能为空）。
  final String? name;
}

/// 样式码：便于用户经剪贴板分享与导入一套样式。
///
/// 格式：`<scheme>:v<版本>:<base64url(JSON)>`，JSON 为
/// `{"v":版本,"n":名称?,"s":稀疏样式}`，去掉 base64 补位等号。不压缩：样式
/// 本身稀疏，通常只有几百字节，且 gzip 在 Web 上不可用。
///
/// 解析时在任意文本中查找第一个本格式的样式码（分享时常附带说明文字），
/// 超过 [maxLength] 的输入直接拒绝，避免粘贴巨量文本时卡顿。[scheme] 区分
/// 样式种类：卡片样式码贴到预览页样式里会被当作无效码。
class StyleCodeFormat<S> {
  StyleCodeFormat({
    required this.scheme,
    required this.version,
    required this.fromJson,
    required this.toJson,
  }) : _pattern = RegExp(
         '${RegExp.escape(scheme)}:v(\\d{1,4}):([A-Za-z0-9_-]+)',
       );

  static const int maxLength = 16 * 1024;

  final String scheme;
  final int version;
  final S Function(Object? json) fromJson;
  final Object Function(S style) toJson;
  final RegExp _pattern;

  String encode(S style, {String? name}) {
    final normalizedName = name == null ? '' : SavedStyles.normalizeName(name);
    final payload = <String, Object>{
      'v': version,
      if (normalizedName.isNotEmpty) 'n': normalizedName,
      's': toJson(style),
    };
    final data = base64Url
        .encode(utf8.encode(jsonEncode(payload)))
        .replaceAll('=', '');
    return '$scheme:v$version:$data';
  }

  StyleCodeResult<S> decode(String? text) {
    if (text == null || text.trim().isEmpty) {
      return StyleCodeResult<S>(StyleCodeStatus.empty);
    }
    final invalid = StyleCodeResult<S>(StyleCodeStatus.invalid);
    if (text.length > maxLength) {
      return invalid;
    }
    final match = _pattern.firstMatch(text);
    if (match == null) {
      return invalid;
    }
    final codeVersion = int.parse(match.group(1)!);
    var data = match.group(2)!;
    final remainder = data.length % 4;
    if (remainder == 1) {
      return invalid;
    }
    if (remainder != 0) {
      data += '=' * (4 - remainder);
    }
    try {
      final decoded = jsonDecode(utf8.decode(base64Url.decode(data)));
      if (decoded is! Map || decoded['s'] is! Map) {
        return invalid;
      }
      final rawName = decoded['n'];
      final name = rawName is String ? SavedStyles.normalizeName(rawName) : '';
      return StyleCodeResult<S>(
        codeVersion > version
            ? StyleCodeStatus.newerVersion
            : StyleCodeStatus.ok,
        style: fromJson(decoded['s']),
        name: name.isEmpty ? null : name,
      );
    } catch (_) {
      return invalid;
    }
  }
}
