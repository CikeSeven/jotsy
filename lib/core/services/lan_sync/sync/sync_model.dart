import 'dart:convert';
import 'dart:io' show gzip;

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

/// 局域网同步的规范记录模型（规格见 docs/lan_sync.md §2.1）。
///
/// - 输入：各实体的规范 JSON 值（已做媒体路径归一，由 `sync_canonical_*.dart`
///   从数据库行生成）；
/// - 输出：记录身份 [SyncKey]、规范记录 [SyncRecord]（分面值 + 惰性哈希 + 引用
///   的媒体键）、清单 [SyncManifest]（每条记录各分面的哈希，可 JSON / gzip
///   编解码）；
/// - 无副作用，只依赖纯 Dart 包：规划器（纯函数）与它的测试直接使用这些类型，
///   不能牵进 Flutter 或 Drift。
///
/// 规范形式一旦改变（分面的组成、归一规则、哈希算法），两端算出的哈希就对不上，
/// 必须同时提升 [kSyncFormatVersion]：版本不同的设备在握手时互相拒绝，而不是
/// 把每条记录都判成冲突。
const int kSyncFormatVersion = 1;

/// 规范值里托管媒体引用的前缀：`jotsy-media:diary_images/media_x/a.jpg`。
const String kSyncMediaRefPrefix = 'jotsy-media:';

/// 参与同步的实体。枚举名即 [SyncKey] 字符串形式里的实体名，改名等同于改协议。
enum SyncEntity {
  diary,
  tag,
  notebook,
  membership,
  orderList,
  comment,
  template,
  anniversary,
  dayMood,
  settings;

  static SyncEntity? tryParse(String name) => values.asNameMap()[name];
}

/// 各实体的分面名（规格 §2.2）。
abstract final class SyncFacet {
  // diary
  static const String content = 'content';
  static const String stamp = 'stamp';
  static const String pin = 'pin';
  static const String archive = 'archive';
  static const String trash = 'trash';
  static const String capsule = 'capsule';
  static const String tags = 'tags';

  // tag
  static const String color = 'color';

  // notebook
  static const String definition = 'definition';

  // membership / comment / template / anniversary / dayMood
  static const String main = 'main';

  // orderList
  static const String items = 'items';

  /// 历史里同时记录值（而不只是哈希）的分面：三方合并要用到共同祖先的值
  /// （规格 §3、§4.1）。
  static bool tracksValue(SyncEntity entity, String facet) =>
      (entity == SyncEntity.diary && facet == tags) ||
      (entity == SyncEntity.orderList && facet == items);
}

/// orderList 记录的 id。
abstract final class SyncOrderListId {
  /// 书架：日记本的手动顺序。
  static const String shelf = 'shelf';

  /// 我的模板的手动顺序（只含用户模板，不含 `builtin.*`）。
  static const String templates = 'templates';

  static const String _bookPrefix = 'book:';

  /// 手动日记本的书序。
  static String book(String notebookId) => '$_bookPrefix$notebookId';

  /// [listId] 是书序列表时返回日记本业务 id，否则为 null。
  static String? notebookOf(String listId) => listId.startsWith(_bookPrefix)
      ? listId.substring(_bookPrefix.length)
      : null;
}

/// 向用户报告变化时 [key] 归在哪一种数据下（完成摘要、同步记录、“以哪边
/// 为准”的明细）：收录与书架 / 书序归日记本，“我的模板”的顺序归模板，
/// 其余即自身的实体。
SyncEntity syncSummaryEntityOf(SyncKey key) => switch (key.entity) {
  SyncEntity.membership => SyncEntity.notebook,
  SyncEntity.orderList =>
    key.id == SyncOrderListId.templates
        ? SyncEntity.template
        : SyncEntity.notebook,
  _ => key.entity,
};

/// settings 记录的唯一 id。
const String kSyncSettingsId = 'settings';

/// 成员关系记录的 id：`<notebookId>|<diaryId>`（两者都是业务 id，UUID 里没有 `|`）。
String syncMembershipId(String notebookId, String diaryId) =>
    '$notebookId|$diaryId';

/// 拆开成员关系 id；格式不对时为 null。
({String notebookId, String diaryId})? parseSyncMembershipId(String id) {
  final index = id.indexOf('|');
  if (index <= 0 || index == id.length - 1) return null;
  return (notebookId: id.substring(0, index), diaryId: id.substring(index + 1));
}

/// 记录身份：实体 + 业务 id。字符串形式 `<entity>:<id>`；id 本身可以含冒号
/// （`orderList:book:<id>`、带冒号的标签名），解析时只按第一个冒号拆分。
@immutable
class SyncKey implements Comparable<SyncKey> {
  const SyncKey(this.entity, this.id);

  final SyncEntity entity;
  final String id;

  /// 解析 `<entity>:<id>`；实体名认不出或格式不对时抛 [FormatException]。
  factory SyncKey.parse(String raw) {
    final key = tryParse(raw);
    if (key == null) throw FormatException('无效的同步记录键', raw);
    return key;
  }

  static SyncKey? tryParse(String raw) {
    final index = raw.indexOf(':');
    if (index <= 0) return null;
    final entity = SyncEntity.tryParse(raw.substring(0, index));
    if (entity == null) return null;
    return SyncKey(entity, raw.substring(index + 1));
  }

  @override
  bool operator ==(Object other) =>
      other is SyncKey && other.entity == entity && other.id == id;

  @override
  int get hashCode => Object.hash(entity, id);

  /// 先按实体枚举顺序、再按 id（UTF-16 码元）排序，供确定性遍历。
  @override
  int compareTo(SyncKey other) {
    final byEntity = entity.index.compareTo(other.entity.index);
    return byEntity != 0 ? byEntity : id.compareTo(other.id);
  }

  @override
  String toString() => '${entity.name}:$id';
}

/// 一条规范记录：分面名 → 规范 JSON 值（已做媒体路径归一，见规格 §2.3）。
///
/// [facets] 构造时做浅层只读拷贝；里面的值由调用方保证不再被改动（哈希与
/// 媒体键都是惰性算一次后缓存的）。
class SyncRecord {
  SyncRecord(this.key, Map<String, Object?> facets)
    : facets = Map<String, Object?>.unmodifiable(facets);

  /// 从 [toJson] 的结果还原；结构不对时抛 [FormatException]。
  factory SyncRecord.fromJson(Object? json) {
    if (json is! Map || json['k'] is! String || json['f'] is! Map) {
      throw const FormatException('无效的同步记录');
    }
    return SyncRecord(
      SyncKey.parse(json['k'] as String),
      (json['f'] as Map).cast<String, Object?>(),
    );
  }

  final SyncKey key;
  final Map<String, Object?> facets;

  Map<String, String>? _hashes;
  Set<String>? _mediaKeys;

  /// 分面名 → 哈希（[syncHashValue]）。
  Map<String, String> get hashes =>
      _hashes ??= Map<String, String>.unmodifiable(<String, String>{
        for (final entry in facets.entries)
          entry.key: syncHashValue(entry.value),
      });

  /// 这条记录引用的托管媒体键（`diary_images/…`、`app_backgrounds/…`），
  /// 由同一套规范值遍历得出（[syncMediaKeysIn]），供传输阶段决定要搬哪些文件。
  Set<String> get mediaKeys =>
      _mediaKeys ??= Set<String>.unmodifiable(syncMediaKeysIn(facets));

  /// 传输用 JSON：`{"k": 键, "f": 分面}`。
  Map<String, Object?> toJson() => <String, Object?>{
    'k': key.toString(),
    'f': facets,
  };

  @override
  String toString() => 'SyncRecord($key)';
}

/// 清单：每条记录各分面的哈希。
class SyncManifest {
  SyncManifest(
    Map<SyncKey, Map<String, String>> entries, {
    this.formatVersion = kSyncFormatVersion,
  }) : entries = Map<SyncKey, Map<String, String>>.unmodifiable(
         entries.map(
           (key, value) =>
               MapEntry(key, Map<String, String>.unmodifiable(value)),
         ),
       );

  factory SyncManifest.fromRecords(Iterable<SyncRecord> records) =>
      SyncManifest(<SyncKey, Map<String, String>>{
        for (final record in records) record.key: record.hashes,
      });

  /// 从 [toJson] 的结果还原。实体名认不出时抛 [FormatException] 而不是跳过：
  /// 跳过会让对方的记录在本机看来“缺失”，进而被当成删除。格式版本不同的
  /// 两端本应在握手时就互相拒绝，走到这里说明数据损坏。
  factory SyncManifest.fromJson(Object? json) {
    if (json is! Map || json['v'] is! int || json['entries'] is! Map) {
      throw const FormatException('无效的同步清单');
    }
    final entries = <SyncKey, Map<String, String>>{};
    for (final entry in (json['entries'] as Map).entries) {
      final hashes = entry.value;
      if (entry.key is! String || hashes is! Map) {
        throw const FormatException('无效的同步清单条目');
      }
      entries[SyncKey.parse(entry.key as String)] = <String, String>{
        for (final facet in hashes.entries)
          if (facet.key is String && facet.value is String)
            facet.key as String: facet.value as String,
      };
    }
    return SyncManifest(entries, formatVersion: json['v'] as int);
  }

  /// gzip 压缩的 JSON（[encodeGzip] 的逆运算）。
  factory SyncManifest.decodeGzip(List<int> bytes) =>
      SyncManifest.fromJson(jsonDecode(utf8.decode(gzip.decode(bytes))));

  final int formatVersion;
  final Map<SyncKey, Map<String, String>> entries;

  Map<String, String>? operator [](SyncKey key) => entries[key];

  bool containsKey(SyncKey key) => entries.containsKey(key);

  Iterable<SyncKey> get keys => entries.keys;

  int get length => entries.length;

  /// 键按 [SyncKey.compareTo] 排序后输出，同一份清单的 JSON 逐字节相同。
  Map<String, Object?> toJson() {
    final keys = entries.keys.toList()..sort();
    return <String, Object?>{
      'v': formatVersion,
      'entries': <String, Object?>{
        for (final key in keys) key.toString(): entries[key],
      },
    };
  }

  List<int> encodeGzip() =>
      gzip.encode(utf8.encode(syncCanonicalJson(toJson())));
}

/// 规范 JSON：对象键按 UTF-16 码元升序（Dart [String.compareTo] 即此序）、
/// 无空白。值只能是 JSON 类型（Map 的键必须是字符串），否则抛 [ArgumentError]。
///
/// 整数与浮点数沿用 `jsonEncode` 的写法（`1` 与 `1.0` 不同）：两端都是 Dart，
/// 写法一致；规范值经 JSON 往返后仍是同一种数字，规范串不变。
String syncCanonicalJson(Object? value) {
  final buffer = StringBuffer();
  _writeCanonical(buffer, value);
  return buffer.toString();
}

void _writeCanonical(StringBuffer buffer, Object? value) {
  if (value is Map) {
    final keys = <String>[];
    for (final key in value.keys) {
      if (key is! String) {
        throw ArgumentError.value(key, 'key', '规范 JSON 的对象键必须是字符串');
      }
      keys.add(key);
    }
    keys.sort();
    buffer.write('{');
    for (var i = 0; i < keys.length; i++) {
      if (i > 0) buffer.write(',');
      buffer
        ..write(jsonEncode(keys[i]))
        ..write(':');
      _writeCanonical(buffer, value[keys[i]]);
    }
    buffer.write('}');
  } else if (value is List) {
    buffer.write('[');
    for (var i = 0; i < value.length; i++) {
      if (i > 0) buffer.write(',');
      _writeCanonical(buffer, value[i]);
    }
    buffer.write(']');
  } else if (value == null ||
      value is String ||
      value is num ||
      value is bool) {
    buffer.write(jsonEncode(value));
  } else {
    throw ArgumentError.value(value, 'value', '不是 JSON 值');
  }
}

/// 规范串的哈希：`sha256(utf8(规范 JSON))` 取前 16 字节，小写十六进制 32 位。
String syncHash(String canonicalJson) {
  final digest = sha256.convert(utf8.encode(canonicalJson));
  return _hex(digest.bytes.sublist(0, 16));
}

/// [value] 的规范 JSON 的哈希。
String syncHashValue(Object? value) => syncHash(syncCanonicalJson(value));

String _hex(List<int> bytes) {
  final buffer = StringBuffer();
  for (final byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

/// 规范值里引用到的托管媒体键。
///
/// 规范值里的引用一律是整串 `jotsy-media:<键>`；嵌在“值是 JSON 的字符串”
/// 里的引用（附件 metadata、背景设置）同样认出：这类字符串在规范化时已经
/// 按规范 JSON 重新编码，以 `{` / `[` 开头。
Set<String> syncMediaKeysIn(Object? value) {
  final keys = <String>{};
  _collectMediaKeys(value, keys);
  return keys;
}

void _collectMediaKeys(Object? value, Set<String> out) {
  if (value is String) {
    if (!value.contains(kSyncMediaRefPrefix)) return;
    if (value.startsWith(kSyncMediaRefPrefix)) {
      final key = value.substring(kSyncMediaRefPrefix.length);
      if (key.isNotEmpty) out.add(key);
      return;
    }
    if (value.startsWith('{') || value.startsWith('[')) {
      try {
        _collectMediaKeys(jsonDecode(value), out);
      } on FormatException {
        // 不是 JSON 的普通文字：只是恰好提到了前缀。
      }
    }
  } else if (value is Map) {
    for (final item in value.values) {
      _collectMediaKeys(item, out);
    }
  } else if (value is List) {
    for (final item in value) {
      _collectMediaKeys(item, out);
    }
  }
}
