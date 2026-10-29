part of 'sync_apply.dart';

/// 写入层的结果类型：会话层据此回 `applied{skipped, manifest}` 消息、告诉
/// 对方改键，并给界面摘要用。

/// 一侧计划的执行结果。
enum SyncApplyStatus {
  /// 已执行（可能有跳过的条目）。
  applied,

  /// 撤销窗口在超时前没有关闭，本次什么都没写（会话层中止，稍后再同步）。
  deferred,
}

/// 为什么跳过一条写入。枚举名即消息里的字符串。
enum SyncSkipReason {
  /// 前置条件不符：本机这条记录在规划之后变了（或改名的旧名 / 新名不符）。
  precondition,

  /// 记录结构不对，还原不出列值（对方数据损坏或版本不一致）。
  invalidRecord,

  /// 依赖的记录不在（如成员关系的日记 / 日记本的写入被跳过了）。
  missingDependency,

  /// 设置应用失败，已按快照回滚。
  settingsFailed;

  static SyncSkipReason? tryParse(String name) => values.asNameMap()[name];
}

/// 一条被跳过的写入（原地改名记为 `tag:<旧名>`）。下次同步再处理。
@immutable
class SyncApplySkip {
  const SyncApplySkip(this.key, this.reason);

  factory SyncApplySkip.fromJson(Object? json) {
    if (json is! Map || json['k'] is! String || json['r'] is! String) {
      throw const FormatException('无效的跳过条目');
    }
    final reason = SyncSkipReason.tryParse(json['r'] as String);
    if (reason == null) throw FormatException('未知的跳过原因', json['r']);
    return SyncApplySkip(SyncKey.parse(json['k'] as String), reason);
  }

  final SyncKey key;
  final SyncSkipReason reason;

  Map<String, Object?> toJson() => <String, Object?>{
    'k': key.toString(),
    'r': reason.name,
  };

  @override
  bool operator ==(Object other) =>
      other is SyncApplySkip && other.key == key && other.reason == reason;

  @override
  int get hashCode => Object.hash(key, reason);

  @override
  String toString() => 'SyncApplySkip($key, ${reason.name})';
}

/// [SyncApplier.apply] / [SyncApplier.adoptMediaRekeys] 的结果。
@immutable
class SyncApplyResult {
  SyncApplyResult({
    required this.status,
    List<SyncApplySkip> skipped = const <SyncApplySkip>[],
    List<SyncMediaRekey> rekeys = const <SyncMediaRekey>[],
    this.manifest,
    Map<SyncEntity, SyncEntityCounts> counts =
        const <SyncEntity, SyncEntityCounts>{},
    this.mediaFiles = 0,
    this.mediaBytes = 0,
  }) : skipped = List<SyncApplySkip>.unmodifiable(skipped),
       rekeys = List<SyncMediaRekey>.unmodifiable(rekeys),
       counts = Map<SyncEntity, SyncEntityCounts>.unmodifiable(counts);

  SyncApplyResult.deferred() : this(status: SyncApplyStatus.deferred);

  final SyncApplyStatus status;

  /// 跳过的写入与改名（`applied{skipped}`）。
  final List<SyncApplySkip> skipped;

  /// 本机收件时因同键不同文件换了键的媒体：会话层发给来源一侧，对方调用
  /// [SyncApplier.adoptMediaRekeys] 照做，两边的规范记录才会一致。
  final List<SyncMediaRekey> rekeys;

  /// 写入后的本机清单（`applied{manifest}`）；推迟时为 null。
  final SyncManifest? manifest;

  /// 实际执行的写入按实体统计（跳过的不算；原地改名记为标签更新）。
  final Map<SyncEntity, SyncEntityCounts> counts;

  /// 新放进托管目录的媒体文件数与字节数（复用本机已有的不算）。
  final int mediaFiles;
  final int mediaBytes;

  bool get isDeferred => status == SyncApplyStatus.deferred;

  /// 日记的新增 / 更新 / 删除（界面摘要）。冲突副本数取自计划的
  /// `SyncPlan.conflictCopies`，写入层不重复判断。
  SyncEntityCounts get diaries =>
      counts[SyncEntity.diary] ?? const SyncEntityCounts();

  /// 是否改动了任何数据（推迟或全部跳过时为 false）。
  bool get changedAnything =>
      counts.values.any((count) => count.total > 0) || mediaFiles > 0;
}

/// 事务与设置都完成后的中间结果（[SyncApplier] 内部）。
class _LockedResult {
  _LockedResult(this.skipped, this.manifest, this.counts);

  final List<SyncApplySkip> skipped;
  final SyncManifest manifest;
  final Map<SyncEntity, SyncEntityCounts> counts;
}

/// 写入后折叠要继承的历史时间：只取真正写了的键，且去掉被媒体改键改写过的
/// 分面（改写后的值不再是另一侧的原值，规格 §4.1.1）。
Map<SyncKey, Map<String, int>> _inheritedSeenAt(
  SyncSidePlan plan,
  List<SyncWrite> performed,
  Map<SyncKey, Set<String>> rewrittenFacets,
) {
  final result = <SyncKey, Map<String, int>>{};
  for (final write in performed) {
    final times = plan.historySeenAt[write.key];
    if (times == null) continue;
    final rewritten = rewrittenFacets[write.key] ?? const <String>{};
    final kept = <String, int>{
      for (final entry in times.entries)
        if (!rewritten.contains(entry.key)) entry.key: entry.value,
    };
    if (kept.isNotEmpty) result[write.key] = kept;
  }
  return result;
}

/// 实际执行的写入按实体统计；原地改名记为标签更新（与计划的 stats 同口径）。
Map<SyncEntity, SyncEntityCounts> _countPerformed(
  List<SyncWrite> performed,
  List<SyncTagRenameOp> renamed,
) {
  final counts = <SyncEntity, SyncEntityCounts>{};
  void add(SyncEntity entity, {int a = 0, int u = 0, int d = 0}) {
    counts[entity] = (counts[entity] ?? const SyncEntityCounts()).plus(
      added: a,
      updated: u,
      deleted: d,
    );
  }

  for (final write in performed) {
    if (write.isDelete) {
      add(write.key.entity, d: 1);
    } else if (write.isInsert) {
      add(write.key.entity, a: 1);
    } else {
      add(write.key.entity, u: 1);
    }
  }
  if (renamed.isNotEmpty) add(SyncEntity.tag, u: renamed.length);
  return counts;
}
