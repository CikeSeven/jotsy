import 'dart:io';

import 'package:drift/native.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_apply.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_local_plan_side.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_local_state.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_manifest_builder.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_media.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_media_index.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_model.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_plan_side.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_planner.dart';
import 'package:node_diary/core/services/lan_sync/sync/sync_state_model.dart';
import 'package:path/path.dart' as p;

/// 局域网同步端到端测试的两台（或多台）“设备”与一轮同步的完整流程。
///
/// 每台设备有自己的内存数据库、数据根目录、状态目录、[SyncLocalState]、
/// 媒体索引与 [SyncApplier]；不经网络，按会话层（docs/lan_sync.md §5.3）的
/// 顺序直接调用：刷新检查点 → 取数循环 → `planSync` → 传媒体 → 对方写入 →
/// 本机写入 → 双方照做对方的改键。经真正会话与服务的端到端测试见
/// test/core/services/lan_sync/lan_sync_session_harness.dart 与
/// lan_sync_e2e_harness.dart（它们复用这里的数据库与目录）。
///
/// 不含设置：同一进程里的两个 `SettingsService` 共用 SharedPreferences 单例。

/// 两台设备共用的假时钟：每次读取前进 1 秒，保证历史时间可复现、互不相同。
class LanSyncTestClock {
  LanSyncTestClock([DateTime? start])
    : _now = start ?? DateTime.utc(2026, 10, 1);

  DateTime _now;

  DateTime call() => _now = _now.add(const Duration(seconds: 1));
}

class LanSyncTestDevice {
  LanSyncTestDevice._({
    required this.deviceId,
    required this.root,
    required this.dataRoot,
    required this.stateDir,
    required this.db,
    required this.state,
    required this.index,
    required this.media,
    required this.applier,
  });

  static Future<LanSyncTestDevice> create(
    String deviceId, {
    required LanSyncTestClock clock,
  }) async {
    final root = await Directory.systemTemp.createTemp('jotsy_lan_$deviceId');
    final dataRoot = await Directory(p.join(root.path, 'data')).create();
    final stateDir = Directory(p.join(root.path, 'state'));
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final state = SyncLocalState(
      database: db,
      stateDir: stateDir,
      clock: clock.call,
    );
    final index = SyncMediaIndex(stateDir: stateDir, dataRoot: dataRoot);
    final media = SyncMediaLibrary(dataRoot: dataRoot, index: index);
    return LanSyncTestDevice._(
      deviceId: deviceId,
      root: root,
      dataRoot: dataRoot,
      stateDir: stateDir,
      db: db,
      state: state,
      index: index,
      media: media,
      applier: SyncApplier(
        database: db,
        dataRoot: dataRoot,
        state: state,
        media: media,
      ),
    );
  }

  final String deviceId;
  final Directory root;
  final Directory dataRoot;
  final Directory stateDir;
  final AppDatabase db;
  final SyncLocalState state;
  final SyncMediaIndex index;
  final SyncMediaLibrary media;
  final SyncApplier applier;

  int _sessions = 0;

  /// 托管媒体键在这台设备上的绝对路径。
  String mediaPath(String key) =>
      p.joinAll(<String>[dataRoot.path, ...key.split('/')]);

  /// 写一个托管媒体文件，返回它的绝对路径（供正文 / 封面引用）。
  Future<String> writeMedia(String key, List<int> bytes) async {
    final file = File(mediaPath(key));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// 当前的全部规范记录（不含设置）。
  Future<List<SyncRecord>> records() async =>
      syncBuildRecords(await db.readSyncRows());

  /// 记录键 → 规范 JSON，便于逐字节比较两台设备。
  Future<Map<String, String>> canonical() async {
    final sorted = (await records())..sort((a, b) => a.key.compareTo(b.key));
    return <String, String>{
      for (final record in sorted)
        record.key.toString(): syncCanonicalJson(record.facets),
    };
  }

  SyncMediaStaging newStaging() => SyncMediaStaging(
    dataRoot: dataRoot,
    sessionId: '$deviceId-${++_sessions}',
    index: index,
  );

  Future<void> dispose() async {
    await db.close();
    await root.delete(recursive: true);
  }
}

/// 一轮同步的结果。
class LanSyncRound {
  LanSyncRound({
    required this.plan,
    required this.initiatorResult,
    required this.responderResult,
    required this.initiatorAdopt,
    required this.responderAdopt,
  });

  final SyncPlan plan;

  /// 没有执行的一侧为 null（模拟中断）。
  final SyncApplyResult? initiatorResult;
  final SyncApplyResult? responderResult;
  final SyncApplyResult? initiatorAdopt;
  final SyncApplyResult? responderAdopt;
}

/// 规划一轮：两侧刷新检查点，跑完取数循环后 `planSync`。[initiator] 是
/// 本机一侧（[SyncLocalPlanSide]），[responder] 的数据像经网络取得那样逐步
/// 填进 [SyncPlanSideData]。
Future<SyncPlan> planLanSyncRound(
  LanSyncTestDevice initiator,
  LanSyncTestDevice responder, {
  SyncPlanOptions options = const SyncPlanOptions(nowMillis: 0),
}) async {
  final mine = await initiator.state.refreshCheckpoint();
  final theirs = await responder.state.refreshCheckpoint();
  final local = SyncLocalPlanSide(deviceId: initiator.deviceId, snapshot: mine);
  final remote = SyncPlanSideData(
    deviceId: responder.deviceId,
    manifest: theirs.manifest,
    entities: local.entities,
    tombstoneKeys: theirs.tombstoneKeys,
    renames: theirs.renames,
  );
  while (true) {
    final request = planSyncFetch(
      local: local,
      remote: remote,
      options: options,
    );
    if (request.isEmpty) break;
    await local.loadRecords(initiator.state, request.localRecords);
    remote
      ..addRecords(await responder.state.buildRecords(request.remoteRecords))
      ..addHistory(<SyncKey, Map<String, List<SyncHistoryEntry>>>{
        for (final key in request.remoteHistory) key: theirs.historyOf(key),
      })
      ..addTombstones(<SyncKey, SyncTombstone>{
        for (final key in request.remoteTombstones) key: theirs.tombstone(key)!,
      });
  }
  return planSync(local: local, remote: remote, options: options);
}

/// 一轮完整的同步（会话层的顺序）：
/// 1. 规划；
/// 2. 对方先写：从本机传它缺的媒体（sha256 相同的不传），执行 `plan.remote`；
/// 3. 本机再写：从对方传本机缺的媒体，执行 `plan.local`；
/// 4. 双方照做对方报告的改键（各自在自己的写入之后）。
/// [applyInitiator] / [applyResponder] 为 false 时跳过那一侧（模拟中断）。
Future<LanSyncRound> runLanSyncRound(
  LanSyncTestDevice initiator,
  LanSyncTestDevice responder, {
  SyncPlanOptions options = const SyncPlanOptions(nowMillis: 0),
  bool applyInitiator = true,
  bool applyResponder = true,
}) async {
  final plan = await planLanSyncRound(initiator, responder, options: options);
  SyncApplyResult? responderResult;
  SyncApplyResult? initiatorResult;
  if (applyResponder) {
    responderResult = await responder.applier.apply(
      plan.remote,
      staging: await transferLanSyncMedia(
        plan.remote.mediaNeeded,
        from: initiator,
        to: responder,
      ),
    );
  }
  if (applyInitiator) {
    initiatorResult = await initiator.applier.apply(
      plan.local,
      staging: await transferLanSyncMedia(
        plan.local.mediaNeeded,
        from: responder,
        to: initiator,
      ),
    );
  }
  final initiatorAdopt = responderResult == null || !applyInitiator
      ? null
      : await initiator.applier.adoptMediaRekeys(responderResult.rekeys);
  final responderAdopt = initiatorResult == null || !applyResponder
      ? null
      : await responder.applier.adoptMediaRekeys(initiatorResult.rekeys);
  return LanSyncRound(
    plan: plan,
    initiatorResult: initiatorResult,
    responderResult: responderResult,
    initiatorAdopt: initiatorAdopt,
    responderAdopt: responderAdopt,
  );
}

/// `media.have` + `media.get`：把 [to] 没有、或 sha256 不同的候选文件从
/// [from] 流式写进 [to] 的暂存区并校验。没有要传的文件时为 null。
Future<SyncMediaStaging?> transferLanSyncMedia(
  List<String> candidates, {
  required LanSyncTestDevice from,
  required LanSyncTestDevice to,
}) async {
  if (candidates.isEmpty) return null;
  final have = await to.media.describe(candidates);
  final staging = to.newStaging();
  var any = false;
  for (final key in candidates) {
    final outgoing = await from.media.open(key);
    if (outgoing == null || have[key]?.sha256 == outgoing.sha256) continue;
    await staging.receive(
      key,
      outgoing.openRead(),
      size: outgoing.size,
      sha256: outgoing.sha256,
    );
    any = true;
  }
  if (any) return staging;
  await staging.dispose();
  return null;
}
