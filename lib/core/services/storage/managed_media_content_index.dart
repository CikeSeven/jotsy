import 'dart:io';

import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

import '../lan_sync/sync/sync_media_index.dart';

/// 托管媒体的内容哈希缓存，导入时复用（`ManagedMediaDedup`）与存储管理的
/// 重复文件共用一份。
///
/// 复用局域网同步的 [SyncMediaIndex]（按大小 + 修改时间缓存 sha256，流式
/// 计算），与同步、网盘备份的实例各用各的目录：`<数据根>/media_dedup_state/`。
/// 这里只是缓存：不随备份、不被恢复覆盖，删掉只会让下次重新计算。缓存可能
/// 过期（覆盖恢复换进了同名同大小的文件），所以真正复用或合并之前，调用方
/// 一律再按文件内容直接算一次核对。
abstract final class ManagedMediaContentIndex {
  static const String directoryName = 'media_dedup_state';

  static final Map<String, SyncMediaIndex> _byRoot = <String, SyncMediaIndex>{};

  /// [root] 这个数据根目录的索引（同一进程内同一个实例，保证读写串行）。
  static SyncMediaIndex forRoot(Directory root) => _byRoot.putIfAbsent(
    p.normalize(root.absolute.path),
    () => SyncMediaIndex(
      stateDir: Directory(p.join(root.path, directoryName)),
      dataRoot: root,
    ),
  );

  /// 清空进程内索引实例缓存（数据位置迁移或测试复位时调用）。
  static void clearCache() => _byRoot.clear();

  @visibleForTesting
  static void debugReset() => clearCache();
}
