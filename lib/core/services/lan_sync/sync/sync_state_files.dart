import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// 同步状态目录（`stateDir`）里 gzip JSON 文件的读写。
///
/// - 写：先写同目录下的临时文件（`<名>.tmp`），flush 后改名覆盖。同一文件
///   系统内的改名是原子的，写到一半断电 / 被杀也只会留下旧文件或临时文件，
///   不会留下半个 JSON；
/// - 读：文件不存在、解压失败、不是 JSON —— 一律当作“没有”，debugPrint 后
///   返回 null，从不抛出。为什么这样是安全的：这些文件只是同步的“记忆”
///   （检查点、历史、墓碑、改名、缓存）。丢了它们，下次规划时找不到共同
///   祖先，会把更多分面判为真冲突、按并集合并或生成冲突副本；没有墓碑的
///   记录会被对方复制回来（删除不传播）。最坏结果是多出数据，不会丢数据。
class SyncStateFiles {
  const SyncStateFiles(this.directory);

  final Directory directory;

  File fileOf(String name) => File(p.join(directory.path, name));

  /// 读出 [name] 的 JSON；不存在或损坏时为 null。
  Future<Object?> readJson(String name) async {
    final file = fileOf(name);
    try {
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return jsonDecode(utf8.decode(gzip.decode(bytes)));
    } catch (error) {
      debugPrint('LAN sync state file $name unreadable, discarded: $error');
      return null;
    }
  }

  /// 原子写入 [name]（gzip JSON）。
  Future<void> writeJson(String name, Object? json) async {
    await directory.create(recursive: true);
    final target = fileOf(name);
    final temp = File('${target.path}.tmp');
    await temp.writeAsBytes(
      gzip.encode(utf8.encode(jsonEncode(json))),
      flush: true,
    );
    await temp.rename(target.path);
  }

  /// 删除 [name]（及可能残留的临时文件）；不存在时什么也不做。删除失败照常
  /// 抛出：覆盖恢复后留下旧检查点，会把恢复造成的差异误记成本机编辑。
  Future<void> delete(String name) async {
    for (final file in <File>[fileOf(name), File('${fileOf(name).path}.tmp')]) {
      if (await file.exists()) await file.delete();
    }
  }
}
