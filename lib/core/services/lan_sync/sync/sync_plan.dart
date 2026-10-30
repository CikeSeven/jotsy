import 'package:meta/meta.dart';

import 'sync_model.dart';

/// 同步规划的输入选项与产出（规格 docs/lan_sync.md §4.5、§4.6）。
///
/// 纯数据类型：规划器（`sync_planner.dart`）产出 [SyncPlan]，会话层据此决定
/// 是否需要用户确认，写入层（`sync_apply.dart`）按其中的写入列表落库。
/// 没有副作用，不牵进 Flutter 与 Drift。

/// 没有共同祖先的冲突怎么处理（规格 §4.5“以哪边为准”）。
enum SyncSideChoice {
  /// 保留两份：日记正文冲突生成冲突副本，其余分面按变化时间取较新者。
  keepBoth,

  /// 以本机（发起方）为准：这些冲突直接取本机的值，不生成副本。
  preferLocal,

  /// 以对方为准。
  preferRemote,
}

/// 规划时的选项。规划器不读时钟，时间只经 [nowMillis] 传入。
@immutable
class SyncPlanOptions {
  const SyncPlanOptions({
    required this.nowMillis,
    this.firstSyncWithPeer = false,
    this.localLoserTitleSuffix = '',
    this.remoteLoserTitleSuffix = '',
    this.sideChoice = SyncSideChoice.keepBoth,
  });

  /// 规划时刻（UTC 毫秒）。规则本身不依赖它：同一份输入无论何时规划结果都
  /// 相同（中断后重新规划要得到同一个副本 id），只供调用方记录。
  final int nowMillis;

  /// 本次是不是与这台设备的第一次同步。
  final bool firstSyncWithPeer;

  /// 冲突副本标题的后缀，按副本保存的是哪一侧的版本（败方）选用：本机
  /// （发起方）败时用 [localLoserTitleSuffix]，对方败时用
  /// [remoteLoserTitleSuffix]。由界面层本地化后传入，写明那一侧的设备名
  /// （如“（冲突副本 · ThinkPad）”），用户一看就知道副本是哪台上的版本。
  /// 只影响副本的标题，不影响副本 id：换一台发起方、换一种语言重新规划，
  /// 副本 id 仍然相同。
  final String localLoserTitleSuffix;
  final String remoteLoserTitleSuffix;

  /// 只在“以哪边为准”生效时（首次同步或任一侧刚做过覆盖恢复）作用于没有
  /// 共同祖先的冲突；其余情况一律按 [SyncSideChoice.keepBoth] 的规则处理。
  final SyncSideChoice sideChoice;
}

/// 写入计划里的一侧。
enum SyncSideRole { local, remote }

/// 一条写入：把 [key] 写成 [record]（null 为删除）。
///
/// [expected] 是规划时这一侧该记录的分面哈希（null 表示规划时不存在）。写入层
/// 在**事务开始时、执行任何写入（含标签改名）之前**逐条比对：本机当前哈希与
/// [expected] 不同就跳过这一条（`skipped`，下次同步再处理）。
@immutable
class SyncWrite {
  const SyncWrite({
    required this.key,
    required this.expected,
    required this.record,
  });

  final SyncKey key;
  final Map<String, String>? expected;
  final SyncRecord? record;

  bool get isDelete => record == null;
  bool get isInsert => expected == null && record != null;

  @override
  String toString() =>
      'SyncWrite($key, ${expected == null ? 'new' : 'update'}'
      '${record == null ? ', delete' : ''})';
}

/// 标签原地改名：把这一侧名为 [from] 的标签改名为 [to]，本地 id 不变，再把
/// 颜色设为 [record] 的值（规格 §4.2、§6）。
///
/// 规划时这一侧有 `tag:[from]`（哈希为 [expected]）、没有 `tag:[to]`；这一侧的
/// 写入列表里**没有** `tag:[from]` 的删除和 `tag:[to]` 的新增，改名就是这两条。
/// 前置条件与 [SyncWrite] 一同在事务开始时比对（`from` 的哈希等于 [expected]
/// 且 `to` 不存在），不满足就跳过。引用旧名的日记写入（tags 分面已换成新名）
/// 的 expected 是改名前的哈希，因此必须先比对、再改名、再写。
@immutable
class SyncTagRenameOp {
  const SyncTagRenameOp({
    required this.from,
    required this.to,
    required this.expected,
    required this.record,
  });

  final String from;
  final String to;
  final Map<String, String> expected;

  /// `tag:[to]` 的最终规范记录。
  final SyncRecord record;

  @override
  String toString() => 'SyncTagRenameOp($from → $to)';
}

/// 一类实体在一侧的新增 / 更新 / 删除条数。
@immutable
class SyncEntityCounts {
  const SyncEntityCounts({this.added = 0, this.updated = 0, this.deleted = 0});

  final int added;
  final int updated;
  final int deleted;

  int get total => added + updated + deleted;

  SyncEntityCounts plus({int added = 0, int updated = 0, int deleted = 0}) =>
      SyncEntityCounts(
        added: this.added + added,
        updated: this.updated + updated,
        deleted: this.deleted + deleted,
      );

  @override
  bool operator ==(Object other) =>
      other is SyncEntityCounts &&
      other.added == added &&
      other.updated == updated &&
      other.deleted == deleted;

  @override
  int get hashCode => Object.hash(added, updated, deleted);

  @override
  String toString() => '+$added ~$updated -$deleted';
}

/// 一侧要执行的全部操作。
@immutable
class SyncSidePlan {
  SyncSidePlan({
    required List<SyncWrite> writes,
    required List<SyncTagRenameOp> renames,
    required List<String> mediaNeeded,
    required Map<SyncEntity, SyncEntityCounts> stats,
    Map<SyncKey, Map<String, int>> historySeenAt =
        const <SyncKey, Map<String, int>>{},
  }) : writes = List<SyncWrite>.unmodifiable(writes),
       renames = List<SyncTagRenameOp>.unmodifiable(renames),
       mediaNeeded = List<String>.unmodifiable(mediaNeeded),
       stats = Map<SyncEntity, SyncEntityCounts>.unmodifiable(stats),
       historySeenAt = Map<SyncKey, Map<String, int>>.unmodifiable(
         historySeenAt.map(
           (key, facets) =>
               MapEntry(key, Map<String, int>.unmodifiable(facets)),
         ),
       );

  /// 按 [SyncKey] 排序（实体枚举顺序：日记 → 标签 → 日记本 → 成员 → 顺序
  /// 列表 → 留言 → …）。
  final List<SyncWrite> writes;

  /// 按旧名排序；比对前置条件之后、执行 [writes] 之前进行。
  final List<SyncTagRenameOp> renames;

  /// 这一侧需要从另一侧取得的媒体键候选（排序）：写入的记录里、哈希有变化
  /// 的分面引用到的媒体键。只是候选——这一侧可能已经有同样的文件，写入层
  /// 经 `media.have` 按 sha256 核对后只传缺的。
  final List<String> mediaNeeded;

  /// 每类实体的统计（只含有变化的实体；原地改名记为标签的更新）。
  final Map<SyncEntity, SyncEntityCounts> stats;

  /// 写入后折叠（规格 §3“写入后”）时，这些键的这些分面被换掉的旧值进历史
  /// 用的 `seenAt`——另一侧这个值的确立时间（它的历史头条 seenAt，没有历史
  /// 时用记录自身的时间字段），而不是写入时刻。
  ///
  /// 只含“直接采纳了另一侧的值”的分面（合并出的新值、由从属关系改出的值
  /// 照常用写入时刻）。不继承的话，每次同步采纳都会给值刷新一个最新的时间，
  /// 三台以上设备之间“来回改过”的值会按采纳顺序无休止地翻转（规格 §4.1）。
  final Map<SyncKey, Map<String, int>> historySeenAt;

  /// 彻底删除的日记数（删除保护用）。
  int get diaryDeletions => stats[SyncEntity.diary]?.deleted ?? 0;

  bool get isEmpty => writes.isEmpty && renames.isEmpty;
}

/// 一份新生成的冲突副本：[originalId] 的败方版本写成了 [copyId]。
@immutable
class SyncConflictCopy {
  const SyncConflictCopy({
    required this.originalId,
    required this.copyId,
    required this.title,
    required this.loser,
  });

  final String originalId;
  final String copyId;
  final String title;

  /// 副本保存的是哪一侧的版本。
  final SyncSideRole loser;

  @override
  String toString() => 'SyncConflictCopy($originalId → $copyId)';
}

/// 删除保护：[side] 将彻底删除 [count] 篇日记（共 [total] 篇）。
@immutable
class SyncDeletionGuard {
  const SyncDeletionGuard({
    required this.side,
    required this.count,
    required this.total,
  });

  final SyncSideRole side;
  final int count;
  final int total;
}

/// 需要用户确认的事项（规格 §4.5）；规划器只报告，会话层决定。
@immutable
class SyncPendingConfirmations {
  SyncPendingConfirmations({
    required List<SyncDeletionGuard> deletionGuards,
    Map<SyncEntity, int> sideChoiceCounts = const <SyncEntity, int>{},
  }) : deletionGuards = List<SyncDeletionGuard>.unmodifiable(deletionGuards),
       sideChoiceCounts = Map<SyncEntity, int>.unmodifiable(sideChoiceCounts);

  /// 超过删除保护阈值的一侧（0–2 项）。
  final List<SyncDeletionGuard> deletionGuards;

  /// “以哪边为准”生效时，没有共同祖先的冲突涉及的记录数，按实体分开（只含
  /// 数量大于 0 的实体；顺序列表从不计入）；不生效时为空。不论本次用哪种
  /// [SyncSideChoice] 规划都照样报告：用户是否已经选过由会话层记住，规划器
  /// 不知道。
  final Map<SyncEntity, int> sideChoiceCounts;

  /// [sideChoiceCounts] 的合计。
  int get sideChoiceConflicts =>
      sideChoiceCounts.values.fold(0, (sum, count) => sum + count);

  bool get sideChoiceNeeded => sideChoiceConflicts > 0;

  bool get isEmpty => deletionGuards.isEmpty && !sideChoiceNeeded;
}

/// 一次同步的完整计划。
@immutable
class SyncPlan {
  SyncPlan({
    required this.local,
    required this.remote,
    required List<SyncConflictCopy> conflictCopies,
    required this.confirmations,
  }) : conflictCopies = List<SyncConflictCopy>.unmodifiable(conflictCopies);

  /// 本机（发起方）要执行的操作。
  final SyncSidePlan local;

  /// 对方要执行的操作。
  final SyncSidePlan remote;

  /// 按原日记 id 排序。
  final List<SyncConflictCopy> conflictCopies;

  final SyncPendingConfirmations confirmations;

  List<SyncWrite> get localWrites => local.writes;
  List<SyncWrite> get remoteWrites => remote.writes;

  SyncSidePlan sideOf(SyncSideRole role) =>
      role == SyncSideRole.local ? local : remote;

  bool get isEmpty => local.isEmpty && remote.isEmpty;
}
