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

  /// 建议条的“全部”：打开完整的模板面板。面板是新路由，会收起键盘；套用
  /// 后把焦点还给正文。
  Future<void> openTemplatePicker() async {
    final selection = await showDiaryTemplatePickerSheet(
      _state.context,
      diaryDate: _state._templateDiaryDate,
    );
    if (selection == null || !_state.mounted) return;
    await _applyTemplate(selection, DiaryTemplateApplySource.picker);
  }

  /// 新建空白页初始化时套用入口带来的模板或自动套用的模板，在草稿自动保存
  /// 设定基线之前完成（见 [prepareCreateEntry]）。等待期间用户已经开始写，
  /// 套用会自行放弃。
  Future<void> applyInitialTemplate() async {
    final launch = _state.widget.createTemplate;
    if (launch != null) {
      await _applyTemplate(
        launch,
        DiaryTemplateApplySource.launch,
        announce: false,
      );
      return;
    }
    final settings = await _state.ref.read(settingsServiceProvider.future);
    final autoId = DiaryTemplatePrefs.decode(
      settings.diaryTemplatePrefsRaw,
    ).autoTemplateId;
    if (autoId == null || !_state.mounted) return;
    final template = await loadDiaryTemplate(
      _state._database,
      _state.context.l10n,
      autoId,
    );
    if (template == null || !_state.mounted) return;
    await _applyTemplate(
      DiaryTemplateSelection(template),
      DiaryTemplateApplySource.auto,
    );
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

  Future<void> _applyTemplate(
    DiaryTemplateSelection selection,
    DiaryTemplateApplySource source, {
    bool announce = true,
  }) async {
    final applied = await _state._templates.apply(selection, source: source);
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
      title.trim().isNotEmpty ||
      diaryDocumentHasVisibleContent(_state._contentController.document);

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
    required List<Map<String, Object?>> ops,
    required int caret,
  }) {
    final document = decodeDiaryContentToDocument(jsonEncode(ops));
    _state.setState(() {
      _state._titleController.text = title;
      _state._controller.replaceContentController(
        quill.QuillController(
          document: document,
          selection: TextSelection.collapsed(offset: caret),
        ),
      );
    });
    return _state._currentContentDocJson;
  }
}
