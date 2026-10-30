import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import 'sync_model.dart';

/// 媒体改键（规格 docs/lan_sync.md §6 第 2 步）：同一个媒体键在两台设备上
/// 恰好是不同的文件时，来件不覆盖本机文件，换到派生键，并改写记录里的引用。
///
/// - [SyncMediaRekey]：一次改键（旧键 → 新键，附来件的 sha256），收件一侧在
///   写入结果里报告，经会话消息告诉来源一侧照做（`SyncApplier.adoptMediaRekeys`）；
/// - [syncDerivedMediaKey]：派生键的确定性规则；
/// - [syncRewriteMediaRefs] / [syncRewriteRecordMedia]：把规范值里的
///   `jotsy-media:<旧键>` 换成新键。
///
/// 纯数据变换，不读写文件。

/// 一次媒体改键：本机把来件（sha256 为 [sha256]）放到了 [newKey]，因为
/// [oldKey] 已是另一份文件。
@immutable
class SyncMediaRekey {
  const SyncMediaRekey({
    required this.oldKey,
    required this.newKey,
    required this.sha256,
  });

  /// 从 [toJson] 的结果还原；结构不对时抛 [FormatException]。
  factory SyncMediaRekey.fromJson(Object? json) {
    if (json is! Map ||
        json['old'] is! String ||
        json['new'] is! String ||
        json['sha256'] is! String) {
      throw const FormatException('无效的媒体改键');
    }
    return SyncMediaRekey(
      oldKey: json['old'] as String,
      newKey: json['new'] as String,
      sha256: json['sha256'] as String,
    );
  }

  final String oldKey;
  final String newKey;

  /// 来件（也就是来源一侧 [oldKey] 文件）的 sha256，小写十六进制。来源一侧
  /// 照做前核对本机 [oldKey] 仍是这份文件。
  final String sha256;

  Map<String, Object?> toJson() => <String, Object?>{
    'old': oldKey,
    'new': newKey,
    'sha256': sha256,
  };

  @override
  bool operator ==(Object other) =>
      other is SyncMediaRekey &&
      other.oldKey == oldKey &&
      other.newKey == newKey &&
      other.sha256 == sha256;

  @override
  int get hashCode => Object.hash(oldKey, newKey, sha256);

  @override
  String toString() => 'SyncMediaRekey($oldKey → $newKey)';
}

/// 派生键：同一目录下 `<文件名>.<sha256 前 [hexLength] 位>.<扩展名>`
/// （`diary_images/media_x/a.jpg` → `diary_images/media_x/a.0123456789ab.jpg`）。
///
/// 只由键与内容决定：两台设备、中断重试都得到同一个键。托管媒体目录是随机
/// 生成的（`createTemp('media_')`），同键不同文件几乎只会因巧合出现，前 12 位
/// 再撞上的概率可以忽略；万一撞上，调用方改用完整的 64 位。
String syncDerivedMediaKey(String key, String sha256, {int hexLength = 12}) {
  final slash = key.lastIndexOf('/');
  final directory = slash < 0 ? '' : key.substring(0, slash + 1);
  final name = key.substring(slash + 1);
  final extension = p.extension(name);
  final stem = name.substring(0, name.length - extension.length);
  final digest = sha256.substring(0, hexLength.clamp(1, sha256.length));
  return '$directory$stem.$digest$extension';
}

/// 返回 [value] 的拷贝，其中整串 `jotsy-media:<旧键>` 换成新键（[rekeys]：
/// 旧键 → 新键）。与 [syncMediaKeysIn] 同一口径：值本身是 JSON 对象 / 数组的
/// 字符串（规范化时已按规范 JSON 重新编码）解码后递归处理，**只在确有改动时**
/// 按规范 JSON 编码回去，没改动的字符串原样保留。
Object? syncRewriteMediaRefs(Object? value, Map<String, String> rekeys) {
  if (rekeys.isEmpty) return value;
  return _rewrite(value, rekeys).value;
}

/// 改写一条记录里的引用；没有引用到任何旧键时返回 [record] 本身。
SyncRecord syncRewriteRecordMedia(
  SyncRecord record,
  Map<String, String> rekeys,
) {
  if (rekeys.isEmpty || !record.mediaKeys.any(rekeys.containsKey)) {
    return record;
  }
  final rewritten = _rewrite(record.facets, rekeys);
  if (!rewritten.changed) return record;
  return SyncRecord(record.key, (rewritten.value! as Map).cast());
}

({Object? value, bool changed}) _rewrite(
  Object? value,
  Map<String, String> rekeys,
) {
  if (value is String) return _rewriteString(value, rekeys);
  if (value is Map) {
    var changed = false;
    final out = <String, Object?>{};
    for (final entry in value.entries) {
      final item = _rewrite(entry.value, rekeys);
      changed |= item.changed;
      out[entry.key as String] = item.value;
    }
    return (value: changed ? out : value, changed: changed);
  }
  if (value is List) {
    var changed = false;
    final out = <Object?>[];
    for (final element in value) {
      final item = _rewrite(element, rekeys);
      changed |= item.changed;
      out.add(item.value);
    }
    return (value: changed ? out : value, changed: changed);
  }
  return (value: value, changed: false);
}

({Object? value, bool changed}) _rewriteString(
  String value,
  Map<String, String> rekeys,
) {
  if (!value.contains(kSyncMediaRefPrefix)) {
    return (value: value, changed: false);
  }
  if (value.startsWith(kSyncMediaRefPrefix)) {
    final mapped = rekeys[value.substring(kSyncMediaRefPrefix.length)];
    return mapped == null
        ? (value: value, changed: false)
        : (value: '$kSyncMediaRefPrefix$mapped', changed: true);
  }
  if (value.startsWith('{') || value.startsWith('[')) {
    try {
      final inner = _rewrite(jsonDecode(value), rekeys);
      if (inner.changed) {
        return (value: syncCanonicalJson(inner.value), changed: true);
      }
    } on FormatException {
      // 普通文字恰好提到前缀：原样保留。
    }
  }
  return (value: value, changed: false);
}
