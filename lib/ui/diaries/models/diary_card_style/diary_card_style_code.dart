import 'dart:convert';

import 'diary_card_style.dart';
import 'diary_card_style_settings.dart';

/// 样式码解析结果的类别。
enum DiaryCardStyleCodeStatus {
  ok,

  /// 新版本应用导出的样式码：按当前版本逐字段容错解析，认不出的字段回退
  /// 默认值，界面应提示“部分样式可能未生效”。
  newerVersion,
  invalid,
  empty,
}

class DiaryCardStyleCodeResult {
  const DiaryCardStyleCodeResult._(this.status, {this.style, this.name});

  final DiaryCardStyleCodeStatus status;
  final DiaryCardStyle? style;

  /// 导出时附带的样式名（可能为空）。
  final String? name;
}

/// 卡片样式码：便于用户通过剪贴板分享与导入样式。
///
/// 格式：`jotsy-card:v<版本>:<base64url(JSON)>`，JSON 为
/// `{"v":1,"n":名称?,"s":稀疏样式}`，去掉 base64 补位等号。
/// 不压缩：样式本身稀疏、通常只有几百字节，且 gzip 在 Web 上不可用。
///
/// 解析时在任意文本中查找第一个样式码（分享时常附带说明文字），超过
/// [maxLength] 的输入直接拒绝，避免粘贴巨量文本时卡顿。
abstract final class DiaryCardStyleCode {
  static const String scheme = 'jotsy-card';
  static const int version = 1;
  static const int maxLength = 16 * 1024;
  static final RegExp _pattern = RegExp(
    r'jotsy-card:v(\d{1,4}):([A-Za-z0-9_-]+)',
  );

  static String encode(DiaryCardStyle style, {String? name}) {
    final normalizedName = name == null
        ? ''
        : DiaryCardStyleSettings.normalizeName(name);
    final payload = <String, Object>{
      'v': version,
      if (normalizedName.isNotEmpty) 'n': normalizedName,
      's': style.toJson(),
    };
    final data = base64Url
        .encode(utf8.encode(jsonEncode(payload)))
        .replaceAll('=', '');
    return '$scheme:v$version:$data';
  }

  static DiaryCardStyleCodeResult decode(String? text) {
    if (text == null || text.trim().isEmpty) {
      return const DiaryCardStyleCodeResult._(DiaryCardStyleCodeStatus.empty);
    }
    const invalid = DiaryCardStyleCodeResult._(
      DiaryCardStyleCodeStatus.invalid,
    );
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
      final name = rawName is String
          ? DiaryCardStyleSettings.normalizeName(rawName)
          : '';
      return DiaryCardStyleCodeResult._(
        codeVersion > version
            ? DiaryCardStyleCodeStatus.newerVersion
            : DiaryCardStyleCodeStatus.ok,
        style: DiaryCardStyle.fromJson(decoded['s']),
        name: name.isEmpty ? null : name,
      );
    } catch (_) {
      return invalid;
    }
  }
}
