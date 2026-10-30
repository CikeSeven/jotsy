import 'dart:convert';

import 'sync_model.dart';

/// 各实体规范化共用的小工具：时间换算、JSON 列的解析与回写、按列长截断。
///
/// 时间：库里是 Unix 秒（Drift 默认），规范值一律为 UTC 毫秒整数（规格
/// §2.1）。写回时经 [DateTime.fromMillisecondsSinceEpoch] 交给 Drift，Drift 再
/// 按秒落库，往返不丢精度（毫秒值本来就是秒 × 1000）。

/// 库里的秒 → 规范毫秒。
int syncMillisOfSeconds(int seconds) => seconds * 1000;

int? syncMillisOfSecondsOrNull(int? seconds) =>
    seconds == null ? null : seconds * 1000;

/// 规范毫秒 → 写库用的 [DateTime]。
DateTime syncDateTimeOf(Object? millis) =>
    DateTime.fromMillisecondsSinceEpoch(_asInt(millis, 'time'));

DateTime? syncDateTimeOrNullOf(Object? millis) =>
    millis == null ? null : syncDateTimeOf(millis);

/// 规范值里的整数（经 JSON 往返的整数仍是 int；防御性地接受整值浮点数）。
int syncIntOf(Object? value, String field) => _asInt(value, field);

int? syncIntOrNullOf(Object? value, String field) =>
    value == null ? null : _asInt(value, field);

int _asInt(Object? value, String field) {
  if (value is int) return value;
  if (value is double && value == value.truncateToDouble()) {
    return value.toInt();
  }
  throw FormatException('同步记录字段 $field 不是整数', value);
}

String syncStringOf(Object? value, String field) {
  if (value is String) return value;
  throw FormatException('同步记录字段 $field 不是字符串', value);
}

String? syncStringOrNullOf(Object? value, String field) =>
    value == null ? null : syncStringOf(value, field);

bool syncBoolOf(Object? value, String field) {
  if (value is bool) return value;
  throw FormatException('同步记录字段 $field 不是布尔值', value);
}

Map<String, Object?> syncMapOf(Object? value, String field) {
  if (value is Map) return value.cast<String, Object?>();
  throw FormatException('同步记录字段 $field 不是对象', value);
}

/// 按库里的原文解析一个“应当是 JSON 对象”的列（metadata、payload）。
///
/// 解析成对象时返回对象；不是合法 JSON 或不是对象（旧版本 / 手改的坏数据）时
/// 返回原文字符串：规范值里保留原文、写回时原样写回，两端逐字节一致，也不会
/// 因为同步把对方的坏数据“修”成空对象而丢掉内容。
Object syncDecodeJsonObjectColumn(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return decoded.cast<String, Object?>();
  } on FormatException {
    // 落到下面按原文保留。
  }
  return raw;
}

/// [syncDecodeJsonObjectColumn] 的逆运算：对象按规范 JSON 编码（紧凑、键排序），
/// 字符串原样返回。
String syncEncodeJsonObjectColumn(Object? value, String field) {
  if (value is Map) return syncCanonicalJson(value);
  if (value is String) return value;
  throw FormatException('同步记录字段 $field 不是对象或字符串', value);
}

/// 截断到 [maxLength] 个 UTF-16 码元（Drift `withLength` 的口径），不把代理对
/// 切成两半。
///
/// 规范化（读）与写回两个方向都截断：各设备的库都有同样的列长约束，正常数据
/// 不会超长；两边口径一致，才能保证超长的坏数据写到对方后规范值仍相同。
String syncTruncate(String value, int maxLength) {
  if (value.length <= maxLength) return value;
  var end = maxLength;
  final last = value.codeUnitAt(end - 1);
  if (last >= 0xD800 && last <= 0xDBFF) end--;
  return value.substring(0, end);
}

/// 列长上限（与各表 `withLength(max: …)` 一致，规格 §2.2）。
abstract final class SyncColumnLimits {
  static const int diaryTitle = 200;
  static const int tagName = 40;
  static const int notebookName = 60;
  static const int anniversaryTitle = 100;
}
