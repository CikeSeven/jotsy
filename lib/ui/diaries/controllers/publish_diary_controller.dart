import 'package:flutter/foundation.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/models/publish_metadata_composer.dart';
import 'package:node_diary/ui/diaries/models/publish_time.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';

/// 发布流程的阶段。
///
/// - idle：可编辑、可返回编辑页；
/// - saving：正在写库；
/// - sealing：已写库的胶囊，封存卡片一直展示到页面退场；
/// - done：已写库的普通日记，页面正在退场。
///
/// 除 idle 外都不允许带草稿返回或再次发布：日记已经（或即将）存在，带回
/// 草稿会让编辑页留着它，用户可以重复发布。
enum PublishPhase { idle, saving, sealing, done }

/// 发布前校验结果。
enum PublishValidation { ok, capsuleUnlockPassed }

/// 发布页的发布流程（不含 UI）。
///
/// 输入：打开者带来的 [initialDraft]（标题、正文、请求的发表时间）与面板
/// 草稿 [meta]；[clock] 供测试注入时间。
/// 输出：[phase]、[explicitPublishAt] 两个可监听状态，[submit] 返回新日记
/// id，[returnDraft] 给出返回编辑页时带回的草稿。
/// 副作用：只有 [submit] 写数据库。提示、触觉、封存动画、路由由页面负责。
///
/// 功能管理里关闭的功能（`timeCapsulesEnabled`、`notebooksEnabled`，校验与
/// 写库时现读）在发布时一律忽略，按普通日记发布：草稿可能来自关闭之前、
/// 日历或模板的预设，日记绝不能经用户已经看不到的设置被封存、或收进看不到
/// 的本子（私密本里的日记会从所有列表消失）。只影响写库（[submit]）与校验
/// （[validate]）；面板草稿与带回编辑页的草稿（[returnDraft]）原样保留，
/// 重新开启后照常生效。
class PublishDiaryController {
  PublishDiaryController({
    required this.initialDraft,
    required this.meta,
    bool Function()? timeCapsulesEnabled,
    bool Function()? notebooksEnabled,
    DateTime Function()? clock,
  }) : _timeCapsulesEnabled = timeCapsulesEnabled ?? _alwaysEnabled,
       _notebooksEnabled = notebooksEnabled ?? _alwaysEnabled,
       _clock = clock ?? DateTime.now;

  final NewDiaryDraft initialDraft;
  final DiaryMetaDraftController meta;

  /// 时间胶囊功能是否开启；关闭时忽略草稿里的胶囊：不校验解封时间、不封存，
  /// `capsuleUnlockAt` / `capsuleLockedAt` 留空。
  final bool Function() _timeCapsulesEnabled;

  /// 日记本功能是否开启；关闭时新日记不收进任何本子（也不带章节）。
  final bool Function() _notebooksEnabled;
  final DateTime Function() _clock;

  static bool _alwaysEnabled() => true;

  final ValueNotifier<PublishPhase> phase = ValueNotifier<PublishPhase>(
    PublishPhase.idle,
  );

  /// 用户在本页亲自选的发表时间；没选过为 null，发表时间在提交时现算。
  final ValueNotifier<DateTime?> explicitPublishAt = ValueNotifier<DateTime?>(
    null,
  );

  bool _disposed = false;

  /// 是否仍可带草稿返回编辑页、可再次发布。
  bool get canLeave => phase.value == PublishPhase.idle;

  /// 实际发表时间：用户选过就用所选（晚于现在时回退到现在），否则按打开
  /// 者带来的请求值现算（见 [resolvePublishAt]）。每次读取都重新计算，
  /// 发布时取的是提交那一刻，而不是打开发布页的那一刻。
  DateTime get effectivePublishAt {
    final now = _clock();
    final explicit = explicitPublishAt.value;
    if (explicit != null) {
      return explicit.isAfter(now) ? now : explicit;
    }
    return resolvePublishAt(initialDraft.createdAtOverride, now: now);
  }

  /// 是否有确定的发表时间可显示；既没选过、打开者也没指定时面板显示
  /// “自动获取当前时间”。
  bool get hasFixedPublishTime =>
      explicitPublishAt.value != null || initialDraft.createdAtOverride != null;

  /// 记录选择器返回的发表时间。原样确认（选回 [shown] 那一分钟时选择器
  /// 返回 shown 本身）不算选择，发表时间继续跟随提交时刻。
  void applyPickedPublishAt(DateTime picked, {required DateTime shown}) {
    if (picked == shown) return;
    explicitPublishAt.value = picked;
  }

  /// 发布前校验：解封时间必须仍在未来。日期精度选了今天、或恢复的草稿里
  /// 那天已过，写入的就是一个立即解封的胶囊。
  PublishValidation validate() {
    final capsule = _publishedMeta.capsule;
    if (capsule != null && !capsule.isUnlockInFuture(_clock())) {
      return PublishValidation.capsuleUnlockPassed;
    }
    return PublishValidation.ok;
  }

  /// 实际发布的面板草稿：关闭的功能留下的胶囊与日记本去掉（见类注释）。
  DiaryMetaDraft get _publishedMeta {
    var draft = meta.value;
    if (!_timeCapsulesEnabled() && draft.capsule != null) {
      draft = draft.copyWith(capsule: null);
    }
    if (!_notebooksEnabled() && draft.notebookIds.isNotEmpty) {
      draft = draft.copyWith(notebookIds: const <String>{});
    }
    return draft;
  }

  /// 组装 metadata；[generatedAt] 同时作为胶囊的封存时刻。[draft] 默认为
  /// 面板草稿原样（带回编辑页用），写库时传 [_publishedMeta]。
  String buildMetadataJson({DateTime? generatedAt, DiaryMetaDraft? draft}) {
    final lockedAt = generatedAt ?? _clock();
    return PublishMetadataComposer.composeDraft(
      draft: draft ?? meta.value,
      contentText: initialDraft.contentText,
      generatedAt: lockedAt,
      capsuleLockedAt: lockedAt,
    );
  }

  /// 写库并返回新日记 id。
  ///
  /// 只在 idle 时可调用。成功后进入 sealing（有胶囊，页面播放封存卡片）或
  /// done，不再回到 idle；失败回到 idle 并把异常抛给页面提示。日记的创建
  /// 时间：有胶囊时是解封时刻，否则是 [effectivePublishAt]。
  Future<String> submit(AppDatabase database) async {
    if (!canLeave) {
      throw StateError('Publishing is already in progress.');
    }
    final draft = _publishedMeta;
    final schedule = draft.capsule;
    final notebooksEnabled = _notebooksEnabled();
    _setPhase(PublishPhase.saving);
    try {
      final lockedAt = schedule == null ? null : _clock();
      final diaryId = await database.createDiary(
        title: initialDraft.title,
        contentDocJson: initialDraft.contentDocJson,
        contentText: initialDraft.contentText,
        cover: draft.cover,
        metadataJson: buildMetadataJson(generatedAt: lockedAt, draft: draft),
        tagIds: draft.tagIds.toList(),
        createdAtOverride: TimeCapsuleSchedule.resolveDiaryCreatedAt(
          schedule: schedule,
          fallbackPublishAt: effectivePublishAt,
        ),
        capsuleUnlockAt: schedule?.normalizedUnlockAt,
        capsuleLockedAt: lockedAt,
        // 同一事务里收进所选日记本；在日记本里按章节新建时带上章节。
        notebookIds: draft.notebookIds.toList(),
        notebookChapterIds: notebooksEnabled
            ? initialDraft.notebookChapterIds
            : const <String, String>{},
      );
      _setPhase(schedule == null ? PublishPhase.done : PublishPhase.sealing);
      return diaryId;
    } catch (_) {
      _setPhase(PublishPhase.idle);
      rethrow;
    }
  }

  /// 返回编辑页时带回的草稿：面板字段 + 用户亲自选的发表时间。没选过就
  /// 原样带回打开者的请求值（如日历的按日新建），下次打开或发表时再现算，
  /// 不把“打开发布页那一刻”冻结进草稿。
  NewDiaryDraft returnDraft() => meta.value.applyTo(
    initialDraft.copyWith(
      createdAtOverride:
          explicitPublishAt.value ?? initialDraft.createdAtOverride,
      metadataJson: buildMetadataJson(),
    ),
  );

  /// 页面销毁后写库才返回时，不再写已释放的通知器。
  void _setPhase(PublishPhase next) {
    if (!_disposed) phase.value = next;
  }

  void dispose() {
    _disposed = true;
    phase.dispose();
    explicitPublishAt.dispose();
  }
}
