import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/storage/storage_usage_models.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../diaries/controllers/diary_open_flow.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/action_loading_overlay.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_gate.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/expressive_icon_swap.dart';
import '../../widgets/expressive_menu/expressive_menu_button.dart';
import '../../widgets/expressive_menu/expressive_menu_item.dart';
import '../../widgets/form_width.dart';
import '../../widgets/select_all_button.dart';
import '../../widgets/width_layout_builder.dart';
import '../controllers/storage_flows.dart';
import '../models/storage_media_filter.dart';
import '../models/storage_preferences.dart';
import '../providers/storage_providers.dart';
import '../sections/storage_filter_bar.dart';
import '../sections/storage_media_detail_sheet.dart';
import '../viewmodels/storage_labels.dart';
import '../viewmodels/storage_media_view.dart';
import '../widgets/storage_media_grid_tile.dart';
import '../widgets/storage_media_tile.dart';
import '../widgets/storage_selection_bar.dart';

/// 存储管理的媒体页：按类别与条件筛选、按大小或时间排序、列表或网格查看
/// 托管媒体，点按看详情，长按进入多选后批量压缩或删除。
///
/// - 多选时顶栏返回键换成 ✕、系统返回先清空勾选（与回收站一致）；
/// - 私密日记里的媒体默认打码，“显示”后本页内可见（上锁的先验证身份），
///   未解封的时间胶囊始终打码；
/// - 页面只做装配与选择、揭示这些界面状态；写入经 [StorageFlows]。
class StorageMediaPage extends ConsumerStatefulWidget {
  const StorageMediaPage({
    super.key,
    this.initialFilter = const StorageMediaFilter(),
  });

  final StorageMediaFilter initialFilter;

  @override
  ConsumerState<StorageMediaPage> createState() => _StorageMediaPageState();
}

class _StorageMediaPageState extends ConsumerState<StorageMediaPage>
    implements StorageFlowHost {
  late final StorageFlows _flows = StorageFlows(ref, this);
  late StorageMediaFilter _filter = widget.initialFilter;
  final Set<String> _selected = <String>{};
  bool _revealPrivate = false;
  bool _busy = false;
  String _busyText = '';

  /// 本次构建列出的项（全选、按 key 取回选中的项用），在 build 开头更新。
  List<StorageMediaItemView> _items = const [];

  bool get _selecting => _selected.isNotEmpty;

  bool get _allSelected =>
      _items.isNotEmpty && _items.every((i) => _selected.contains(i.entry.key));

  @override
  void setBusy(bool busy, [String label = '']) {
    if (!mounted) return;
    setState(() {
      _busy = busy;
      if (busy) _busyText = label;
    });
  }

  @override
  void showSnack(String message) {
    if (!mounted) return;
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(content: Text(message)),
      ),
    );
  }

  void _toggle(String key) {
    if (_busy) return;
    setState(() {
      if (!_selected.remove(key)) _selected.add(key);
    });
  }

  void _toggleAll() {
    if (_busy) return;
    setState(() {
      if (_allSelected) {
        _selected.clear();
      } else {
        _selected.addAll(_items.map((item) => item.entry.key));
      }
    });
  }

  void _clearSelection() => setState(_selected.clear);

  List<StorageMediaEntry> get _selectedEntries => [
    for (final item in _items)
      if (_selected.contains(item.entry.key)) item.entry,
  ];

  Future<void> _delete(List<StorageMediaEntry> entries) async {
    if (await _flows.delete(context, entries) && mounted) _clearSelection();
  }

  Future<void> _compress(
    List<StorageMediaEntry> entries,
    StorageUsageReport report,
  ) async {
    if (await _flows.compress(context, entries, report) && mounted) {
      _clearSelection();
    }
  }

  Future<void> _reveal(bool needsVerification) async {
    final ok = await _flows.revealPrivate(
      context,
      needsVerification: needsVerification,
    );
    if (ok && mounted) setState(() => _revealPrivate = true);
  }

  Future<void> _openDiary(String diaryId) async {
    await openDiaryPage(context, ref, diaryId: diaryId);
    // 在日记里改过、删过都会改变占用。
    if (mounted) refreshStorageViews(ref);
  }

  void _showDetail(StorageMediaItemView item, StorageUsageReport report) {
    final canCompress = item.compressible;
    unawaited(
      showStorageMediaDetail(
        context,
        item: item,
        onCompress: canCompress
            ? () => unawaited(_compress([item.entry], report))
            : null,
        onDelete: () => unawaited(_delete([item.entry])),
        onOpenDiary: (id) => unawaited(_openDiary(id)),
      ),
    );
  }

  void _savePreferences(StoragePreferences next) =>
      unawaited(ref.read(storagePreferencesProvider.notifier).save(next));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reportAsync = ref.watch(storageReportProvider);
    final compress = ref.watch(storageCompressContextProvider);
    final preferences = ref.watch(storagePreferencesProvider);
    final report = reportAsync.value;
    final view = report == null
        ? null
        : StorageMediaListView.of(
            report,
            _filter,
            sort: preferences.sort,
            compress: compress,
            revealPrivate: _revealPrivate,
          );
    _items = view?.items ?? const [];
    // 删除、压缩、换筛选后，不在列表里的勾选一并去掉。
    final listed = {for (final item in _items) item.entry.key};
    _selected.removeWhere((key) => !listed.contains(key));
    final selectedEntries = _selectedEntries;
    final selectedBytes = selectedEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.bytes,
    );
    final canCompressSelection =
        compress.supported &&
        report != null &&
        selectedEntries.any(
          (entry) => compress.estimate(entry, report) != null,
        );
    final grid =
        _filter.supportsGrid && preferences.view == StorageMediaView.grid;

    return PopScope(
      canPop: !_selecting && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting && !_busy) _clearSelection();
      },
      child: AppPageBackground(
        area: AppBackgroundArea.settings,
        child: Builder(
          builder: (BuildContext context) => Scaffold(
            backgroundColor: AppPageBackdrop.pageColorOf(context),
            appBar: AppTopBar(
              contentMaxWidth: FormWidth.maxWidth,
              leading: ExpressiveIconSwap(
                switchKey: _selecting,
                child: _selecting
                    ? IconButton(
                        tooltip: l10n.commonCancel,
                        onPressed: _busy ? null : _clearSelection,
                        icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
                      )
                    : IconButton(
                        tooltip: l10n.commonBack,
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        icon: const FaIcon(
                          FontAwesomeIcons.angleLeft,
                          size: 18,
                        ),
                      ),
              ),
              title: AnimatedSwitcher(
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.fast,
                ),
                switchInCurve: ExpressiveMotion.effects,
                switchOutCurve: ExpressiveMotion.exit,
                child: Text(
                  _selecting
                      ? l10n.storageMgmtSelectedCount(_selected.length)
                      : _filter.category?.label(l10n) ??
                            l10n.storageMgmtAllMedia,
                  key: ValueKey<int>(_selecting ? _selected.length : -1),
                ),
              ),
              actions: _selecting
                  ? <Widget>[
                      SelectAllButton(
                        allSelected: _allSelected,
                        onPressed: _busy ? null : _toggleAll,
                      ),
                    ]
                  : <Widget>[
                      if (_filter.supportsGrid)
                        IconButton(
                          tooltip: grid
                              ? l10n.storageMgmtViewList
                              : l10n.storageMgmtViewGrid,
                          onPressed: () => _savePreferences(
                            preferences.copyWith(
                              view: grid
                                  ? StorageMediaView.list
                                  : StorageMediaView.grid,
                            ),
                          ),
                          icon: ExpressiveIconSwap(
                            switchKey: grid,
                            child: FaIcon(
                              grid
                                  ? FontAwesomeIcons.list
                                  : FontAwesomeIcons.tableCells,
                              size: 16,
                            ),
                          ),
                        ),
                      ExpressiveMenuButton(
                        tooltip: l10n.storageMgmtSort,
                        icon: const FaIcon(
                          FontAwesomeIcons.arrowDownWideShort,
                          size: 16,
                        ),
                        items: <Widget>[
                          for (final sort in StorageMediaSort.values)
                            ExpressiveMenuItem(
                              selected: preferences.sort == sort,
                              onPressed: () => _savePreferences(
                                preferences.copyWith(sort: sort),
                              ),
                              child: Text(_sortLabel(l10n, sort)),
                            ),
                        ],
                      ),
                    ],
            ),
            body: Stack(
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(
                      child: reportAsync.when(
                        skipLoadingOnRefresh: true,
                        skipLoadingOnReload: true,
                        loading: () => const DelayedLoadingIndicator(),
                        error: (error, _) => EmptyHint(
                          icon: FontAwesomeIcons.triangleExclamation,
                          message: l10n.storageMgmtScanFailed,
                        ),
                        data: (report) => _buildContent(
                          report,
                          view!,
                          grid: grid,
                          canCompress: compress.supported,
                        ),
                      ),
                    ),
                    StorageSelectionBar(
                      visible: _selecting,
                      count: _selected.length,
                      bytes: selectedBytes,
                      onCompress: canCompressSelection && !_busy
                          ? () => unawaited(_compress(selectedEntries, report))
                          : null,
                      onDelete: _busy
                          ? null
                          : () => unawaited(_delete(selectedEntries)),
                    ),
                  ],
                ),
                Positioned.fill(
                  child: ActionLoadingOverlay(
                    visible: _busy,
                    label: _busyText,
                    revealDelay: DelayedLoadingGate.defaultDelay,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    StorageUsageReport report,
    StorageMediaListView view, {
    required bool grid,
    required bool canCompress,
  }) {
    final l10n = context.l10n;
    return WidthLayoutBuilder(
      builder: (BuildContext context, double width) {
        final side = FormWidth.gutter(width);
        final bottom = AppSpacing.xxl + MediaQuery.paddingOf(context).bottom;
        final header = StorageFilterBar(
          filter: _filter,
          view: view,
          canCompress: canCompress,
          padding: EdgeInsets.symmetric(horizontal: side),
          onChanged: (filter) => setState(() => _filter = filter),
          onReveal: view.maskedPrivateCount > 0
              ? () => unawaited(_reveal(view.maskedNeedsVerification))
              : null,
        );
        if (view.items.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: AppSpacing.s),
              header,
              Expanded(
                child: EmptyHint(
                  icon: FontAwesomeIcons.folderOpen,
                  message: l10n.storageMgmtEmpty,
                ),
              ),
            ],
          );
        }
        void onTap(StorageMediaItemView item) =>
            _selecting ? _toggle(item.entry.key) : _showDetail(item, report);
        void onLongPress(StorageMediaItemView item) => _toggle(item.entry.key);
        final items = view.items;
        final Widget body;
        if (grid) {
          final columns = math.max(3, (width - side * 2) ~/ 160);
          const spacing = 6.0;
          final extent = (width - side * 2 - spacing * (columns - 1)) / columns;
          body = SliverPadding(
            padding: EdgeInsets.fromLTRB(side, AppSpacing.m, side, bottom),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: spacing,
                crossAxisSpacing: spacing,
              ),
              itemCount: items.length,
              itemBuilder: (BuildContext context, int index) {
                final item = items[index];
                return StorageMediaGridTile(
                  key: ValueKey<String>('storage_grid_${item.entry.key}'),
                  item: item,
                  extent: extent,
                  selectionMode: _selecting,
                  selected: _selected.contains(item.entry.key),
                  onTap: () => onTap(item),
                  onLongPress: () => onLongPress(item),
                );
              },
            ),
          );
        } else {
          final largest = view.largestBytes;
          body = SliverPadding(
            padding: EdgeInsets.fromLTRB(side, AppSpacing.m, side, bottom),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (BuildContext context, int index) {
                final item = items[index];
                return Padding(
                  key: ValueKey<String>('storage_row_${item.entry.key}'),
                  padding: const EdgeInsets.only(bottom: AppSpacing.s),
                  child: StorageMediaTile(
                    item: item,
                    largestBytes: largest,
                    selectionMode: _selecting,
                    selected: _selected.contains(item.entry.key),
                    onTap: () => onTap(item),
                    onLongPress: () => onLongPress(item),
                  ),
                );
              },
            ),
          );
        }
        return CustomScrollView(
          slivers: <Widget>[
            SliverPadding(
              padding: const EdgeInsets.only(top: AppSpacing.s),
              sliver: SliverToBoxAdapter(child: header),
            ),
            body,
          ],
        );
      },
    );
  }

  static String _sortLabel(AppLocalizations l10n, StorageMediaSort sort) =>
      switch (sort) {
        StorageMediaSort.largest => l10n.storageMgmtSortLargest,
        StorageMediaSort.newest => l10n.storageMgmtSortNewest,
        StorageMediaSort.oldest => l10n.storageMgmtSortOldest,
      };
}
