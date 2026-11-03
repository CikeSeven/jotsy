import 'package:flutter/foundation.dart' show debugPrint;

import 'cloud_backup_incremental_format.dart';
import 'cloud_backup_incremental_io.dart';
import 'cloud_backup_incremental_prune.dart';
import 'cloud_backup_incremental_state.dart';
import 'cloud_backup_models.dart';

/// 按保留份数清理增量备份（规划见 [planIncrementalPrune]）并同步本机的索引
/// 缓存。清理只是省空间：任何失败都只记日志，下次备份再试，不影响这次
/// 备份或删除的结果。只读本机记住的那条链（[chain]）的索引：别的链不知道
/// 密码，规划时整条链不动。
Future<void> pruneIncrementalQuietly({
  required CloudBackupLocalState state,
  required DateTime Function() clock,
  required CloudSleep sleep,
  required IncrementalRemoteIO io,
  required List<CloudBackupEntry> files,
  required int keep,
  required String? chain,
  required String? password,
}) async {
  try {
    final listing = IncrementalRemoteListing.of(files);
    final readable = <String, IncrementalIndex>{};
    for (final snapshot in retainedIncrementalSnapshots(listing, keep)) {
      if (snapshot.chain != chain) continue;
      try {
        readable[snapshot.stem] = await io.readIndex(
          snapshot.index,
          password: password,
        );
      } on Object catch (error) {
        debugPrint('cloud backup prune skips ${snapshot.stem}: $error');
      }
    }
    final plan = planIncrementalPrune(
      listing: listing,
      keep: keep,
      retainedIndexes: readable,
      now: clock(),
    );
    final deleted = <String>{};
    for (final entry in plan.deletions) {
      await withCloudRetry((_) => io.remote.delete(entry), sleep: sleep);
      deleted.add(entry.fileName);
    }
    await state.retainIndexes(io.targetId, {
      for (final snapshot in listing.snapshots)
        if (!deleted.contains(snapshot.index.fileName)) snapshot.index.fileName,
    });
  } on Object catch (error, stack) {
    debugPrint('cloud backup prune failed: $error\n$stack');
  }
}
