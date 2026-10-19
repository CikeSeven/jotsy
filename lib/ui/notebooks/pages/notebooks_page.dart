import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../diary_templates/sections/diary_templates_lists.dart';
import '../../settings/widgets/style_editor/style_editor_common.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../controllers/notebooks_controller.dart';
import '../providers/notebook_providers.dart';
import '../sections/notebook_action_flows.dart';
import '../sections/notebook_action_sheets.dart';
import '../sections/notebooks_page_lists.dart';
import '../viewmodels/notebook_view.dart';
import '../widgets/notebooks_empty_state.dart';
import 'notebook_editor_page.dart';

/// 日记本管理页（书架面板“管理”与设置首页入口）。
///
/// 三组：我的日记本（含置顶）、智能日记本、已合上；每组按住手柄拖动排序，
/// 写入时保持其他分组的相对顺序（[notebookOrderAfterReorder]）。行尾“更多”
/// 打开操作面板，编辑、置顶、合并、合上与删除都经 [runNotebookAction]，与
/// 书架面板同一套流程；删除时这一行先收起再删，撤销后重新展开。
class NotebooksPage extends ConsumerStatefulWidget {
  const NotebooksPage({super.key});

  @override
  ConsumerState<NotebooksPage> createState() => _NotebooksPageState();
}

class _NotebooksPageState extends ConsumerState<NotebooksPage> {
  // 拖动排序后先按新顺序显示，等数据库流推送同样的顺序再交还给它，松手时
  // 列表不会先跳回旧位置。
  List<String>? _pendingOrder;
  final Set<String> _collapsing = <String>{};
  final Set<String> _appearing = <String>{};

  Future<void> _openEditor([String? notebookId]) => Navigator.of(
    context,
  ).push(NotebookEditorPage.route(notebookId: notebookId));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final notebooks = ref.watch(notebooksProvider).value;
    final counts =
        ref.watch(notebookEntryCountsProvider).value ?? const <String, int>{};
    final Widget body;
    if (notebooks == null) {
      body = const DelayedLoadingIndicator();
    } else if (notebooks.isEmpty) {
      body = Center(child: NotebooksEmptyState(onCreate: _openEditor));
    } else {
      body = _buildList(context, notebooks, counts);
    }
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppTopBar(
        title: Text(l10n.notebookTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.notebookNew,
            onPressed: () => unawaited(_openEditor()),
            icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildList(
    BuildContext context,
    List<NotebookView> notebooks,
    Map<String, int> counts,
  ) {
    final l10n = context.l10n;
    final groups = NotebookShelfGroups(_ordered(notebooks));
    _settleAppearing(notebooks);
    Widget section(String title, List<NotebookView> members) =>
        SliverMainAxisGroup(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: DiaryTemplatesSectionHeader(title: title),
            ),
            NotebooksSectionSliver(
              notebooks: members,
              counts: counts,
              collapsing: _collapsing,
              appearing: _appearing,
              onTap: (notebook) => unawaited(_openEditor(notebook.id)),
              onMore: (notebook) => unawaited(_more(notebook)),
              onReorder: (oldIndex, newIndex) =>
                  _reorder(notebooks, members, oldIndex, newIndex),
            ),
          ],
        );
    return CustomScrollView(
      slivers: <Widget>[
        if (groups.manual.isNotEmpty)
          section(l10n.notebookSectionMine, groups.manual),
        if (groups.smart.isNotEmpty)
          section(l10n.notebookSectionSmart, groups.smart),
        if (groups.closed.isNotEmpty)
          section(l10n.notebookSectionClosed, groups.closed),
        SliverToBoxAdapter(
          child: SizedBox(
            height: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }

  /// 撤销后重新出现的行只在首次构建时展开：数据库流把它推回来、这一帧建好
  /// 之后就清掉标记，滚出再滚回不会重复播放。
  void _settleAppearing(List<NotebookView> notebooks) {
    final present = <String>{
      for (final n in notebooks)
        if (_appearing.contains(n.id)) n.id,
    };
    if (present.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appearing.removeAll(present);
    });
  }

  List<NotebookView> _ordered(List<NotebookView> notebooks) {
    final pending = _pendingOrder;
    if (pending == null) return notebooks;
    final ids = notebooks.map((n) => n.id).toList();
    if (ids.length == pending.length &&
        Iterable<int>.generate(ids.length).every((i) => ids[i] == pending[i])) {
      // 数据库已经是新顺序：之后照常跟随它。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _pendingOrder = null);
      });
      return notebooks;
    }
    final byId = {for (final n in notebooks) n.id: n};
    return <NotebookView>[
      for (final id in pending) ?byId[id],
      ...notebooks.where((n) => !pending.contains(n.id)),
    ];
  }

  void _reorder(
    List<NotebookView> all,
    List<NotebookView> section,
    int oldIndex,
    int newIndex,
  ) {
    if (oldIndex == newIndex) return;
    final ids = section.map((n) => n.id).toList();
    ids.insert(newIndex, ids.removeAt(oldIndex));
    final order = notebookOrderAfterReorder(all, ids);
    setState(() => _pendingOrder = order.shelf);
    unawaited(_writeOrder(order.manual));
  }

  Future<void> _writeOrder(List<String> manual) async {
    try {
      await ref.read(notebooksControllerProvider).reorder(manual);
    } catch (error) {
      debugPrint('Reordering notebooks failed: $error');
      if (!mounted) return;
      setState(() => _pendingOrder = null);
      showStyleEditorMessage(context, context.l10n.notebookActionFailed);
    }
  }

  Future<void> _more(NotebookView notebook) async {
    final action = await showNotebookActionsSheet(context, notebook: notebook);
    if (action == null || !mounted) return;
    final id = notebook.id;
    await runNotebookAction(
      context,
      ref,
      notebook: notebook,
      action: action,
      hooks: NotebookDeleteHooks(
        beforeDelete: () async {
          final duration = ExpressiveMotion.duration(
            context,
            ExpressiveMotion.medium,
          );
          setState(() => _collapsing.add(id));
          // 等这一行收起再删：删除后数据库流会立即把这一行拿掉。
          await Future<void>.delayed(duration);
        },
        // 删除成功后保持收起标记：数据库流拿掉这一行之前它不会先弹回来。
        onDeleteFailed: () {
          if (mounted) setState(() => _collapsing.remove(id));
        },
        onRestored: () {
          if (!mounted) return;
          setState(() {
            _collapsing.remove(id);
            _appearing.add(id);
          });
        },
      ),
    );
  }
}
