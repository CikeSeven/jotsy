import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../widgets/app_modal/app_dialog.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/expressive_icon_swap.dart';
import '../../widgets/list_item_presence.dart';
import '../../widgets/select_all_button.dart';
import '../controllers/recycle_bin_controller.dart';
import '../widgets/recycle_bin_selection_bar.dart';
import '../widgets/recycle_bin_tile.dart';
import '../../widgets/form_width.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';

/// 回收站：已软删除的日记，最近删除的在前。
///
/// - 每行都带勾选框，点按或长按切换；顶栏可全选 / 取消全选；
/// - 有勾选时底部升起操作栏：恢复，或确认后彻底删除；
/// - 有勾选时顶栏返回键换成 ✕，系统返回先清空勾选。
///
/// 页面只做装配与选择、收起等界面状态；写库经 [RecycleBinController]。
class RecycleBinPage extends ConsumerStatefulWidget {
  const RecycleBinPage({super.key});

  @override
  ConsumerState<RecycleBinPage> createState() => _RecycleBinPageState();
}

class _RecycleBinPageState extends ConsumerState<RecycleBinPage> {
  late final RecycleBinController _controller = RecycleBinController(
    database: ref.read(appDatabaseProvider),
    mediaCleanup: ref.read(diaryMediaCleanupServiceProvider),
  );

  final Set<String> _selectedIds = <String>{};

  /// 恢复 / 彻底删除时正在播放收起动画、等待提交的条目；数据流确认移除后
  /// 在 build 中清理，提交失败的重新展开。
  final Set<String> _pendingHideIds = <String>{};

  /// 本次构建列出、可以勾选的日记（不含正在收起的），供“全选”使用；在
  /// build 开头随数据流更新。
  List<String> _selectableIds = const <String>[];

  bool _operating = false;

  bool get _hasSelection => _selectedIds.isNotEmpty;

  bool get _allSelected =>
      _selectableIds.isNotEmpty && _selectedIds.containsAll(_selectableIds);

  void _toggleSelection(String diaryId) {
    if (_operating) return;
    setState(() {
      if (!_selectedIds.remove(diaryId)) _selectedIds.add(diaryId);
    });
  }

  void _toggleSelectAll() {
    if (_operating) return;
    setState(() {
      if (_allSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_selectableIds);
      }
    });
  }

  void _clearSelection() => setState(_selectedIds.clear);

  Future<void> _restoreSelected() async {
    final l10n = context.l10n;
    await _commitSelected(
      _controller.restore,
      done: (count) => l10n.autoT0191(count.toString()),
      partlyFailed: l10n.autoT0026,
    );
  }

  Future<void> _purgeSelected() async {
    if (!_hasSelection || _operating) return;
    final l10n = context.l10n;
    if (!await _confirmPurge(_selectedIds.length) || !mounted) return;
    await _commitSelected(
      _controller.purge,
      done: (count) => l10n.autoT0192(count.toString()),
      partlyFailed: l10n.autoT0027,
    );
  }

  /// 恢复与彻底删除共用的提交流程：
  /// 1. 清空勾选（底栏随之收起）并把这些条目标为收起，与底栏同步播放；
  /// 2. 等收起播完再写库：数据流随后移除条目时它已是 0 高度，列表不会硬跳；
  ///    减少动画时时长为 0，立即提交；
  /// 3. 写库失败的条目取消收起、重新勾选，方便直接重试。
  ///
  /// 勾选清空后系统返回不再被拦下：收起途中离开页面时照常写库（控制器不依赖
  /// 页面），只是不再提示。
  Future<void> _commitSelected(
    Future<List<String>> Function(List<String> diaryIds) commit, {
    required String Function(int count) done,
    required String partlyFailed,
  }) async {
    if (!_hasSelection || _operating) return;
    final ids = _selectedIds.toList(growable: false);
    final collapse = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    setState(() {
      _operating = true;
      _selectedIds.clear();
      _pendingHideIds.addAll(ids);
    });
    try {
      await Future<void>.delayed(collapse);
      final failedIds = await commit(ids);
      if (!mounted) return;
      if (failedIds.isNotEmpty) {
        setState(() {
          _pendingHideIds.removeAll(failedIds);
          _selectedIds.addAll(failedIds);
        });
      }
      _showHint(failedIds.isEmpty ? done(ids.length) : partlyFailed);
    } finally {
      if (mounted) setState(() => _operating = false);
    }
  }

  Future<bool> _confirmPurge(int count) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final l10n = dialogContext.l10n;
        final colorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: Text(l10n.autoT0028),
          content: Text(l10n.autoT0193(count.toString())),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );
    return confirmed == true;
  }

  void _showHint(String message) {
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(content: Text(message)),
      ),
    );
  }

  /// 数据流确认移除后清理收起与勾选状态，并记下可勾选的 id。
  void _syncWith(List<DiaryWithTags> diaries) {
    final currentIds = <String>{for (final item in diaries) item.diary.diaryId};
    _pendingHideIds.removeWhere((id) => !currentIds.contains(id));
    _selectedIds.removeWhere((id) => !currentIds.contains(id));
    _selectableIds = <String>[
      for (final item in diaries)
        if (!_pendingHideIds.contains(item.diary.diaryId)) item.diary.diaryId,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final deletedAsync = ref.watch(deletedDiariesProvider);
    // 私密日记本里的日记不露出内容，只显示占位（仍可勾选恢复或彻底删除）。
    final privateIds =
        ref.watch(privateDiaryIdsProvider).value ?? const <String>{};
    // 先按最新数据整理界面状态，顶栏的全选与列表看到的是同一份。
    final diaries = deletedAsync.value;
    if (diaries != null) _syncWith(diaries);
    final canSelectAll = _selectableIds.isNotEmpty;

    return PopScope(
      canPop: !_hasSelection,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _clearSelection();
      },
      child: AppPageBackground(
        area: AppBackgroundArea.settings,
        child: Builder(
          builder: (BuildContext context) => Scaffold(
            backgroundColor: AppPageBackdrop.pageColorOf(context),
            appBar: AppTopBar(
              contentMaxWidth: FormWidth.maxWidth,
              leading: ExpressiveIconSwap(
                switchKey: _hasSelection,
                child: _hasSelection
                    ? IconButton(
                        tooltip: l10n.commonCancel,
                        onPressed: _clearSelection,
                        icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
                      )
                    : IconButton(
                        tooltip: l10n.commonBack,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const FaIcon(
                          FontAwesomeIcons.angleLeft,
                          size: 18,
                        ),
                      ),
              ),
              // 勾选数量变化时标题淡入淡出，而不是硬切。
              title: AnimatedSwitcher(
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.fast,
                ),
                switchInCurve: ExpressiveMotion.effects,
                switchOutCurve: ExpressiveMotion.exit,
                child: Text(
                  _hasSelection
                      ? l10n.autoT0099(_selectedIds.length.toString())
                      : l10n.autoT0029,
                  key: ValueKey<int>(_hasSelection ? _selectedIds.length : -1),
                ),
              ),
              actions: <Widget>[
                // 回收站清空后全选按钮随列表一起退场。
                ExpressiveIconSwap(
                  switchKey: canSelectAll,
                  child: canSelectAll
                      ? SelectAllButton(
                          allSelected: _allSelected,
                          onPressed: _operating ? null : _toggleSelectAll,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  child: deletedAsync.when(
                    loading: () => const DelayedLoadingIndicator(),
                    error: (error, _) =>
                        Center(child: Text(l10n.autoT0031(error.toString()))),
                    data: (diaries) => _buildList(diaries, privateIds),
                  ),
                ),
                RecycleBinSelectionBar(
                  visible: _hasSelection,
                  onRestore: _operating ? null : _restoreSelected,
                  onPurge: _operating ? null : _purgeSelected,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<DiaryWithTags> diaries, Set<String> privateIds) {
    final itemDuration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    // 最后一条移走后与空态交叉淡入。
    return AnimatedSwitcher(
      duration: itemDuration,
      switchInCurve: ExpressiveMotion.effects,
      switchOutCurve: ExpressiveMotion.exit,
      child: diaries.isEmpty
          ? EmptyHint(
              key: const ValueKey<String>('recycle_empty'),
              icon: FontAwesomeIcons.trashCan,
              message: context.l10n.autoT0032,
            )
          : LayoutBuilder(
              key: const ValueKey<String>('recycle_list'),
              builder: (BuildContext context, BoxConstraints constraints) {
                final side = FormWidth.gutter(constraints.maxWidth);
                return ListView.builder(
                  // 底栏收起时列表一直延伸到屏幕底，末尾让出系统导航条。
                  padding: EdgeInsets.fromLTRB(
                    side,
                    AppSpacing.s,
                    side,
                    AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: diaries.length,
                  itemBuilder: (BuildContext context, int index) {
                    final diary = diaries[index].diary;
                    final id = diary.diaryId;
                    // 间距放在收起容器内，收起时连同间距一起收掉。
                    return ListItemPresence(
                      key: ValueKey<String>('recycle_$id'),
                      visible: !_pendingHideIds.contains(id),
                      appearing: false,
                      duration: itemDuration,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s),
                        child: RecycleBinTile(
                          diary: diary,
                          isPrivate: privateIds.contains(id),
                          selected: _selectedIds.contains(id),
                          onTap: () => _toggleSelection(id),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
