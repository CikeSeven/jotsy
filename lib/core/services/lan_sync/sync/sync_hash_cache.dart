import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import '../../../database/sync_rows.dart';
import 'sync_model.dart';

/// 哈希缓存（`hash_cache.json.gz`，规格 §3）：记录键 → 原始列指纹 + 规范
/// 分面哈希。
///
/// 计算清单时，先对每行的原始列算指纹（一次流式 sha256，便宜），指纹与缓存
/// 相同就直接取分面哈希，省掉解码正文、归一路径、规范编码这些重活。按记录
/// 键而不是按指纹做索引：缓存每次整份重写、只留当前存在的行，按键索引天然
/// 做到这一点，同一行的新旧指纹也不会同时留在缓存里。
///
/// 规范化规则变了（[kSyncCanonicalRevision]）或格式版本变了，旧缓存整份作废。

/// 规范化实现的修订号。改动任何会影响规范值的代码（不改变协议、只修正本机
/// 实现）时提升它，让各设备重算一遍而不是继续用旧哈希。
const int kSyncCanonicalRevision = 1;

@immutable
class SyncHashCacheEntry {
  const SyncHashCacheEntry(this.fingerprint, this.hashes);

  final String fingerprint;
  final Map<String, String> hashes;
}

/// 缓存文件的 JSON 形态 ↔ 内存。版本不符、结构不对时返回空缓存。
Map<String, SyncHashCacheEntry> syncHashCacheFromJson(Object? json) {
  if (json is! Map ||
      json['v'] != kSyncFormatVersion ||
      json['r'] != kSyncCanonicalRevision ||
      json['rows'] is! Map) {
    return <String, SyncHashCacheEntry>{};
  }
  final rows = <String, SyncHashCacheEntry>{};
  for (final entry in (json['rows'] as Map).entries) {
    final value = entry.value;
    if (entry.key is! String ||
        value is! List ||
        value.length != 2 ||
        value[0] is! String ||
        value[1] is! Map) {
      continue;
    }
    rows[entry.key
        as String] = SyncHashCacheEntry(value[0] as String, <String, String>{
      for (final facet in (value[1] as Map).entries)
        if (facet.key is String && facet.value is String)
          facet.key as String: facet.value as String,
    });
  }
  return rows;
}

Map<String, Object?> syncHashCacheToJson(
  Map<String, SyncHashCacheEntry> rows,
) => <String, Object?>{
  'v': kSyncFormatVersion,
  'r': kSyncCanonicalRevision,
  'rows': <String, Object?>{
    for (final entry in rows.entries)
      entry.key: <Object?>[entry.value.fingerprint, entry.value.hashes],
  },
};

/// 原始列指纹：按类型标记 + 长度前缀把各列依次喂进 sha256，避免
/// `("ab", "c")` 与 `("a", "bc")` 这样的拼接歧义，也不需要先拼出一个大字符串。
class SyncFingerprint {
  SyncFingerprint() {
    _input = sha256.startChunkedConversion(_output);
  }

  final _DigestSink _output = _DigestSink();
  late final ByteConversionSink _input;

  void string(String? value) {
    if (value == null) {
      _input.add(const <int>[0]);
      return;
    }
    final bytes = utf8.encode(value);
    _input
      ..add(const <int>[1])
      ..add(_length(bytes.length))
      ..add(bytes);
  }

  void integer(int? value) {
    if (value == null) {
      _input.add(const <int>[0]);
      return;
    }
    final bytes = utf8.encode(value.toString());
    _input
      ..add(const <int>[2])
      ..add(_length(bytes.length))
      ..add(bytes);
  }

  void boolean(bool value) => _input.add(<int>[value ? 4 : 3]);

  /// 结束并返回指纹（sha256 前 16 字节的十六进制）。之后不能再写入。
  String finish() {
    _input.close();
    final bytes = _output.digest!.bytes;
    final buffer = StringBuffer();
    for (final byte in bytes.take(16)) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static List<int> _length(int length) =>
      (ByteData(4)..setUint32(0, length)).buffer.asUint8List();
}

class _DigestSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}

// ---- 各表的原始列指纹：日记不含 content_text（不参与哈希），其余为全部业务列 ----

String syncDiaryFingerprint(SyncRawDiary row) =>
    (SyncFingerprint()
          ..string(row.diaryId)
          ..string(row.title)
          ..string(row.content)
          ..string(row.cover)
          ..string(row.metadata)
          ..integer(row.createdAt)
          ..integer(row.updatedAt)
          ..boolean(row.isArchived)
          ..integer(row.archivedAt)
          ..boolean(row.isPinned)
          ..integer(row.capsuleUnlockAt)
          ..integer(row.capsuleLockedAt)
          ..boolean(row.isDeleted)
          ..integer(row.deletedAt))
        .finish();

String syncNotebookFingerprint(SyncRawNotebook row) =>
    (SyncFingerprint()
          ..string(row.notebookId)
          ..string(row.name)
          ..string(row.kind)
          ..string(row.visibility)
          ..string(row.payload)
          ..boolean(row.isPinned)
          ..boolean(row.isClosed)
          ..integer(row.createdAt)
          ..integer(row.updatedAt)
          ..string(row.parentId))
        .finish();

String syncTemplateFingerprint(SyncRawTemplate row) =>
    (SyncFingerprint()
          ..string(row.templateId)
          ..string(row.name)
          ..string(row.payload)
          ..integer(row.createdAt)
          ..integer(row.updatedAt))
        .finish();

String syncAnniversaryFingerprint(SyncRawAnniversary row) =>
    (SyncFingerprint()
          ..string(row.anniversaryId)
          ..string(row.title)
          ..string(row.baseDate)
          ..string(row.recurrence)
          ..integer(row.lunarYear)
          ..integer(row.lunarMonth)
          ..integer(row.lunarDay)
          ..string(row.linkedDiaryId)
          ..string(row.note)
          ..boolean(row.isPinned)
          ..string(row.metadata)
          ..integer(row.createdAt)
          ..integer(row.updatedAt))
        .finish();
