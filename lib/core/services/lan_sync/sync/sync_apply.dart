import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../database/app_database.dart';
import '../../backup_settings.dart';
import '../../data_archive_service.dart';
import '../../editing_session_registry.dart';
import '../../settings_service.dart';
import 'sync_canonical_diary.dart';
import 'sync_canonical_misc.dart';
import 'sync_canonical_notebook.dart';
import 'sync_canonical_settings.dart';
import 'sync_local_state.dart';
import 'sync_media.dart';
import 'sync_model.dart';
import 'sync_plan.dart';

part 'sync_apply_result.dart';
part 'sync_apply_settings.dart';
part 'sync_apply_writes.dart';

/// 新建标签的默认颜色（Material Grey 500）。日记按名称建出的标签随后由同一
/// 计划里 `tag:` 记录的写入定下颜色；那条写入被跳过时才会留着这个中性色，
/// 下次同步按标签的颜色分面照常合并。
const int kSyncNewTagColor = 0xFF9E9E9E;

/// 同步写入层（规格 docs/lan_sync.md §6）：把一侧的 [SyncSidePlan] 落到本机。
///
/// - 输入（构造注入）：数据库、数据根目录、本机同步状态 [SyncLocalState]
///   （状态目录在它里面）、媒体库（取文件的 sha256、照做改键）、设置服务
///   （只在同步设置时需要）；不解析任何真实目录，测试里一个进程可以跑两台
///   “设备”；
/// - 输出：[SyncApplyResult]（跳过的条目、改键、写入后的清单、统计）；
/// - 副作用：媒体就位、单个 Drift 事务里的全部数据库写入、设置、`stateDir`
///   里的历史 / 墓碑 / 检查点，最后发出 [EditingSessionRegistry.notifyDataReplaced]。
///
/// [apply] 的顺序（每一步为什么在这里，见方法里的注释）：
/// 1. 等撤销窗口关闭，超时即推迟、什么都不写；
/// 2. 媒体就位（事务之前），同键不同文件的来件换键并改写本次要写的记录；
/// 3. 在 [DataArchiveService.runSerialized] 里开**一个**事务：读行算出当前
///    清单 → 比对全部前置条件 → 原地改名 → 按计划写入 → 顺序列表 → 再读行；
/// 4. 提交后应用设置（失败回滚设置，数据库写入保留）；
/// 5. 用写入后的观测 `recordAppliedState`（带计划的 `historySeenAt`），
///    发出写入后事件；暂存目录无论成败都删除。
///
/// 失败语义：第 3 步里任何异常回滚这一侧的全部数据库写入、不更新同步状态
/// （下次同步重新规划即可）；第 2 步已就位的媒体文件留着、没有记录引用，
/// 由媒体回收（按修改时间的宽限期）收走。
///
/// 并发：会话期间同一个 [SyncLocalState] 不能同时被别处调用——第 3 步在事务
/// 里调用它的 `observeRows`，它的队列里若排着要读库的操作，会与事务互相等待。
class SyncApplier {
  SyncApplier({
    required this.database,
    required this.dataRoot,
    required this.state,
    required this.media,
    this.settings,
    EditingSessionRegistry? registry,
    this.undoWaitTimeout = const Duration(seconds: 15),
  }) : registry = registry ?? EditingSessionRegistry.instance;

  final AppDatabase database;
  final Directory dataRoot;
  final SyncLocalState state;
  final SyncMediaLibrary media;
  final SettingsService? settings;
  final EditingSessionRegistry registry;

  /// 等撤销窗口关闭的最长时间。撤销提示通常只显示几秒，超过就推迟本次同步，
  /// 而不是在用户还能点“撤销”时改掉数据（撤销会把同步写入的内容覆盖回去）。
  final Duration undoWaitTimeout;

  /// 执行一侧的计划。[staging] 为本次会话收到的媒体（没有媒体时为 null），
  /// 结束时一律删除。
  ///
  /// [includeSettings] 为本次会话是否同步设置（两端都开启）；默认取“计划里
  /// 有没有设置写入”。会话同步设置时应显式传 true：标签改名会改变设置里
  /// 按名称的标签顺序，写入后的观测要带上设置才记得准。
  Future<SyncApplyResult> apply(
    SyncSidePlan plan, {
    SyncMediaStaging? staging,
    bool? includeSettings,
  }) async {
    try {
      // 1. 撤销窗口：提示还开着时用户可能点“撤销”，把旧内容写回、覆盖同步
      //    刚写入的值；先等它关闭。超时就推迟，什么都不写（暂存件也丢掉，
      //    下次同步重新传）。
      final ready = await registry.waitForUndoWindows(timeout: undoWaitTimeout);
      if (!ready) return SyncApplyResult.deferred();

      // 2. 媒体在事务之前就位：记录写进库的那一刻文件必须已经在（界面随时
      //    可能读到新记录）。同键不同文件的来件换了键，本次要写的记录里的
      //    引用跟着改；改过的分面不再是另一侧的原值，不继承历史时间。
      final placement = await staging?.place() ?? const SyncMediaPlacement();
      final rekeys = placement.rekeyMap;
      final rewrittenFacets = <SyncKey, Set<String>>{};
      final writes = <SyncWrite>[];
      for (final write in plan.writes) {
        final record = write.record;
        final rewritten = record == null
            ? null
            : syncRewriteRecordMedia(record, rekeys);
        if (rewritten == null || identical(rewritten, record)) {
          writes.add(write);
          continue;
        }
        rewrittenFacets[write.key] = <String>{
          for (final facet in rewritten.facets.keys)
            if (rewritten.hashes[facet] != record!.hashes[facet]) facet,
        };
        writes.add(
          SyncWrite(
            key: write.key,
            expected: write.expected,
            record: rewritten,
          ),
        );
      }

      final withSettings =
          includeSettings ??
          writes.any((write) => write.key.entity == SyncEntity.settings);
      if (withSettings && settings == null) {
        throw StateError('同步设置需要在构造 SyncApplier 时传入 SettingsService');
      }

      final result = await DataArchiveService.runSerialized(
        () => _applyLocked(
          plan,
          writes,
          withSettings: withSettings,
          rewrittenFacets: rewrittenFacets,
        ),
      );
      return SyncApplyResult(
        status: SyncApplyStatus.applied,
        skipped: result.skipped,
        rekeys: placement.rekeys,
        manifest: result.manifest,
        counts: result.counts,
        mediaFiles: placement.placedFiles,
        mediaBytes: placement.placedBytes,
      );
    } finally {
      await staging?.dispose();
    }
  }

  /// 来源一侧照做对方报告的改键（[SyncApplyResult.rekeys]）：把本机 `oldKey`
  /// 的文件拷到 `newKey`，再把本机所有引用 `oldKey` 的记录改写为 `newKey`，
  /// 让两边的规范记录逐字节相同。
  ///
  /// 改写经 [apply] 的同一条路径（前置条件 = 现在的哈希、单事务、写入后折叠
  /// 进同步状态），所以必须在本机自己的 [apply] 之后调用：那时本机收到的
  /// 记录已在库里，引用 `oldKey` 的都是本机这份文件。本机 `oldKey` 已不是
  /// 对方收到的那份文件时跳过这一条（文件在此期间被换掉）。
  Future<SyncApplyResult> adoptMediaRekeys(
    List<SyncMediaRekey> rekeys, {
    bool includeSettings = false,
  }) async {
    final adoptable = await media.copyForAdoption(rekeys);
    if (adoptable.isEmpty) {
      return SyncApplyResult(status: SyncApplyStatus.applied);
    }
    final map = <String, String>{
      for (final rekey in adoptable) rekey.oldKey: rekey.newKey,
    };
    final settingsService = settings;
    final observed = await state.observeRows(
      await database.readSyncRows(),
      settingsCaptured: includeSettings && settingsService != null
          ? syncCaptureSettings(settingsService)
          : null,
    );
    final records = await state.buildRecords(observed.manifest.keys);
    final writes = <SyncWrite>[];
    for (final record in records) {
      final rewritten = syncRewriteRecordMedia(record, map);
      if (identical(rewritten, record)) continue;
      writes.add(
        SyncWrite(key: record.key, expected: record.hashes, record: rewritten),
      );
    }
    writes.sort((a, b) => a.key.compareTo(b.key));
    return apply(
      SyncSidePlan(
        writes: writes,
        renames: const <SyncTagRenameOp>[],
        mediaNeeded: const <String>[],
        stats: const <SyncEntity, SyncEntityCounts>{},
      ),
      includeSettings: includeSettings,
    );
  }

  /// 第 3–5 步，在 [DataArchiveService.runSerialized] 里执行：与备份导入、
  /// 覆盖恢复共用一个串行队列，不会与恢复事务交错。
  Future<_LockedResult> _applyLocked(
    SyncSidePlan plan,
    List<SyncWrite> writes, {
    required bool withSettings,
    required Map<SyncKey, Set<String>> rewrittenFacets,
  }) async {
    final skipped = <SyncApplySkip>[];
    final prepared = <_PreparedWrite>[];
    for (final write in writes) {
      try {
        prepared.add(
          _prepareWrite(
            write,
            dataRoot: dataRoot.path,
            newTagColor: kSyncNewTagColor,
          ),
        );
      } on FormatException catch (error) {
        debugPrint('LAN sync write ${write.key} invalid: $error');
        skipped.add(SyncApplySkip(write.key, SyncSkipReason.invalidRecord));
      } on ArgumentError catch (error) {
        debugPrint('LAN sync write ${write.key} invalid: $error');
        skipped.add(SyncApplySkip(write.key, SyncSkipReason.invalidRecord));
      }
    }
    final renames = <_PreparedRename>[];
    for (final rename in plan.renames) {
      try {
        renames.add(_PreparedRename(rename));
      } on FormatException {
        skipped.add(
          SyncApplySkip(
            SyncKey(SyncEntity.tag, rename.from),
            SyncSkipReason.invalidRecord,
          ),
        );
      }
    }

    // 3. 单个事务。当前清单在事务里由刚读出的行算出（哈希缓存命中时很便宜），
    //    前置条件与写入看到的是同一份状态；写完再读一次行，提交后的库就是它。
    final settingsService = settings;
    final outcome = await database.transaction(() async {
      final current = await state.observeRows(
        await database.readSyncRows(),
        settingsCaptured: withSettings
            ? syncCaptureSettings(settingsService!)
            : null,
      );
      return _runWrites(
        database,
        current: current.manifest,
        renames: renames,
        writes: prepared,
      );
    });
    skipped.addAll(outcome.skipped);

    // 4. 设置在提交之后应用：SharedPreferences 不在 Drift 事务里，放在前面
    //    的话数据库回滚时设置已经改了。设置失败只回滚设置。
    final performed = <SyncWrite>[];
    for (final write in outcome.performed) {
      if (write.key.entity != SyncEntity.settings) {
        performed.add(write);
        continue;
      }
      final ok = await _applySyncSettings(
        settingsService!,
        write.record!,
        facets: _changedSettingsFacets(write),
        tagIdsByName: <String, int>{
          for (final tag in outcome.rowsAfter.tags)
            syncTagRecordName(tag): tag.localId,
        },
        dataRoot: dataRoot.path,
      );
      if (ok) {
        performed.add(write);
      } else {
        skipped.add(SyncApplySkip(write.key, SyncSkipReason.settingsFailed));
      }
    }

    // 5. 写入后的观测：库的部分用事务里最后读出的行（就是提交后的状态），
    //    设置在应用（或回滚）之后取值。historySeenAt 只传真正写了的键、且
    //    没被改键改过的分面：跳过的键若因用户编辑而变了，旧值的时间应当是
    //    现在，不能套用另一侧的确立时间（规格 §4.1.1）。
    final after = await state.observeRows(
      outcome.rowsAfter,
      settingsCaptured: withSettings
          ? syncCaptureSettings(settingsService!)
          : null,
    );
    await state.recordAppliedState(
      after,
      historySeenAt: _inheritedSeenAt(plan, performed, rewrittenFacets),
    );
    final counts = _countPerformed(performed, outcome.renamed);
    if (counts.isNotEmpty) registry.notifyDataReplaced();
    return _LockedResult(skipped, after.manifest, counts);
  }
}
