// ignore_for_file: library_private_types_in_public_api, invalid_use_of_protected_member

part of 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';

/// 新建编辑页与日记模板的衔接。
///
/// 套用、撤销与“原样未动不算草稿”的规则都在 [DiaryTemplateApplyController]
/// 里；这里只把编辑页的标题、正文、元数据接给它（[_EditDiaryTemplatePort]），
/// 并负责三种套用时机的提示：
/// - 建议条或“全部”面板里选中：提示“已套用”，可撤销；
/// - 从新建入口的模板面板进来（[EditDiaryPage.createTemplate]）：用户刚在
///   预览里看过，直接套用、不提示；
/// - 偏好里设了自动套用：提示“已自动套用”，可撤销。
extension EditDiaryTemplateFlow on EditDiaryController {
  /// 建议条上点了一个模板。
  Future<void> applyTemplateFromStrip(DiaryTemplate template) => _applyTemplate(
    DiaryTemplateSelection(template),
    DiaryTemplateApplySource.strip,
  );

  /// 建议条的“全部”与顶栏菜单的“选择模板”：打开完整的模板面板。面板是
  /// 新路由，会收起键盘；套用后把焦点还给正文。
  ///
  /// 建议条只在空白时出现；菜单里任何时候都能点，所以先看此刻能否套用：
  /// 标题与正文为空，或仍是本次套用的模板原样（选中后替换它）；用户已经
  /// 写了字就只提示、不打开面板。面板打开期间状态可能变化，选中后由
  /// [_applyTemplate] 再检查一次。
  Future<void> openTemplatePicker() async {
    if (!_state._templates.canApply) {
      _showTemplateNotBlankHint();
      return;
    }
    final selection = await showDiaryTemplatePickerSheet(
      _state.context,
      diaryDate: _state._templateDiaryDate,
    );
    if (selection == null || !_state.mounted) return;
    await _applyTemplate(
      selection,
      DiaryTemplateApplySource.picker,
      replacePristine: true,
    );
  }

  /// 新建空白页初始化时套用入口带来的模板或自动套用的模板，在草稿自动保存
  /// 设定基线之前完成（见 [prepareCreateEntry]）。等待期间用户已经开始写，
  /// 套用会自行放弃。
  ///
  /// 自动套用按偏好给出的候选顺序（命中的时间段由具体到宽泛，最后是默认
  /// 模板，见 `DiaryTemplatePrefs.autoApplyCandidates`）逐个查库，套用第一个
  /// 仍存在的：规则指向的模板被删掉时自然落到下一个，而不是什么都不套。
  /// “此刻”与套用控制器用同一个时钟，时间段与变量里的时间不会错开。
  ///
  /// 日记模板功能关闭时什么也不套用（入口带来的、自动套用的都不套），新建
  /// 空白日记就是空白；偏好与模板原样保留，重新开启即恢复。
  Future<void> applyInitialTemplate() async {
    // 先等设置就绪：之前 appFeaturesProvider 给的是默认值。
    final settings = await _state.ref.read(settingsServiceProvider.future);
    if (!_state.mounted) return;
    if (!_state.ref.read(appFeaturesProvider).templates) return;
    final launch = _state.widget.createTemplate;
    if (launch != null) {
      await _applyTemplate(
        launch,
        DiaryTemplateApplySource.launch,
        announce: false,
      );
      return;
    }
    final prefs = DiaryTemplatePrefs.decode(settings.diaryTemplatePrefsRaw);
    final candidates = prefs.autoApplyCandidates(
      now: _state._templateClock(),
      diaryDate: _state._templateDiaryDate,
    );
    for (final id in candidates) {
      final template = await loadDiaryTemplate(
        _state._database,
        _state.context.l10n,
        id,
        deletedBuiltIns: prefs.hiddenBuiltIns,
      );
      if (!_state.mounted) return;
      if (template == null) continue;
      await _applyTemplate(
        DiaryTemplateSelection(template),
        DiaryTemplateApplySource.auto,
      );
      return;
    }
  }

  /// 顶栏菜单“存为模板”：把正在写的标题、正文（去掉媒体）、标签、心情与
  /// 精力预填进一个新模板的编辑页。
  Future<void> saveAsTemplate() async {
    final meta = _state._meta.value;
    final tags = (await _state._database.watchAllTags().first)
        .where((tag) => meta.tagIds.contains(tag.id))
        .toList(growable: false);
    if (!_state.mounted) return;
    await openSaveAsTemplate(
      _state.context,
      title: _state._titleController.text,
      contentDocJson: _state._currentContentDocJson,
      tags: tags,
      mood: meta.moodEmoji,
      energy: meta.energyLevel,
    );
  }

  /// [replacePristine]：可以替换本次套用后原样未动的模板（见
  /// [DiaryTemplateApplyController.apply]）；此刻已经不能套用时提示原因。
  /// 撤销替换后的模板回到空白日记，不恢复上一个模板。
  Future<void> _applyTemplate(
    DiaryTemplateSelection selection,
    DiaryTemplateApplySource source, {
    bool announce = true,
    bool replacePristine = false,
  }) async {
    final templates = _state._templates;
    if (replacePristine && !templates.canApply) {
      _showTemplateNotBlankHint();
      return;
    }
    final applied = await templates.apply(
      selection,
      source: source,
      replacePristine: replacePristine,
    );
    if (applied == null || !_state.mounted) return;
    _state._contentFocusNode.requestFocus();
    if (!announce) return;
    final l10n = _state.context.l10n;
    final name = applied.template.name.isEmpty
        ? l10n.diaryTemplateUntitled
        : applied.template.name;
    unawaited(
      showStyleEditorUndoSnackBar(
        _state.context,
        message: source == DiaryTemplateApplySource.auto
            ? l10n.diaryTemplateAutoApplied(name)
            : l10n.diaryTemplateApplied(name),
        onUndo: () => unawaited(_state._templates.undo(applied)),
      ),
    );
  }

  /// 已经开始写了：模板只能套用在空白日记上。
  void _showTemplateNotBlankHint() {
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: _state.context,
        snackBar: SnackBar(
          content: Text(_state.context.l10n.diaryTemplateNeedsBlankEntry),
        ),
      ),
    );
  }
}

/// 把编辑页的标题、正文与元数据接给模板套用控制器。
class _EditDiaryTemplatePort implements DiaryTemplateEditorPort {
  _EditDiaryTemplatePort(this._state);

  final _EditDiaryPageState _state;

  @override
  String get title => _state._titleController.text;

  @override
  String get contentDocJson => _state._currentContentDocJson;

  @override
  bool get hasContent =>
      title.trim().isNotEmpty || _state._contentController.hasContent;

  @override
  DiaryMetaDraftController get meta => _state._meta;

  @override
  DateTime get diaryDate => _state._templateDiaryDate;

  @override
  AppLocalizations get l10n => _state.context.l10n;

  @override
  List<String> get moodOptions =>
      _state.ref.read(settingsServiceProvider).asData?.value.moodOptions ??
      SettingsService.defaultMoodOptions;

  @override
  String replaceContent({
    required String title,
    required Map<String, Object?> document,
    required int caret,
  }) {
    final body = editor.diaryEditorDocument(jsonEncode(document));
    _state.setState(() {
      _state._titleController.text = title;
      _state._controller.replaceContentController(
        editor.DiaryEditorController(
          document: body,
          selection: editor.diaryEditorSelectionAtOffset(body, caret),
        ),
      );
    });
    return _state._currentContentDocJson;
  }
}
