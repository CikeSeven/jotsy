// ignore_for_file: invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

/// 新建页“返回时直接发表”（设置 → 编辑器设置，`DiaryCreatePrefs`，#196）。
///
/// 默认（存进草稿箱）时新建页的返回不经这里：PopScope 直接放行，草稿在 pop
/// 回调里补存。打开这个设置后，新建页的 PopScope 拦下返回（返回键、顶栏
/// 返回、桌面 Esc 都经 `attemptExit`，面板与录音仍先收起），交给
/// [leaveCreateEntryPublishing]：
///
/// 1. 没写东西（只套了模板或带进来的内容原样未动的也算，口径同草稿自动
///    保存）：照常离开，
///    空草稿在 pop 回调里补存时删除；
/// 2. 校验不过（metadata 损坏）：与“发表”键一样提示并留在本页；
/// 3. 带时间胶囊（且胶囊功能开着）：封存是一次性的仪式，与“发表”键一样经
///    发布页（进入即发表，返回时播放封存卡片）；
/// 4. 其余直接写库（[publishNewDiaryDirectly]，与发布页同一口径）。成功后
///    先关草稿自动保存再删草稿（顺序见 `_deletePublishedDraft`）、轻震、
///    按需开始 AI 自动回应，然后以新日记 id 退场，列表据此播放新卡片的出现
///    动画（与发布页退场相同）；
/// 5. 写库失败：补存草稿后离开并提示“留在草稿箱里”，不把用户困在页面上；
///    连草稿也存不下时提示失败并留在本页，输入不丢。
///
/// 写库期间 `_saving` 为真，`attemptExit` 不会重入（连按返回不会发表两次）。
extension EditDiaryCreateLeaveFlow on EditDiaryController {
  Future<void> leaveCreateEntryPublishing() async {
    final context = _state.context;
    final navigator = Navigator.of(context);
    final draft = _state._currentCreateDraft;
    if (!createSnapshotOf(draft).hasContent) {
      navigator.pop();
      return;
    }
    if (!validateDraft()) {
      return;
    }
    final features = _state.ref.read(appFeaturesProvider);
    if (features.timeCapsules &&
        DiaryMetaDraft.fromNewDiaryDraft(draft).capsule != null) {
      await openPublishPage();
      return;
    }

    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    _state.setState(() => _state._saving = true);
    try {
      final String diaryId;
      try {
        diaryId = await publishNewDiaryDirectly(
          database: _state._database,
          draft: draft,
          timeCapsulesEnabled: features.timeCapsules,
          notebooksEnabled: features.notebooks,
        );
      } catch (error) {
        debugPrint('Publish on leave failed: $error');
        final saved = await flushCreateDraft();
        if (!_state.mounted) return;
        if (saved) {
          _showHint(l10n.publishOnLeaveFailedKeptDraft);
          navigator.pop();
        } else {
          _showHint(l10n.publishFailed);
        }
        return;
      }
      // 不论本页是否还在都要删除草稿，否则日记与草稿并存，可能被再发一次。
      unawaited(_deletePublishedDraft());
      if (!_state.mounted) return;
      unawaited(HapticFeedback.lightImpact());
      // 直接发表的不会带胶囊（带胶囊的经发布页），与发布页一样自动回应。
      unawaited(
        startAutoAiReply(
          _state.ref,
          diaryId: diaryId,
          locale: locale,
          l10n: l10n,
        ),
      );
      navigator.pop(diaryId);
    } finally {
      if (_state.mounted) _state.setState(() => _state._saving = false);
    }
  }
}
