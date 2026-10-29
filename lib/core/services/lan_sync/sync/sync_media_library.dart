import 'dart:io';

import 'package:meta/meta.dart';

import 'sync_media_index.dart';
import 'sync_media_refs.dart';
import 'sync_media_rekey.dart';

/// 本机托管媒体的读取（发送）与改键照做（来源一侧），规格 docs/lan_sync.md
/// §6 第 2 步。
///
/// - 输入：数据根目录、媒体索引（sha256 按大小与修改时间缓存）；
/// - 输出：[SyncOutgoingMedia]（流、大小、sha256）、可照做的改键；
/// - 副作用：只在照做改键时新建 `newKey` 文件，从不覆盖或删除已有媒体。

/// 发送一个本机媒体文件所需的信息。
@immutable
class SyncOutgoingMedia {
  const SyncOutgoingMedia({
    required this.key,
    required this.size,
    required this.sha256,
    required this.file,
  });

  final String key;
  final int size;
  final String sha256;
  final File file;

  /// 流式读取，不把文件整个读进内存。读取期间文件若被改动，收件方的
  /// [SyncMediaStaging.verify] 会因 sha256 不符而拒收。
  Stream<List<int>> openRead() => file.openRead();
}

/// 本机托管媒体的读取与改键照做（来源一侧）。
class SyncMediaLibrary {
  SyncMediaLibrary({
    required this.dataRoot,
    required this.index,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Directory dataRoot;
  final SyncMediaIndex index;
  final DateTime Function() _clock;

  /// 本机这些键的大小与 sha256（`media.have` 的应答）；没有的键不在结果里。
  Future<Map<String, SyncMediaInfo>> describe(Iterable<String> keys) =>
      index.describeAll(keys);

  /// 打开 [key] 准备发送；文件不存在时为 null。
  Future<SyncOutgoingMedia?> open(String key) async {
    final info = await index.describe(key);
    final path = syncMediaPathFor(dataRoot.path, key);
    if (info == null || path == null) return null;
    return SyncOutgoingMedia(
      key: key,
      size: info.size,
      sha256: info.sha256,
      file: File(path),
    );
  }

  /// 照对方的改键把本机 `oldKey` 的文件拷一份到 `newKey`（同样的字节），返回
  /// 可以照做的改键：本机 `oldKey` 必须仍是 `sha256` 那份文件；`newKey` 已有
  /// 同样内容时复用，已是另一份文件（几乎不可能）时跳过这一条。
  ///
  /// 拷贝先写到同目录的临时文件再改名，中途失败不会留下半个 `newKey`；临时
  /// 文件没人引用，媒体回收会收走。旧文件不删：之后改写记录可能被跳过。
  Future<List<SyncMediaRekey>> copyForAdoption(
    Iterable<SyncMediaRekey> rekeys,
  ) async {
    final adoptable = <SyncMediaRekey>[];
    for (final rekey in rekeys) {
      final oldPath = syncMediaPathFor(dataRoot.path, rekey.oldKey);
      final newPath = syncMediaPathFor(dataRoot.path, rekey.newKey);
      if (oldPath == null || newPath == null) continue;
      final current = await index.describe(rekey.oldKey);
      if (current == null || current.sha256 != rekey.sha256) continue;
      final existing = await index.describe(rekey.newKey);
      if (existing != null) {
        if (existing.sha256 == rekey.sha256) adoptable.add(rekey);
        continue;
      }
      final temp = File('$newPath.lan_sync_tmp');
      await temp.parent.create(recursive: true);
      await File(oldPath).copy(temp.path);
      await temp.rename(newPath);
      await File(newPath).setLastModified(_clock());
      adoptable.add(rekey);
    }
    return adoptable;
  }
}
