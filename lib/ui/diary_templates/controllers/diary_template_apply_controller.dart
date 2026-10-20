import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../../diaries/models/diary_meta_draft.dart';
import '../../diaries/models/new_diary_draft.dart';
import '../../diaries/models/time_capsule.dart';
import '../models/diary_template_body.dart';
import '../models/diary_template_selection.dart';
import '../viewmodels/diary_template_application.dart';
import '../viewmodels/diary_template_variable_values.dart';
import 'diary_template_apply_port.dart';

export 'diary_template_apply_port.dart';

/// 新建编辑页里的模板套用：建议条的显示状态、套用、撤销，以及“套用后原样
/// 未动的内容不算草稿”。
///
/// 状态边界：
/// - 只在新建空白日记时可用（[enabled]）；续写草稿、编辑已有日记都不出现；
/// - 标题与正文都为空时才能套用，绝不覆盖用户已经写下的字；
/// - 用户一旦写了字（[_touched]）建议条就不再出现，即使之后删光——此后不再
///   每次输入都检查整篇文档；
/// - 套用后建议条收起，撤销成功后重新出现；用户关掉（[dismiss]）后本次编辑
///   不再出现。
///
/// 撤销只在标题与正文仍是套用时的样子时生效：撤销提示条停留的 4 秒里用户
/// 已经开始写，就不能再清空。元数据只撤回仍保持模板所设值的那几项。
///
/// 换模板（[apply] 带 `replacePristine: true`，顶栏菜单与“全部”面板用）：
/// - 只在 [isPristine] 时替换——内容仍是本次套用的模板原样；用户写过字就
///   拒绝，绝不覆盖模板以外的字（[canApply] 供界面提前判断）；
/// - 旧模板的预设先撤回、再换上新模板的内容与预设，同一个同步步骤里完成：
///   [_applied] 直接从旧记录换成新记录、只通知一次，建议条不会在两者之间
///   闪出来，[onEditorChanged] 也看不到中间状态；
/// - 旧记录随之失效：它的撤销提示条再点也不生效（[isPristine] 要求同一条
///   记录）；撤销新记录回到空白日记，不会恢复上一个模板；
/// - 标签：旧模板勾上的标签与撤销一样取消勾选；旧模板新建的标签先回收，
///   再解析新模板的标签——两份模板都用到的同名标签由新模板重新取得并勾上，
///   而不是在勾上之后才被回收。所有标签读写经 [_enqueueTagWork] 排队，
///   上一份仍在解析的标签不会与回收或新的解析交错。
class DiaryTemplateApplyController extends ChangeNotifier {
  DiaryTemplateApplyController({
    required this.enabled,
    required this._port,
    required this._database,
    required this._onUsed,
    DateTime Function()? clock,
    bool Function()? capsulesEnabled,
  }) : _clock = clock ?? DateTime.now,
       _capsulesEnabled = capsulesEnabled ?? _alwaysEnabled;

  final bool enabled;
  final DiaryTemplateEditorPort _port;
  final AppDatabase _database;
  final Future<void> Function(String templateId) _onUsed;
  final DateTime Function() _clock;

  /// 时间胶囊功能是否开启，套用时现读：关闭时模板的胶囊预设不套用（预设
  /// 留在模板里，重新开启后照常生效），免得经看不到的设置封存日记。
  final bool Function() _capsulesEnabled;

  static bool _alwaysEnabled() => true;

  bool _dismissed = false;
  bool _touched = false;
  bool _applying = false;
  bool _disposed = false;
  DiaryTemplateApplied? _applied;

  /// 标签读写的队尾：按名称取得与回收依次执行，见 [_enqueueTagWork]。
  Future<void> _tagWork = Future<void>.value();

  DiaryTemplateApplied? get applied => _applied;

  /// 此刻选一个模板能否生效（按 `replacePristine: true` 的规则）：标题与
  /// 正文都为空，或仍是本次套用的模板原样（会被替换）。
  bool get canApply {
    if (!enabled || _applying) return false;
    final applied = _applied;
    if (applied != null && isPristine(applied)) return true;
    return !_port.hasContent;
  }

  /// 建议条此刻是否该出现（是否有可选的模板、偏好是否开启由建议条自己看）。
  bool get stripVisible =>
      enabled && !_dismissed && !_touched && _applied == null;

  /// 关掉建议条，本次编辑不再出现。
  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    notifyListeners();
  }

  /// 标题或正文变化（含光标移动）时由编辑页调用。
  void onEditorChanged() {
    if (!enabled || _applying || _touched || _applied != null) return;
    if (_port.hasContent) {
      _touched = true;
      notifyListeners();
    }
  }

  /// 套用 [selection]；标题或正文已有内容、或正在套用时什么也不做，返回 null。
  ///
  /// 默认已经套用过一次就不再套用（建议条在套用后收起）；[replacePristine]
  /// 为 true 时，内容仍是上一次套用的原样则换成 [selection]（见类注释），
  /// 用户把内容删空后也可以重新套用。
  ///
  /// 顺序：先换标题与正文（同步），再合并预设的心情、精力与胶囊（只填空着
  /// 的项；日历预设的胶囊优先），最后异步按名称取得标签并勾上。标签解析
  /// 期间若已撤销或换了模板，回收刚新建的标签。
  Future<DiaryTemplateApplied?> apply(
    DiaryTemplateSelection selection, {
    required DiaryTemplateApplySource source,
    bool replacePristine = false,
  }) async {
    if (!enabled || _applying) return null;
    final previous = _applied;
    final replacing =
        replacePristine && previous != null && isPristine(previous);
    if (!replacing &&
        (_port.hasContent || (previous != null && !replacePristine))) {
      return null;
    }
    final template = selection.template;
    final now = _clock();
    final application = DiaryTemplateApplication.resolve(
      template,
      DiaryTemplateVariableValues.compute(
        l10n: _port.l10n,
        diaryDate: _port.diaryDate,
        now: now,
        questionShift: selection.questionShift,
      ),
    );
    final DiaryMetaDraft metaBefore;
    final String bodyJson;
    _applying = true;
    try {
      // 换模板：先撤回旧模板的预设，新模板的“套用前”就是没有旧模板时的
      // 样子，撤销新模板因此回到空白日记。内容不必先清空，下面直接换上。
      if (replacing) _revertPresets(previous);
      metaBefore = _port.meta.value;
      bodyJson = _port.replaceContent(
        title: application.title,
        ops: application.ops,
        caret: _caretFor(application),
      );
      _applyPresets(application, metaBefore, now);
    } finally {
      _applying = false;
    }
    final applied = DiaryTemplateApplied(
      template: template,
      title: application.title,
      bodyJson: bodyJson,
      metaBefore: metaBefore,
      metaAfter: _port.meta.value,
    );
    _applied = applied;
    notifyListeners();
    await _enqueueTagWork(() async {
      // 先回收旧模板新建的标签，再解析新模板的：两份模板都用到的标签若在
      // 新模板勾上之后才回收，会把刚勾上的删掉。
      if (replacing) await _database.deleteTagsIfUnused(previous.createdTagIds);
      await _applyTags(applied);
    });
    if (source != DiaryTemplateApplySource.auto && !_disposed) {
      unawaited(_onUsed(template.id));
    }
    return applied;
  }

  /// 标题与正文是否仍是 [applied] 套用时的样子。
  bool isPristine(DiaryTemplateApplied applied) =>
      identical(_applied, applied) &&
      _port.title == applied.title &&
      _port.contentDocJson == applied.bodyJson;

  /// 撤销 [applied]；用户已经改过内容时什么也不做，返回 false。
  Future<bool> undo(DiaryTemplateApplied applied) async {
    if (_disposed || !isPristine(applied)) return false;
    _applying = true;
    try {
      _port.replaceContent(title: '', ops: emptyDiaryTemplateOps, caret: 0);
      _revertPresets(applied);
    } finally {
      _applying = false;
    }
    _applied = null;
    notifyListeners();
    // 排在仍在解析的标签之后：那时 createdTagIds 才完整。
    await _enqueueTagWork(
      () => _database.deleteTagsIfUnused(applied.createdTagIds),
    );
    return true;
  }

  /// 草稿自动保存读取的快照：标题与正文仍是套用时的样子，就按“没有内容”
  /// 处理——草稿表里不会因为点开一个模板又离开而多出一份草稿；写了字或
  /// 之后改回原样，按正常规则保存或删除。
  NewDiaryDraftSnapshot snapshotFor(NewDiaryDraft draft) {
    final snapshot = draft.toSnapshot();
    final applied = _applied;
    if (applied == null ||
        !snapshot.hasContent ||
        draft.title != applied.title ||
        draft.contentDocJson != applied.bodyJson) {
      return snapshot;
    }
    return (
      payload: snapshot.payload,
      title: snapshot.title,
      contentText: snapshot.contentText,
      hasContent: false,
    );
  }

  int _caretFor(DiaryTemplateApplication application) {
    final buffer = StringBuffer();
    for (final op in application.ops) {
      final insert = op['insert'];
      // 嵌入在 Quill 的偏移里占一个字符。
      buffer.write(insert is String ? insert : '￼');
    }
    return firstEmptyLineOffset(buffer.toString());
  }

  void _applyPresets(
    DiaryTemplateApplication application,
    DiaryMetaDraft before,
    DateTime now,
  ) {
    final meta = _port.meta;
    final mood = application.mood;
    if (mood != null &&
        before.moodEmoji == null &&
        _port.moodOptions.contains(mood)) {
      meta.setMood(mood);
    }
    final energy = application.energy;
    if (energy != null && before.energyLevel == null) {
      meta.setEnergy(energy.toDouble());
    }
    final capsule = application.capsule;
    if (capsule != null && before.capsule == null && _capsulesEnabled()) {
      meta.setCapsule(
        TimeCapsuleSchedule(
          unlockAt: TimeCapsuleSchedule.normalizeUnlockAt(
            TimeCapsuleSchedule.presetUnlockAt(capsule, now),
            precision: TimeCapsulePrecision.date,
          ),
          precision: TimeCapsulePrecision.date,
        ),
      );
    }
  }

  void _revertPresets(DiaryTemplateApplied applied) {
    final meta = _port.meta;
    final current = meta.value;
    final before = applied.metaBefore;
    final after = applied.metaAfter;
    if (after.moodEmoji != before.moodEmoji &&
        current.moodEmoji == after.moodEmoji) {
      meta.setMood(before.moodEmoji);
    }
    if (after.energyLevel != before.energyLevel &&
        current.energyLevel == after.energyLevel) {
      meta.setEnergy(before.energyLevel);
    }
    if (after.capsule != before.capsule && current.capsule == after.capsule) {
      meta.setCapsule(before.capsule);
    }
    for (final id in applied.addedTagIds) {
      if (meta.value.tagIds.contains(id)) meta.setTagSelected(id, false);
    }
  }

  /// 把标签读写排到队尾依次执行，返回这一项的结果（出错照常抛给调用方，
  /// 不影响队里后面的项）。
  ///
  /// 为什么要排队：按名称取得标签与回收标签都是异步的数据库操作。连着换
  /// 模板或撤销后马上再套用时，若上一份的解析还没回来，回收与新的解析
  /// 交错，可能把新模板刚勾上的同名标签删掉。
  Future<void> _enqueueTagWork(Future<void> Function() task) {
    final run = _tagWork.then((_) => task());
    _tagWork = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }

  Future<void> _applyTags(DiaryTemplateApplied applied) async {
    final tags = applied.template.tags;
    // 排队等待期间已撤销、换了模板或离开页面：不必再新建标签。
    if (tags.isEmpty || _disposed || !identical(_applied, applied)) return;
    final result = await _database.ensureTagsByName(
      tags.map((tag) => (name: tag.name, color: tag.color)),
    );
    applied.createdTagIds.addAll(result.created);
    if (_disposed || !identical(_applied, applied)) {
      // 解析期间已撤销或离开页面：新建的标签没人用，回收掉。
      if (!identical(_applied, applied)) {
        await _database.deleteTagsIfUnused(result.created);
      }
      return;
    }
    for (final id in result.ids.values) {
      if (_port.meta.value.tagIds.contains(id)) continue;
      _port.meta.setTagSelected(id, true);
      applied.addedTagIds.add(id);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
