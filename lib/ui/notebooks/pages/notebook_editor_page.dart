import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../settings/providers/app_features_provider.dart';
import '../../settings/widgets/style_editor/style_editor_common.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/route_entrance_waiter.dart';
import '../../widgets/unsaved_changes_dialog.dart';
import '../controllers/notebook_editor_controller.dart';
import '../sections/notebook_editor_appearance.dart';
import '../sections/notebook_editor_behavior.dart';
import '../sections/notebook_editor_goal.dart';
import '../sections/notebook_editor_rules.dart';
import '../viewmodels/notebook_view.dart';

/// 日记本编辑页：新建与编辑共用。
///
/// 自上而下：实时预览、名称与简介、图标、颜色、封面图、类型（仅新建）、
/// 规则（仅智能日记本）、隐私与写作目标（仅普通日记本）、默认排序、新建时
/// 套用的模板。表单状态在
/// [NotebookEditorController]，页面只负责组合、导航与提示。保存成功后带着
/// 日记本 id 返回；有未保存改动时返回先确认（与其他编辑页同一个对话框）。
class NotebookEditorPage extends ConsumerStatefulWidget {
  const NotebookEditorPage({
    super.key,
    this.notebookId,
    this.initialKind = NotebookKind.manual,
    this.initialName,
    this.initialPayload,
  });

  /// 要编辑的日记本；null 为新建。
  final String? notebookId;

  /// 新建时预选的类型与名称（收录选择器里“新建并加入”会预填名称）。
  final NotebookKind initialKind;
  final String? initialName;

  /// 新建时预填的设置（日历范围、搜索页“存为日记本”预填规则）；编辑时忽略。
  final NotebookPayload? initialPayload;

  /// 打开编辑页；保存后返回日记本 id，未保存返回 null。
  static Route<String> route({
    String? notebookId,
    NotebookKind initialKind = NotebookKind.manual,
    String? initialName,
    NotebookPayload? initialPayload,
  }) {
    return MaterialPageRoute<String>(
      builder: (_) => NotebookEditorPage(
        notebookId: notebookId,
        initialKind: initialKind,
        initialName: initialName,
        initialPayload: initialPayload,
      ),
    );
  }

  @override
  ConsumerState<NotebookEditorPage> createState() => _NotebookEditorPageState();
}

class _NotebookEditorPageState extends ConsumerState<NotebookEditorPage> {
  final FocusNode _nameFocus = FocusNode();
  final RouteEntranceWaiter _entrance = RouteEntranceWaiter();
  NotebookEditorController? _editor;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    final id = widget.notebookId;
    if (id == null) {
      _editor = NotebookEditorController(
        initialKind: widget.initialKind,
        initialName: widget.initialName,
        initialPayload: widget.initialPayload,
      );
      // 等页面滑入结束再聚焦名称框：键盘不与转场叠在一起。
      _entrance.schedule(this, _nameFocus.requestFocus);
    } else {
      unawaited(_load(id));
    }
  }

  /// 编辑时读一次数据库行作为表单初值；之后的数据库变化不回灌表单。
  Future<void> _load(String id) async {
    final row = await ref.read(appDatabaseProvider).getNotebook(id);
    if (!mounted) return;
    setState(() {
      if (row == null) {
        _missing = true;
      } else {
        _editor = NotebookEditorController(notebook: NotebookView(row));
      }
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    _nameFocus.dispose();
    _editor?.dispose();
    super.dispose();
  }

  /// 保存成功返回 id；名称为空或写入失败返回 null（失败时提示）。
  Future<String?> _save(NotebookEditorController editor) async {
    try {
      return await editor.save(ref.read(appDatabaseProvider));
    } catch (error) {
      debugPrint('Saving notebook failed: $error');
      if (mounted) {
        showStyleEditorMessage(context, context.l10n.notebookSaveFailed);
      }
      return null;
    }
  }

  Future<void> _saveAndClose(NotebookEditorController editor) async {
    final id = await _save(editor);
    if (id != null && mounted) Navigator.of(context).pop(id);
  }

  Future<void> _attemptExit() async {
    final editor = _editor;
    if (editor == null || !editor.dirty) {
      Navigator.of(context).pop();
      return;
    }
    final decision = await showUnsavedChangesDialog(context);
    if (!mounted) return;
    switch (decision) {
      case UnsavedChangesDecision.cancel:
        return;
      case UnsavedChangesDecision.discard:
        Navigator.of(context).pop();
      case UnsavedChangesDecision.saveAndExit:
        await _saveAndClose(editor);
    }
  }

  Future<void> _pickCover(NotebookEditorController editor) async {
    final l10n = context.l10n;
    final result = await editor.pickCover();
    if (!mounted) return;
    switch (result) {
      case NotebookCoverPickResult.missingPath:
        showStyleEditorMessage(context, l10n.autoT0088);
      case NotebookCoverPickResult.failed:
        showStyleEditorMessage(context, l10n.publishCoverImportFailed);
      case NotebookCoverPickResult.cancelled:
      case NotebookCoverPickResult.picked:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final editor = _editor;
    final isNew = widget.notebookId == null;
    final appBar = AppTopBar(
      leading: IconButton(
        tooltip: l10n.commonBack,
        onPressed: () => unawaited(_attemptExit()),
        icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
      ),
      title: Text(isNew ? l10n.notebookNew : l10n.notebookEditTitle),
      actions: <Widget>[
        if (editor != null)
          ListenableBuilder(
            listenable: editor,
            builder: (BuildContext context, Widget? child) => TextButton(
              onPressed: editor.canSave
                  ? () => unawaited(_saveAndClose(editor))
                  : null,
              child: Text(l10n.commonSave),
            ),
          ),
      ],
    );
    // 日记模板功能关闭时隐藏入口，数据保留：没有“默认模板”一项，这本已设的
    // 模板 id 照常随保存写回（编辑器不改动它）。
    final templatesEnabled = ref.watch(
      appFeaturesProvider.select((features) => features.templates),
    );
    final Widget body;
    if (editor != null) {
      body = ListenableBuilder(
        listenable: editor,
        builder: (BuildContext context, Widget? child) =>
            _buildForm(context, editor, templatesEnabled: templatesEnabled),
      );
    } else if (_missing) {
      body = EmptyHint(
        icon: FontAwesomeIcons.book,
        message: l10n.notebookMissing,
      );
    } else {
      body = const DelayedLoadingIndicator();
    }
    final scaffold = Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: appBar,
      body: body,
    );
    if (editor == null) return scaffold;
    // 只有 canPop 随改动变化；child 不跟着重建，输入时整页不重排。
    return ListenableBuilder(
      listenable: editor,
      child: scaffold,
      builder: (BuildContext context, Widget? child) => PopScope(
        canPop: !editor.dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_attemptExit());
        },
        child: child!,
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    NotebookEditorController editor, {
    required bool templatesEnabled,
  }) {
    const gap = SizedBox(height: AppSpacing.xxl);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        0,
        AppSpacing.l,
        0,
        AppSpacing.xxxl + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[
        NotebookEditorPreview(controller: editor),
        gap,
        NotebookEditorTextFields(controller: editor, nameFocus: _nameFocus),
        gap,
        NotebookEditorAppearance(
          controller: editor,
          onPickCover: () => _pickCover(editor),
        ),
        if (editor.isNew) ...<Widget>[
          gap,
          NotebookEditorTypeSection(controller: editor),
        ],
        if (editor.isSmart) ...<Widget>[
          gap,
          NotebookEditorRulesSection(controller: editor),
        ],
        if (!editor.isSmart) ...<Widget>[
          gap,
          NotebookEditorPrivacySection(controller: editor),
          gap,
          NotebookEditorGoalSection(controller: editor),
        ],
        gap,
        NotebookEditorSortSection(controller: editor),
        if (templatesEnabled) ...<Widget>[
          gap,
          NotebookEditorTemplateSection(controller: editor),
        ],
      ],
    );
  }
}
