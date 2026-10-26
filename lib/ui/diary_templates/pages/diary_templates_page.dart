import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../diaries/models/style_library/style_code.dart';
import '../../settings/widgets/style_editor/style_editor_common.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../controllers/diary_templates_controller.dart';
import '../models/diary_template.dart';
import '../providers/diary_template_providers.dart';
import '../sections/diary_template_restore_sheet.dart';
import '../sections/diary_templates_lists.dart';
import '../sections/diary_templates_settings_group.dart';
import 'diary_template_auto_apply_page.dart';
import 'diary_template_editor_page.dart';
import '../../widgets/form_width.dart';

/// 日记模板管理页（设置 → 编辑器设置 → 日记模板）。
///
/// 自上而下：“新建日记时”的建议条开关与自动套用入口（时间段与默认模板在
/// [DiaryTemplateAutoApplyPage]）、我的模板（拖动排序、编辑、
/// 复制、复制模板码、删除可撤销）、内置模板（点按即编辑、复制、复制模板码、
/// 改过的可恢复默认、删除可撤销；删除的不再占位，列表末尾一行可把它们
/// 恢复回来）。顶栏可从剪贴板导入模板码或新建模板。读写都经
/// [DiaryTemplatesController]，页面只负责组合与提示。
class DiaryTemplatesPage extends ConsumerStatefulWidget {
  const DiaryTemplatesPage({super.key});

  @override
  ConsumerState<DiaryTemplatesPage> createState() => _DiaryTemplatesPageState();
}

class _DiaryTemplatesPageState extends ConsumerState<DiaryTemplatesPage> {
  // 拖动排序后先按新顺序显示，等数据库流推送同样的顺序再交还给它，松手时
  // 列表不会先跳回旧位置。
  List<String>? _pendingOrder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppTopBar(
        contentMaxWidth: FormWidth.maxWidth,
        title: Text(l10n.diaryTemplatesTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.diaryTemplatesImport,
            onPressed: settings == null ? null : () => _import(settings),
            icon: const FaIcon(FontAwesomeIcons.paste, size: 16),
          ),
          IconButton(
            tooltip: l10n.diaryTemplatesNew,
            onPressed: () => _openEditor(null),
            icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
          ),
        ],
      ),
      body: settings == null
          ? const DelayedLoadingIndicator()
          : _buildBody(context, settings),
    );
  }

  Widget _buildBody(BuildContext context, SettingsService settings) {
    final l10n = context.l10n;
    final controller = createDiaryTemplatesController(ref, settings);
    final library = watchDiaryTemplateLibrary(ref, l10n, live: true).library;
    final mine = _ordered(library.userTemplates);
    final deleted = library.deletedBuiltIns;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final side = FormWidth.extra(constraints.maxWidth);
        return CustomScrollView(
          slivers: <Widget>[
            // 宽窗口：每段内容都补上居中留白（各段自带左右 16，手机上补 0）。
            for (final sliver in <Widget>[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.m),
                  child: DiaryTemplatesSettingsGroup(
                    library: library,
                    onStripChanged: (value) =>
                        unawaited(controller.setStripEnabled(value)),
                    onOpenAutoApply: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const DiaryTemplateAutoApplyPage(),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: DiaryTemplatesSectionHeader(
                  title: l10n.diaryTemplatesMineGroup,
                ),
              ),
              if (mine.isEmpty)
                const SliverToBoxAdapter(child: DiaryTemplatesMineEmpty())
              else
                DiaryTemplatesMineSliver(
                  templates: mine,
                  onTap: _openEditor,
                  onAction: (template, action) => _handleAction(
                    controller,
                    template,
                    action,
                    builtIn: false,
                  ),
                  onReorder: (oldIndex, newIndex) =>
                      _reorder(controller, mine, oldIndex, newIndex),
                ),
              SliverToBoxAdapter(
                child: DiaryTemplatesSectionHeader(
                  title: l10n.diaryTemplatesBuiltInGroup,
                ),
              ),
              DiaryTemplatesBuiltInSliver(
                templates: library.builtIns
                    .where((template) => !library.isDeleted(template))
                    .toList(growable: false),
                editedIds: library.editedBuiltIns,
                onTap: _openEditor,
                onAction: (template, action) =>
                    _handleAction(controller, template, action, builtIn: true),
              ),
              if (deleted.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.l,
                    AppSpacing.s,
                    AppSpacing.l,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: DiaryTemplatesRestoreRow(
                      key: const ValueKey<String>('template_restore_row'),
                      count: deleted.length,
                      onTap: () => _restoreDeleted(controller, deleted),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ])
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: side),
                sliver: sliver,
              ),
          ],
        );
      },
    );
  }

  List<DiaryTemplate> _ordered(List<DiaryTemplate> templates) {
    final pending = _pendingOrder;
    if (pending == null) return templates;
    final ids = templates.map((t) => t.id).toList();
    if (ids.length == pending.length &&
        Iterable<int>.generate(ids.length).every((i) => ids[i] == pending[i])) {
      // 数据库已经是新顺序：之后照常跟随它。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _pendingOrder = null);
      });
      return templates;
    }
    final byId = {for (final t in templates) t.id: t};
    return <DiaryTemplate>[
      for (final id in pending) ?byId[id],
      ...templates.where((t) => !pending.contains(t.id)),
    ];
  }

  void _reorder(
    DiaryTemplatesController controller,
    List<DiaryTemplate> current,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex == newIndex) return;
    final ids = current.map((t) => t.id).toList();
    ids.insert(newIndex, ids.removeAt(oldIndex));
    setState(() => _pendingOrder = ids);
    unawaited(controller.reorder(ids));
  }

  Future<void> _openEditor(DiaryTemplate? template) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DiaryTemplateEditorPage(template: template),
      ),
    );
  }

  String _name(DiaryTemplate template) => template.name.isEmpty
      ? context.l10n.diaryTemplateUntitled
      : template.name;

  /// [builtIn]：操作来自内置模板列表（删除记进偏好，而不是删数据库行）。
  Future<void> _handleAction(
    DiaryTemplatesController controller,
    DiaryTemplate template,
    DiaryTemplateAction action, {
    required bool builtIn,
  }) async {
    final l10n = context.l10n;
    switch (action) {
      case DiaryTemplateAction.edit:
        await _openEditor(template);
      case DiaryTemplateAction.duplicate:
        await controller.duplicate(
          template,
          name: l10n.diaryTemplatesCopyName(_name(template)),
        );
      case DiaryTemplateAction.copyCode:
        final code = controller.exportCode(template);
        if (code != null) {
          await Clipboard.setData(ClipboardData(text: code));
        }
        if (!mounted) return;
        showStyleEditorMessage(
          context,
          code == null
              ? l10n.diaryTemplatesCodeTooLong
              : l10n.diaryTemplatesCodeCopied,
        );
      case DiaryTemplateAction.reset:
        final reset = await controller.resetBuiltIn(template.id);
        if (reset == null || !mounted) return;
        unawaited(
          showStyleEditorUndoSnackBar(
            context,
            message: l10n.diaryTemplatesResetDone(_name(template)),
            onUndo: () => unawaited(controller.restore(reset)),
          ),
        );
      case DiaryTemplateAction.delete when builtIn:
        final removed = await controller.deleteBuiltIn(template.id);
        if (!mounted) return;
        unawaited(
          showStyleEditorUndoSnackBar(
            context,
            message: l10n.diaryTemplatesDeleted(_name(template)),
            onUndo: () => unawaited(
              controller.undoDeleteBuiltIn(template.id, removed: removed),
            ),
          ),
        );
      case DiaryTemplateAction.delete:
        final deletion = await controller.delete(template.id);
        if (deletion == null || !mounted) return;
        unawaited(
          showStyleEditorUndoSnackBar(
            context,
            message: l10n.diaryTemplatesDeleted(_name(template)),
            onUndo: () => unawaited(controller.restore(deletion)),
          ),
        );
    }
  }

  /// 从“已删除的内置模板”面板恢复一个或全部。恢复本身就能在列表里看到，
  /// 提示只是确认，不带撤销（想再删照常删除即可）。
  Future<void> _restoreDeleted(
    DiaryTemplatesController controller,
    List<DiaryTemplate> deleted,
  ) async {
    final l10n = context.l10n;
    final ids = await showDiaryTemplateRestoreSheet(
      context,
      templates: deleted,
    );
    if (ids == null || ids.isEmpty || !mounted) return;
    await controller.restoreBuiltIns(ids);
    if (!mounted) return;
    final restored = deleted.where((t) => ids.contains(t.id)).toList();
    showStyleEditorMessage(
      context,
      restored.length == 1
          ? l10n.diaryTemplatesRestoredDone(_name(restored.single))
          : l10n.diaryTemplatesRestoredAllDone(restored.length),
    );
  }

  Future<void> _import(SettingsService settings) async {
    final l10n = context.l10n;
    final controller = createDiaryTemplatesController(ref, settings);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final result = await controller.importCode(data?.text);
    if (!mounted) return;
    final id = result.templateId;
    if (id == null) {
      showStyleEditorMessage(
        context,
        result.status == StyleCodeStatus.empty
            ? l10n.diaryTemplatesImportEmpty
            : l10n.diaryTemplatesImportInvalid,
      );
      return;
    }
    final name = result.name.isEmpty ? l10n.diaryTemplateUntitled : result.name;
    unawaited(
      showStyleEditorUndoSnackBar(
        context,
        message: result.status == StyleCodeStatus.newerVersion
            ? l10n.diaryTemplatesImportedNewer(name)
            : l10n.diaryTemplatesImported(name),
        onUndo: () => unawaited(controller.removeImported(id)),
      ),
    );
  }
}
