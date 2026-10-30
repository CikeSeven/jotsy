import 'package:node_diary/core/services/editing_session_registry.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_apply.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_canonical_settings.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_local_state.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_manifest_builder.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_media.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_media_index.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';
import 'package:node_diary/core/services/settings_service.dart';

import 'sync_test_devices.dart';

/// 写入层测试的小工具：给 [SyncTestDevice] 装上写入层，按设备当前清单拼
/// 带前置条件的写入。

class SyncApplyRig {
  SyncApplyRig(this.device, {SettingsService? settings, Duration? undoWait})
    : state = SyncLocalState(
        database: device.db,
        stateDir: device.stateDir,
        settings: settings,
      ),
      index = SyncMediaIndex(
        stateDir: device.stateDir,
        dataRoot: device.dataRoot,
      ) {
    media = SyncMediaLibrary(dataRoot: device.dataRoot, index: index);
    applier = SyncApplier(
      database: device.db,
      dataRoot: device.dataRoot,
      state: state,
      media: media,
      settings: settings,
      registry: EditingSessionRegistry.instance,
      undoWaitTimeout: undoWait ?? const Duration(seconds: 5),
    );
  }

  final SyncTestDevice device;
  final SyncLocalState state;
  final SyncMediaIndex index;
  late final SyncMediaLibrary media;
  late final SyncApplier applier;

  /// 设备现在的清单（不含设置，除非给了 [settings] 的原值）。
  Future<SyncManifest> manifest({SyncSettingsCapture? settings}) async =>
      syncObserveRows(
        await device.db.readSyncRows(),
        settings: settings,
      ).observation.manifest;

  /// 现在的记录（[only] 为空时全部）。
  Future<Map<SyncKey, SyncRecord>> records({
    SyncSettingsCapture? settings,
  }) async => <SyncKey, SyncRecord>{
    for (final record in await device.records(settings: settings))
      record.key: record,
  };

  /// 把 [records] 写成这台设备上带前置条件的写入（expected 取现在的哈希）。
  Future<SyncSidePlan> planFor(
    Iterable<SyncRecord> records, {
    Iterable<SyncKey> deletes = const <SyncKey>[],
    List<SyncTagRenameOp> renames = const <SyncTagRenameOp>[],
    SyncSettingsCapture? settings,
    Map<SyncKey, Map<String, int>> historySeenAt =
        const <SyncKey, Map<String, int>>{},
  }) async {
    final current = await manifest(settings: settings);
    return sidePlan(
      <SyncWrite>[
        for (final record in records)
          SyncWrite(
            key: record.key,
            expected: current[record.key],
            record: record,
          ),
        for (final key in deletes)
          SyncWrite(key: key, expected: current[key], record: null),
      ],
      renames: renames,
      historySeenAt: historySeenAt,
    );
  }
}

/// 按键排序的一侧计划。
SyncSidePlan sidePlan(
  List<SyncWrite> writes, {
  List<SyncTagRenameOp> renames = const <SyncTagRenameOp>[],
  Map<SyncKey, Map<String, int>> historySeenAt =
      const <SyncKey, Map<String, int>>{},
}) => SyncSidePlan(
  writes: writes.toList()..sort((a, b) => a.key.compareTo(b.key)),
  renames: renames,
  mediaNeeded: const <String>[],
  stats: const <SyncEntity, SyncEntityCounts>{},
  historySeenAt: historySeenAt,
);

/// 改写记录的一个分面里的若干字段。
SyncRecord withFacet(
  SyncRecord record,
  String facet,
  Map<String, Object?> changes,
) => SyncRecord(record.key, <String, Object?>{
  ...record.facets,
  facet: <String, Object?>{
    ...(record.facets[facet]! as Map).cast<String, Object?>(),
    ...changes,
  },
});
