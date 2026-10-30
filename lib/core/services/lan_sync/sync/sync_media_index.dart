import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import 'sync_media_refs.dart';
import 'sync_state_files.dart';

/// 媒体索引（`media_index.json.gz`，规格 §3）：媒体键 → 大小、修改时间、sha256。
///
/// - 输入：要描述的媒体键（`diary_images/…`、`app_backgrounds/…`），文件在
///   `<dataRoot>/<键>`；
/// - 输出：每个存在的文件的 [SyncMediaInfo]；
/// - 副作用：读写 `stateDir/media_index.json.gz`；只读媒体文件，从不改动。
///
/// sha256 一律流式计算（`sha256.bind(file.openRead())`），视频再大也不整个读进
/// 内存。大小与修改时间都没变时直接用索引里的哈希；任一变了就重算——托管
/// 媒体写入后通常不再改动，大多数会话里一次都不用重算。
///
/// 索引文件损坏时当作空（见 [SyncStateFiles]），代价只是重新计算哈希。
class SyncMediaIndex {
  SyncMediaIndex({required Directory stateDir, required this.dataRoot})
    : _files = SyncStateFiles(stateDir);

  static const String fileName = 'media_index.json.gz';
  static const int _version = 1;

  final Directory dataRoot;
  final SyncStateFiles _files;

  Map<String, SyncMediaInfo>? _entries;
  Future<void> _queue = Future<void>.value();

  /// 描述 [keys] 指向的文件；不存在的文件、不合法的键不出现在结果里，也从
  /// 索引里移除。有变化时写回索引文件。
  Future<Map<String, SyncMediaInfo>> describeAll(Iterable<String> keys) {
    return _serialized(() async {
      final entries = await _load();
      final result = <String, SyncMediaInfo>{};
      var changed = false;
      for (final key in keys.toSet()) {
        final path = syncMediaPathFor(dataRoot.path, key);
        final stat = path == null ? null : await File(path).stat();
        if (path == null || stat!.type != FileSystemEntityType.file) {
          changed |= entries.remove(key) != null;
          continue;
        }
        final modified = stat.modified.millisecondsSinceEpoch;
        final known = entries[key];
        if (known != null &&
            known.size == stat.size &&
            known.modifiedAt == modified) {
          result[key] = known;
          continue;
        }
        final info = SyncMediaInfo(
          key: key,
          size: stat.size,
          modifiedAt: modified,
          sha256: await syncSha256OfFile(File(path)),
        );
        entries[key] = info;
        result[key] = info;
        changed = true;
      }
      if (changed) await _save(entries);
      return result;
    });
  }

  /// 描述单个键；文件不存在时为 null。
  Future<SyncMediaInfo?> describe(String key) async =>
      (await describeAll(<String>[key]))[key];

  /// 只保留 [keys] 里的条目（例如当前仍被引用的媒体），其余从索引里移除。
  Future<void> retainOnly(Set<String> keys) {
    return _serialized(() async {
      final entries = await _load();
      final before = entries.length;
      entries.removeWhere((key, _) => !keys.contains(key));
      if (entries.length != before) await _save(entries);
    });
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<Map<String, SyncMediaInfo>> _load() async {
    final cached = _entries;
    if (cached != null) return cached;
    final entries = <String, SyncMediaInfo>{};
    final json = await _files.readJson(fileName);
    if (json is Map && json['v'] == _version && json['files'] is Map) {
      for (final entry in (json['files'] as Map).entries) {
        final info = SyncMediaInfo._tryFromJson(entry.key, entry.value);
        if (info != null) entries[info.key] = info;
      }
    }
    return _entries = entries;
  }

  Future<void> _save(Map<String, SyncMediaInfo> entries) =>
      _files.writeJson(fileName, <String, Object?>{
        'v': _version,
        'files': <String, Object?>{
          for (final info in entries.values) info.key: info._toJson(),
        },
      });
}

/// 一个媒体文件的大小（字节）、修改时间（UTC 毫秒）与 sha256（小写十六进制）。
@immutable
class SyncMediaInfo {
  const SyncMediaInfo({
    required this.key,
    required this.size,
    required this.modifiedAt,
    required this.sha256,
  });

  final String key;
  final int size;
  final int modifiedAt;
  final String sha256;

  static SyncMediaInfo? _tryFromJson(Object? key, Object? json) {
    if (key is! String || json is! Map) return null;
    final size = json['s'];
    final modified = json['m'];
    final hash = json['h'];
    if (size is! int || modified is! int || hash is! String) return null;
    return SyncMediaInfo(
      key: key,
      size: size,
      modifiedAt: modified,
      sha256: hash,
    );
  }

  Map<String, Object?> _toJson() => <String, Object?>{
    's': size,
    'm': modifiedAt,
    'h': sha256,
  };
}

/// 流式计算文件的 sha256（小写十六进制），不把文件整个读进内存。
Future<String> syncSha256OfFile(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();
