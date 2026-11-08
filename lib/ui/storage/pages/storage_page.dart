import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/storage/storage_usage_models.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../settings/pages/app_surface_page.dart';
import '../../settings/pages/recycle_bin_page.dart';
import '../../widgets/action_loading_overlay.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_gate.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/form_width.dart';
import '../../widgets/width_layout_builder.dart';
import '../controllers/storage_flows.dart';
import '../models/storage_media_filter.dart';
import '../providers/storage_providers.dart';
import '../sections/storage_overview_card.dart';
import '../sections/storage_overview_groups.dart';
import '../viewmodels/storage_overview_view.dart';
import 'storage_media_page.dart';

/// 存储管理（设置 → 数据与安全）：占用总览、可释放空间的建议、各类媒体与
/// 其他数据的入口（docs/rules/storage.md，DESIGN.md §5.34）。
///
/// 只负责装配、忙碌遮罩与跳转；扫描经 [storageReportProvider]，清理经
/// [StorageFlows]。从媒体页、回收站或背景设置回来时重新扫描：那些页面
/// 里的删除与改动会改变占用。
class StoragePage extends ConsumerStatefulWidget {
  const StoragePage({super.key});

  @override
  ConsumerState<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends ConsumerState<StoragePage>
    implements StorageFlowHost {
  late final StorageFlows _flows = StorageFlows(ref, this);
  bool _busy = false;
  String _busyText = '';

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

  Future<void> _push(Widget page) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (BuildContext context) => page));
    if (mounted) refreshStorageViews(ref);
  }

  void _openMedia(StorageMediaFilter filter) =>
      unawaited(_push(StorageMediaPage(initialFilter: filter)));

  void _openBackgrounds() {
    final settings = ref.read(settingsServiceProvider).asData?.value;
    if (settings == null) return;
    unawaited(_push(AppSurfacePage(settingsService: settings)));
  }

  void _openCategory(StorageCategory category) {
    if (StorageMediaFilter.categories.contains(category)) {
      _openMedia(StorageMediaFilter(category: category));
    } else if (category == StorageCategory.backgrounds) {
      _openBackgrounds();
    }
  }

  bool _canOpenCategory(StorageCategory category) =>
      StorageMediaFilter.categories.contains(category) ||
      category == StorageCategory.backgrounds;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reportAsync = ref.watch(storageReportProvider);
    final compress = ref.watch(storageCompressContextProvider);
    return PopScope(
      canPop: !_busy,
      child: AppPageBackground(
        area: AppBackgroundArea.settings,
        child: Builder(
          builder: (BuildContext context) => Scaffold(
            backgroundColor: AppPageBackdrop.pageColorOf(context),
            appBar: AppTopBar(
              contentMaxWidth: FormWidth.maxWidth,
              title: Text(l10n.storageMgmtTitle),
              leading: IconButton(
                tooltip: l10n.commonBack,
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).maybePop(),
                icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
              ),
              actions: <Widget>[
                IconButton(
                  tooltip: l10n.storageMgmtRescan,
                  onPressed: _busy || reportAsync.isLoading
                      ? null
                      : () => refreshStorageViews(ref),
                  icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 16),
                ),
              ],
            ),
            body: Stack(
              children: <Widget>[
                reportAsync.when(
                  // 重新扫描期间保留上一份结果，不闪回加载态。
                  skipLoadingOnRefresh: true,
                  skipLoadingOnReload: true,
                  loading: () => const DelayedLoadingIndicator(),
                  error: (error, _) => EmptyHint(
                    icon: FontAwesomeIcons.triangleExclamation,
                    message: l10n.storageMgmtScanFailed,
                  ),
                  data: (report) => _buildBody(
                    StorageOverviewView.of(report, compress),
                    canCompress: compress.supported,
                  ),
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

  Widget _buildBody(StorageOverviewView view, {required bool canCompress}) {
    void run(Future<void> Function() action) {
      if (!_busy) unawaited(action());
    }

    return WidthLayoutBuilder(
      builder: (BuildContext context, double width) {
        final side = FormWidth.extra(width);
        return ListView(
          padding: EdgeInsets.fromLTRB(
            side,
            AppSpacing.m,
            side,
            AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
          ),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.l),
              child: StorageOverviewCard(
                view: view,
                onCleanUp: _busy
                    ? null
                    : () => run(() => _flows.cleanUp(context)),
                canOpenCategory: _canOpenCategory,
                onCategoryTap: _openCategory,
              ),
            ),
            const SizedBox(height: AppSpacing.l),
            StorageSuggestionsGroup(
              view: view,
              onClearCache: _busy
                  ? null
                  : () => run(
                      () => _flows.cleanUp(
                        context,
                        orphans: false,
                        database: false,
                      ),
                    ),
              onClearUnused: _busy
                  ? null
                  : () => run(
                      () => _flows.cleanUp(
                        context,
                        cache: false,
                        database: false,
                      ),
                    ),
              onCompactDatabase: _busy
                  ? null
                  : () => run(
                      () =>
                          _flows.cleanUp(context, cache: false, orphans: false),
                    ),
              onOpenTrash: () => unawaited(_push(const RecycleBinPage())),
              onOpenCompressible: canCompress
                  ? () => _openMedia(
                      const StorageMediaFilter(compressibleOnly: true),
                    )
                  : null,
            ),
            const SizedBox(height: AppSpacing.l),
            if (view.report.media.isNotEmpty) ...<Widget>[
              StorageMediaGroup(view: view, onOpen: _openMedia),
              const SizedBox(height: AppSpacing.l),
            ],
            StorageOtherGroup(view: view, onOpenBackgrounds: _openBackgrounds),
          ],
        );
      },
    );
  }
}
