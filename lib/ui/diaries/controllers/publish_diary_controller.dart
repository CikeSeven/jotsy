import 'package:flutter/foundation.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/controllers/debounced_auto_save_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/models/publish_metadata_composer.dart';
import 'package:node_diary/ui/diaries/models/publish_time.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';

/// 发布页的阶段。
///
/// - idle：刚打开、还没写库（进入即发表，这一瞬间面板锁住、不能返回）；
///   写库失败也回到这里，页面随即退回编辑页；
/// - saving：正在写库；
/// - published：已发表，面板改动像编辑页一样随改随存，可以返回；
/// - sealing：返回时这篇是未解封的胶囊，封存卡片一直展示到页面退场；
/// - done：正在退场（含退场前的补存）。
///
/// 只有 published 允许返回：写库前后返回会让日记留在编辑页草稿里、或丢掉
/// 面板上刚做的改动。
enum PublishPhase { idle, saving, published, sealing, done }

/// 发布前校验结果。
enum PublishValidation { ok, capsuleUnlockPassed }

/// 发布页的自动保存快照：实际写库的面板草稿与发表时间（不含胶囊）。
typedef PublishedDiarySnapshot = ({DiaryMetaDraft meta, DateTime publishAt});

/// 发布页的发布流程（不含 UI）：进入即发表，之后面板改动自动保存。
///
/// 输入：打开者带来的 [initialDraft]（标题、正文、请求的发表时间）与面板
/// 草稿 [meta]；[clock] 供测试注入时间。
/// 输出：[phase]、[explicitPublishAt] 两个可监听状态，[submit] 返回新日记
/// id（之后为 [diaryId]），[finish] 告诉页面能否退场、要不要播放封存。
/// 副作用：[submit] 新建日记；此后 [meta] 与 [explicitPublishAt] 的每次变化
/// 经防抖（[autoSaveDebounce]）改写这篇日记，[flush] 立即补存。写入失败经
/// [onSaveError] 交给页面提示，快照保持未存，下一次改动或返回时重试。提示、
/// 触觉、封存动画、路由由页面负责。
///
/// 功能管理里关闭的功能（`timeCapsulesEnabled`、`notebooksEnabled`）在发布
/// 时一律忽略，按普通日记发布：草稿可能来自关闭之前、日历或模板的预设，
/// 日记绝不能经用户已经看不到的设置被封存、或收进看不到的本子（私密本里的
/// 日记会从所有列表消失）。两个开关在写库时读取一次并沿用到之后的自动保存
/// （停在本页期间改不了功能管理；页面销毁时补存也不能再读 provider）。
class PublishDiaryController {
  PublishDiaryController({
    required this.initialDraft,
    required this.meta,
    bool Function()? timeCapsulesEnabled,
    bool Function()? notebooksEnabled,
    void Function(Object error)? onSaveError,
    DateTime Function()? clock,
    Duration autoSaveDebounce = const Duration(milliseconds: 500),
  }) : _timeCapsulesEnabled = timeCapsulesEnabled ?? _alwaysEnabled,
       _notebooksEnabled = notebooksEnabled ?? _alwaysEnabled,
       _clock = clock ?? DateTime.now {
    _autoSave = DebouncedAutoSaveController<PublishedDiarySnapshot>(
      debounce: autoSaveDebounce,
      readSnapshot: _captureSnapshot,
      writeSnapshot: _writeSnapshot,
      onError: (error) => onSaveError?.call(error),
    );
  }

  final NewDiaryDraft initialDraft;
  final DiaryMetaDraftController meta;

  /// 时间胶囊功能是否开启；关闭时忽略草稿里的胶囊：不校验解封时间、不封存，
  /// `capsuleUnlockAt` / `capsuleLockedAt` 留空。
  final bool Function() _timeCapsulesEnabled;

  /// 日记本功能是否开启；关闭时新日记不收进任何本子（也不带章节）。
  final bool Function() _notebooksEnabled;
  final DateTime Function() _clock;
  late final DebouncedAutoSaveController<PublishedDiarySnapshot> _autoSave;

  static bool _alwaysEnabled() => true;

  final ValueNotifier<PublishPhase> phase = ValueNotifier<PublishPhase>(
    PublishPhase.idle,
  );

  /// 用户在本页亲自选的发表时间；没选过为 null，发表时间为写库那一刻。
  final ValueNotifier<DateTime?> explicitPublishAt = ValueNotifier<DateTime?>(
    null,
  );

  // 写库时读取的功能开关（见类注释）；写库前为 null，校验时现读。
  bool? _capsulesOn;
  bool? _notebooksOn;

  // 写库之后才有：自动保存改写的日记与所用的数据库。
  AppDatabase? _database;
  String? _diaryId;

  // 写库时确定的发表时间（不含胶囊）：之后没另选时间就一直是它。
  DateTime? _publishedAt;

  // 当前胶囊的封存时刻：第一次把胶囊写进库的那一刻，改解封日不变，取消
  // 胶囊后清空、再设时重新计。
  DateTime? _sealedAt;

  bool _disposed = false;

  /// 新日记的业务 id；写库成功之前为 null。
  String? get diaryId => _diaryId;

  /// 是否可以返回：只有已发表、且不在退场中时。
  bool get canLeave => phase.value == PublishPhase.published;

  /// 实际发表时间：用户选过就用所选（晚于现在时回退到现在）；否则写库后是
  /// 写库那一刻，写库前按打开者带来的请求值现算（见 [resolvePublishAt]）。
  DateTime get effectivePublishAt {
    final now = _clock();
    final explicit = explicitPublishAt.value;
    if (explicit != null) {
      return explicit.isAfter(now) ? now : explicit;
    }
    return _publishedAt ??
        resolvePublishAt(initialDraft.createdAtOverride, now: now);
  }

  /// 记录选择器返回的发表时间。原样确认（选回 [shown] 那一分钟时选择器
  /// 返回 shown 本身）不算选择，不触发保存。
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
    if (!(_capsulesOn ?? _timeCapsulesEnabled()) && draft.capsule != null) {
      draft = draft.copyWith(capsule: null);
    }
    if (!(_notebooksOn ?? _notebooksEnabled()) &&
        draft.notebookIds.isNotEmpty) {
      draft = draft.copyWith(notebookIds: const <String>{});
    }
    return draft;
  }

  /// 按日记本新建时的章节；日记本功能关闭时不带。
  Map<String, String> get _chapterIds => (_notebooksOn ?? _notebooksEnabled())
      ? initialDraft.notebookChapterIds
      : const <String, String>{};

  PublishedDiarySnapshot _captureSnapshot() =>
      (meta: _publishedMeta, publishAt: effectivePublishAt);

  /// 组装 metadata；[capsuleLockedAt] 为胶囊的封存时刻（没有胶囊时不写）。
  String _composeMetadata(
    DiaryMetaDraft draft, {
    required DateTime generatedAt,
    DateTime? capsuleLockedAt,
  }) => PublishMetadataComposer.composeDraft(
    draft: draft,
    contentText: initialDraft.contentText,
    generatedAt: generatedAt,
    capsuleLockedAt: capsuleLockedAt,
  );

  /// 写库并返回新日记 id（页面一打开就调用）。
  ///
  /// 只在 idle 时可调用。成功后进入 published，开始监听面板与发表时间并
  /// 自动保存；失败回到 idle 并把异常抛给页面。日记的创建时间：有胶囊时是
  /// 解封时刻，否则是 [effectivePublishAt]。
  Future<String> submit(AppDatabase database) async {
    if (phase.value != PublishPhase.idle) {
      throw StateError('The diary is already published.');
    }
    _capsulesOn = _timeCapsulesEnabled();
    _notebooksOn = _notebooksEnabled();
    final snapshot = _captureSnapshot();
    final draft = snapshot.meta;
    final schedule = draft.capsule;
    _setPhase(PublishPhase.saving);
    final String diaryId;
    try {
      final sealedAt = schedule == null ? null : _clock();
      diaryId = await database.createDiary(
        title: initialDraft.title,
        contentDocJson: initialDraft.contentDocJson,
        contentText: initialDraft.contentText,
        cover: draft.cover,
        metadataJson: _composeMetadata(
          draft,
          generatedAt: sealedAt ?? _clock(),
          capsuleLockedAt: sealedAt,
        ),
        tagIds: draft.tagIds.toList(),
        createdAtOverride: TimeCapsuleSchedule.resolveDiaryCreatedAt(
          schedule: schedule,
          fallbackPublishAt: snapshot.publishAt,
        ),
        capsuleUnlockAt: schedule?.normalizedUnlockAt,
        capsuleLockedAt: sealedAt,
        // 同一事务里收进所选日记本；在日记本里按章节新建时带上章节。
        notebookIds: draft.notebookIds.toList(),
        notebookChapterIds: _chapterIds,
      );
      _sealedAt = sealedAt;
    } catch (_) {
      _capsulesOn = null;
      _notebooksOn = null;
      _setPhase(PublishPhase.idle);
      rethrow;
    }
    _database = database;
    _diaryId = diaryId;
    _publishedAt = snapshot.publishAt;
    if (_disposed) return diaryId;
    // 基线是实际写进去的快照：写库期间面板若有变化（如定位回填），按正常
    // 防抖补存，而不是被当成已存。
    _autoSave.initialize(snapshot);
    meta.addListener(_onInputChanged);
    explicitPublishAt.addListener(_onInputChanged);
    _setPhase(PublishPhase.published);
    if (_captureSnapshot() != snapshot) _autoSave.schedule();
    return diaryId;
  }

  void _onInputChanged() => _autoSave.schedule();

  /// 把快照写回这篇日记。标题与正文就是发表时的那份，本页改不了。
  ///
  /// 页面销毁时补存的写入在页面卸载后才完成，这里只用写库时缓存的数据库与
  /// 功能开关，不经页面读取任何东西。
  Future<void> _writeSnapshot(PublishedDiarySnapshot snapshot) async {
    final draft = snapshot.meta;
    final schedule = draft.capsule;
    final now = _clock();
    final sealedAt = schedule == null ? null : (_sealedAt ??= now);
    if (schedule == null) _sealedAt = null;
    await _database!.updateDiary(
      diaryId: _diaryId!,
      title: initialDraft.title,
      contentDocJson: initialDraft.contentDocJson,
      contentText: initialDraft.contentText,
      cover: draft.cover,
      metadataJson: _composeMetadata(
        draft,
        generatedAt: now,
        capsuleLockedAt: sealedAt,
      ),
      tagIds: draft.tagIds.toList(),
      createdAt: TimeCapsuleSchedule.resolveDiaryCreatedAt(
        schedule: schedule,
        fallbackPublishAt: snapshot.publishAt,
      ),
      notebookIds: draft.notebookIds.toList(),
      notebookChapterIds: _chapterIds,
      capsule: (unlockAt: schedule?.normalizedUnlockAt, lockedAt: sealedAt),
    );
  }

  /// 立即补存防抖窗口里的改动（切后台、页面销毁时调用）；写库前不做任何事。
  Future<bool> flush() => _autoSave.flush();

  /// 退场前补存。
  ///
  /// 成功时进入 sealing（这篇是仍未解封的胶囊，页面播放封存卡片）或 done，
  /// 返回 true；补存失败回到 published 并返回 false（错误经 onSaveError
  /// 提示），留在本页可重试。不在 published 时直接返回 false。
  Future<bool> finish() async {
    if (!canLeave) return false;
    _setPhase(PublishPhase.done);
    final saved = await _autoSave.flush();
    if (!saved) {
      _setPhase(PublishPhase.published);
      return false;
    }
    final capsule = _publishedMeta.capsule;
    if (capsule != null && capsule.isUnlockInFuture(_clock())) {
      _setPhase(PublishPhase.sealing);
    }
    return true;
  }

  /// 页面销毁后写库才返回时，不再写已释放的通知器。
  void _setPhase(PublishPhase next) {
    if (!_disposed) phase.value = next;
  }

  /// 停止自动保存。已经开始的写入照常完成，页面应先 [flush] 再调用。
  void dispose() {
    _disposed = true;
    _autoSave.dispose();
    meta.removeListener(_onInputChanged);
    explicitPublishAt.removeListener(_onInputChanged);
    phase.dispose();
    explicitPublishAt.dispose();
  }
}
