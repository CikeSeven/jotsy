import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_breakpoints.dart';
import '../../../core/services/app_service.dart';
import '../../settings/widgets/style_editor/style_editor_common.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/desktop_page_arrows.dart';
import '../../widgets/unsaved_changes_dialog.dart';
import '../controllers/diary_template_editor_controller.dart';
import '../controllers/diary_templates_controller.dart';
import '../models/diary_template.dart';
import '../sections/diary_template_editor_content_tab.dart';
import '../sections/diary_template_editor_settings_tab.dart';

/// 模板编辑页：新建、编辑我的模板，以及“另存为模板”预填后的确认。
///
/// 两个标签：“内容”（标题格式、插入变量、正文）与“设置”（名称、外观、
/// 预设、推荐时间）。标签之间不能左右滑动切换——正文里的横向拖动是选择
/// 文字，不能被翻页抢走。有未保存改动时返回先确认（与日记编辑页同一个
/// 对话框）。名称为空时不保存，切到“设置”标签并在名称框下提示。
class DiaryTemplateEditorPage extends ConsumerStatefulWidget {
  const DiaryTemplateEditorPage({super.key, this.template});

  /// 要编辑的模板；null 为新建，id 为空的模板为预填好、尚未保存的新模板。
  final DiaryTemplate? template;

  @override
  ConsumerState<DiaryTemplateEditorPage> createState() =>
      _DiaryTemplateEditorPageState();
}

class _DiaryTemplateEditorPageState
    extends ConsumerState<DiaryTemplateEditorPage>
    with SingleTickerProviderStateMixin {
  late final DiaryTemplateEditorController _editor =
      DiaryTemplateEditorController(widget.template);
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    _editor.dispose();
    super.dispose();
  }

  /// 保存成功返回 true；名称为空或写入失败返回 false 并提示。
  Future<bool> _save() async {
    final settings = await ref.read(settingsServiceProvider.future);
    if (!mounted) return false;
    final templates = createDiaryTemplatesController(ref, settings);
    try {
      final saved = await _editor.save(templates);
      if (!saved && mounted && _editor.nameMissing) _tabs.animateTo(1);
      return saved;
    } catch (error) {
      debugPrint('Saving diary template failed: $error');
      if (mounted) {
        showStyleEditorMessage(context, context.l10n.diaryTemplatesSaveFailed);
      }
      return false;
    }
  }

  Future<void> _saveAndClose() async {
    if (await _save() && mounted) Navigator.of(context).pop();
  }

  Future<void> _attemptExit() async {
    if (!_editor.dirty) {
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
        await _saveAndClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final scaffold = Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppTopBar(
        contentMaxWidth: AppContentWidth.editor,
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => unawaited(_attemptExit()),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
        title: Text(
          _editor.isNew
              ? l10n.diaryTemplateEditorNewTitle
              : l10n.diaryTemplateEditorEditTitle,
        ),
        actions: <Widget>[
          ListenableBuilder(
            listenable: _editor,
            builder: (BuildContext context, Widget? child) => TextButton(
              onPressed: _editor.saving
                  ? null
                  : () => unawaited(_saveAndClose()),
              child: Text(l10n.commonSave),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: <Widget>[
            Tab(text: l10n.diaryTemplateEditorTabContent),
            Tab(text: l10n.diaryTemplateEditorTabSettings),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        physics: const NeverScrollableScrollPhysics(),
        children: <Widget>[
          DiaryTemplateEditorContentTab(
            controller: _editor,
            keyboardVisible: keyboardVisible,
          ),
          DiaryTemplateEditorSettingsTab(controller: _editor),
        ],
      ),
    );
    // 只有 canPop 随改动变化；child 不跟着重建，正文输入时整页不重排。
    return ListenableBuilder(
      listenable: _editor,
      child: scaffold,
      builder: (BuildContext context, Widget? child) => PopScope(
        canPop: !_editor.dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) unawaited(_attemptExit());
        },
        // 桌面上 Esc 与顶栏返回按钮相同（有未保存的改动时先确认）。
        child: DesktopPageKeys(
          onEscape: () => unawaited(_attemptExit()),
          child: child!,
        ),
      ),
    );
  }
}
