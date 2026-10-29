import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';

import 'sync_canonical_support.dart';
import 'sync_model.dart';
import 'sync_plan.dart';
import 'sync_plan_side.dart';
import 'sync_state_model.dart';

part 'sync_planner_copies.dart';
part 'sync_planner_decide.dart';
part 'sync_planner_keys.dart';
part 'sync_planner_lists.dart';
part 'sync_planner_merge.dart';
part 'sync_planner_notebooks.dart';
part 'sync_planner_output.dart';
part 'sync_planner_revive.dart';
part 'sync_planner_tags.dart';
part 'sync_planner_values.dart';

/// 合并判定（规格 docs/lan_sync.md §4）：发起方是唯一规划者。
///
/// - 输入：两侧的 [SyncPlanSide]（清单、按需取得的记录、分面历史、墓碑、
///   标签改名）与 [SyncPlanOptions]；
/// - 输出：[planSyncFetch] 列出还要取的数据，[planSync] 给出 [SyncPlan]（双方
///   的写入列表、标签改名、媒体候选、统计、冲突副本与待确认事项）；
/// - 纯函数：不碰数据库、文件与时钟，不用随机数；遍历一律按 [SyncKey] 排序，
///   同一份输入得到逐项相同的计划（中断后重新规划得到同一个副本 id）。
///
/// 两个入口跑的是同一条流水线（[_Planner.run]），区别只在缺数据时：
/// [planSyncFetch] 记下缺的数据、跳过依赖它的判定；[planSync] 直接抛
/// [StateError]。流水线分三段，每段结束时若记下了缺的数据就停下（后一段
/// 依赖前一段的完整结果，提前往下走只会猜着要数据）：
/// 1. 逐键判定（`_keys`）：两侧都有的逐分面判定、只有一侧有的看墓碑；
/// 2. 跨键补充（`_revive`、`_copies`、`_notebooks`）：留言复活日记、复活记录
///    的从属、冲突副本及其成员关系、日记本层级要用的定义；
/// 3. 从属收尾（`_tags`、`_notebooks`、`_lists`）：标签改名与引用、层级修复、
///    成员与章节、留言 / 纪念日的悬空引用、顺序列表、设置里的标签顺序。
/// 之后由 `_output` 对比每侧现状产出写入。典型同步（只有编辑）需要两次网络
/// 往返（历史与墓碑 → 记录）；复活与冲突副本最多再各加一次。
SyncFetchRequest planSyncFetch({
  required SyncPlanSide local,
  required SyncPlanSide remote,
  required SyncPlanOptions options,
}) {
  final planner = _Planner(local, remote, options, strict: false)..run();
  return planner.fetchRequest();
}

/// 产出同步计划。只读取 [planSyncFetch] 要过的数据；缺了必需的数据时抛
/// [StateError]（说明会话层没有按 [planSyncFetch] 取齐，是程序错误）。
SyncPlan planSync({
  required SyncPlanSide local,
  required SyncPlanSide remote,
  required SyncPlanOptions options,
}) {
  final planner = _Planner(local, remote, options, strict: true)..run();
  return planner.buildPlan();
}

/// 日记本最多嵌套的层数，与 `kNotebookMaxDepth`（`app_database_notebook_schema
/// .dart`，Drift 库的一部分，纯 Dart 的规划器引用不到）一致，测试兜底。
const int kSyncNotebookMaxDepth = 3;

/// 内置模板 id 的前缀，与 `builtInDiaryTemplateIdPrefix` 一致（测试兜底）：
/// 模板顺序列表只含用户模板。
const String kSyncBuiltInTemplatePrefix = 'builtin.';

/// settings 记录里按名称存标签顺序的分面，与 `kSyncTagOrderNamesFacet`
/// （`sync_canonical_settings.dart`，牵涉设置服务、不是纯 Dart）一致，测试兜底。
const String kSyncPlannerTagOrderFacet = 'tagOrderNames';

/// 日记 `updatedAt` 必须抬高时的步长：库里按秒存、规范值是毫秒，抬 1 毫秒
/// 写回后会被截掉，必须整整 1 秒。
const int kSyncStampBumpMillis = 1000;

/// 冲突副本标题的列长上限（与日记标题列一致）。
const int kSyncCopyTitleLimit = SyncColumnLimits.diaryTitle;

enum _Side { local, remote }

extension on _Side {
  _Side get other => this == _Side.local ? _Side.remote : _Side.local;
  SyncSideRole get role =>
      this == _Side.local ? SyncSideRole.local : SyncSideRole.remote;
}

const List<_Side> _sides = <_Side>[_Side.local, _Side.remote];

/// 一次规划的全部中间状态；各步骤以扩展的形式分在 part 文件里。
class _Planner {
  _Planner(this.local, this.remote, this.options, {required this.strict})
    : sideChoiceActive =
          options.firstSyncWithPeer ||
          local.restoredPending ||
          remote.restoredPending {
    keys = <SyncKey>{
      ...local.manifest.keys.where(participates),
      ...remote.manifest.keys.where(participates),
    }.toList()..sort();
  }

  final SyncPlanSide local;
  final SyncPlanSide remote;
  final SyncPlanOptions options;

  /// true：缺数据即抛错（[planSync]）；false：记下缺的数据（[planSyncFetch]）。
  final bool strict;

  /// “以哪边为准”是否生效（规格 §4.5）。
  final bool sideChoiceActive;

  /// 参与本次同步的全部键（两侧清单的并集），已排序。
  late final List<SyncKey> keys;

  final Set<SyncKey> _wantRemoteHistory = <SyncKey>{};
  final Set<SyncKey> _wantRemoteTombstones = <SyncKey>{};
  final Set<SyncKey> _wantRemoteRecords = <SyncKey>{};
  final Set<SyncKey> _wantLocalRecords = <SyncKey>{};

  /// 每个键（含新生成的副本与副本成员）的最终状态。
  final Map<SyncKey, _Final> finals = <SyncKey, _Final>{};

  /// 只有一侧有、判定为删除的键 → 在场一侧（复活时据此改判）。
  final Map<SyncKey, _Side> deletedFrom = <SyncKey, _Side>{};

  /// 缺失一侧有墓碑、却仍保留（或被留言复活）的键 → 保留它的一侧（§4.3）。
  final Map<SyncKey, _Side> revived = <SyncKey, _Side>{};

  /// 有没有共同祖先的冲突的记录（§4.5 计数）。
  final Set<SyncKey> ancestryLess = <SyncKey>{};

  /// 要生成冲突副本的日记 → 败方。
  final Map<SyncKey, _Side> contentLosers = <SyncKey, _Side>{};

  /// 新生成的冲突副本：副本日记的键与它的成员关系键。
  final Set<SyncKey> createdKeys = <SyncKey>{};
  final Map<String, String> copyOriginals = <String, String>{};
  final List<SyncConflictCopy> copies = <SyncConflictCopy>[];

  /// 生效的标签改名：旧名 → 最终名（已沿链解析）。
  final Map<String, String> renameMap = <String, String>{};

  /// 每侧直接采纳另一侧的值的分面 → 那个值在另一侧的确立时间
  /// （[SyncSidePlan.historySeenAt]）。
  final Map<_Side, Map<SyncKey, Map<String, int>>> inherited =
      <_Side, Map<SyncKey, Map<String, int>>>{
        _Side.local: <SyncKey, Map<String, int>>{},
        _Side.remote: <SyncKey, Map<String, int>>{},
      };

  /// 每侧的原地改名：旧名 → 新名。
  final Map<_Side, Map<String, String>> inPlaceRenames =
      <_Side, Map<String, String>>{
        _Side.local: <String, String>{},
        _Side.remote: <String, String>{},
      };

  SyncPlanSide sideOf(_Side side) => side == _Side.local ? local : remote;

  bool get _wantsData =>
      _wantRemoteHistory.isNotEmpty ||
      _wantRemoteTombstones.isNotEmpty ||
      _wantRemoteRecords.isNotEmpty ||
      _wantLocalRecords.isNotEmpty;

  /// 流水线；[planSyncFetch] 在每段结束时若缺数据就停下。
  void run() {
    computeRenames();
    resolveKeys();
    if (_wantsData) return;
    reviveByComments();
    reviveDependents();
    createCopies();
    loadNotebooks();
    if (_wantsData) return;
    resolveTags();
    resolveNotebookHierarchy();
    resolveMemberships();
    resolveCommentsAndAnniversaries();
    resolveOrderLists();
    resolveSettingsTagOrder();
  }

  SyncFetchRequest fetchRequest() => SyncFetchRequest(
    remoteHistory: _wantRemoteHistory,
    remoteTombstones: _wantRemoteTombstones,
    remoteRecords: _wantRemoteRecords,
    localRecords: _wantLocalRecords,
  );

  /// 两侧都覆盖的实体才参与；settings 只在两侧都开启“同步设置”时参与。
  bool participates(SyncKey key) => key.entity == SyncEntity.settings
      ? local.participatesInSettings && remote.participatesInSettings
      : local.entities.contains(key.entity) &&
            remote.entities.contains(key.entity);

  Map<String, String>? hashesOn(_Side side, SyncKey key) =>
      sideOf(side).manifest[key];

  bool presentOn(_Side side, SyncKey key) =>
      sideOf(side).manifest.containsKey(key);

  /// 两侧都有且各分面哈希相同。
  bool identicalOnBoth(SyncKey key) =>
      _sameHashes(local.manifest[key], remote.manifest[key]);

  /// [side] 的完整记录。没取到时：[planSync] 抛错，[planSyncFetch] 记下并
  /// 返回 null。
  SyncRecord? record(_Side side, SyncKey key) {
    final found = sideOf(side).recordOf(key);
    if (found != null) return found;
    if (!presentOn(side, key)) {
      throw StateError('同步规划读取了${side.name}一侧不存在的记录 $key');
    }
    if (strict) {
      throw StateError('同步规划缺少${side.name}一侧的记录 $key：没有按 planSyncFetch 取齐');
    }
    (side == _Side.local ? _wantLocalRecords : _wantRemoteRecords).add(key);
    return null;
  }

  /// [side] 的当前值；两侧相同时读本机记录（不走网络）。
  Map<String, Object?>? currentFacets(_Side side, SyncKey key) =>
      record(identicalOnBoth(key) ? _Side.local : side, key)?.facets;

  /// [key] 的分面历史；对方的历史没取到时同 [record] 处理。
  List<SyncHistoryEntry>? history(_Side side, SyncKey key, String facet) {
    final source = sideOf(side);
    if (source.hasHistory(key)) return source.historyOf(key, facet);
    if (strict) {
      throw StateError('同步规划缺少${side.name}一侧 $key 的历史：没有按 planSyncFetch 取齐');
    }
    if (side == _Side.local) {
      throw StateError('本机一侧必须能回答全部历史（$key）');
    }
    _wantRemoteHistory.add(key);
    return null;
  }

  /// [side] 对 [key] 的墓碑详情（调用前已确认 [SyncPlanSide.hasTombstone]）。
  SyncTombstone? tombstone(_Side side, SyncKey key) {
    final found = sideOf(side).tombstoneOf(key);
    if (found != null) return found;
    if (strict || side == _Side.local) {
      throw StateError('同步规划缺少${side.name}一侧 $key 的墓碑详情');
    }
    _wantRemoteTombstones.add(key);
    return null;
  }

  bool isPresent(SyncKey key) => finals[key]?.present ?? false;

  /// 最终值；same 读本机记录；unknown 与 absent 为 null。
  Map<String, Object?>? finalFacets(SyncKey key) {
    final state = finals[key];
    if (state == null) return null;
    return switch (state.kind) {
      _Kind.value => state.facets,
      _Kind.same => record(_Side.local, key)?.facets,
      _Kind.absent || _Kind.unknown => null,
    };
  }

  /// 平手时 deviceId 字典序较大的一侧胜出。
  _Side get tieWinner => local.deviceId.compareTo(remote.deviceId) >= 0
      ? _Side.local
      : _Side.remote;
}
