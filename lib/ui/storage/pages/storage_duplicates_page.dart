import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/storage/storage_duplicates.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../ai/controllers/ai_assistant_entry.dart';
import '../../diaries/controllers/diary_open_flow.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../settings/providers/app_features_provider.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../widgets/action_loading_overlay.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_gate.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/form_width.dart';
import '../../widgets/width_layout_builder.dart';
import '../controllers/storage_flows.dart';
import '../providers/storage_providers.dart';
import '../sections/storage_duplicate_group_card.dart';
import '../sections/storage_media_detail_sheet.dart';
import '../viewmodels/storage_duplicates_view.dart';
import '../viewmodels/storage_media_view.dart';

/// 存储管理的重复文件页：内容逐字节相同的文件按组列出，可以逐组或全部
/// 合并（docs/rules/storage.md「重复文件」，DESIGN.md §5.34）。
///
/// - 顶部说明卡：合并做什么、共几组能释放多少、整宽“全部合并”；有私密
///   副本被打码时带“显示”（本页内生效，上锁的先验证身份）；
/// - 每组一张卡片（[StorageDuplicateGroupCard]），点按副本打开与媒体页同一个
///   详情面板（可打开日记、删除）；
/// - 页面只做装配与揭示状态，合并与删除经 [StorageFlows]，结束后列表随扫描
///   重算。
class StorageDuplicatesPage extends ConsumerStatefulWidget {
  const StorageDuplicatesPage({super.key});

  @override
  ConsumerState<StorageDuplicatesPage> createState() =>
      _StorageDuplicatesPageState();
}

class _StorageDuplicatesPageState extends ConsumerState<StorageDuplicatesPage>
    implements StorageFlowHost {
  late final StorageFlows _flows = StorageFlows(ref, this);
  bool _revealPrivate = false;
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

  void _merge(List<StorageDuplicateGroup> groups) {
    if (_busy) return;
    unawaited(_flows.mergeDuplicates(context, groups));
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
    // 在日记里改过、删过都会改变重复情况。
    if (mounted) refreshStorageViews(ref);
  }

  Future<void> _openConversation(String conversationId) async {
    await openAiConversation(context, conversationId);
    if (mounted) refreshStorageViews(ref);
  }

  void _showDetail(StorageMediaItemView item) {
    unawaited(
      showStorageMediaDetail(
        context,
        item: item,
        onCompress: null,
        onDelete: () => unawaited(_flows.delete(context, [item.entry])),
        onOpenDiary: (id) => unawaited(_openDiary(id)),
        onOpenConversation: ref.read(appFeaturesProvider).ai
            ? (id) => unawaited(_openConversation(id))
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final duplicatesAsync = ref.watch(storageDuplicatesProvider);
    final report = ref.watch(storageReportProvider).value;
    return PopScope(
      canPop: !_busy,
      child: AppPageBackground(
        area: AppBackgroundArea.settings,
        child: Builder(
          builder: (BuildContext context) => Scaffold(
            backgroundColor: AppPageBackdrop.pageColorOf(context),
            appBar: AppTopBar(
              contentMaxWidth: FormWidth.maxWidth,
              title: Text(l10n.storageMgmtSuggestDuplicates),
              leading: IconButton(
                tooltip: l10n.commonBack,
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).maybePop(),
                icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
              ),
            ),
            body: Stack(
              children: <Widget>[
                duplicatesAsync.when(
                  // 合并后重新扫描期间保留上一份结果，不闪回加载态。
                  skipLoadingOnRefresh: true,
                  skipLoadingOnReload: true,
                  loading: () => const DelayedLoadingIndicator(),
                  error: (error, _) => EmptyHint(
                    icon: FontAwesomeIcons.triangleExclamation,
                    message: l10n.storageMgmtScanFailed,
                  ),
                  data: (duplicates) => duplicates.isEmpty
                      ? EmptyHint(
                          icon: FontAwesomeIcons.circleCheck,
                          message: l10n.storageMgmtDuplicatesEmpty,
                        )
                      : _buildList(
                          StorageDuplicatesView.of(
                            duplicates,
                            report,
                            revealPrivate: _revealPrivate,
                          ),
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

  Widget _buildList(StorageDuplicatesView view) {
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
            _SummaryCard(
              view: view,
              onMergeAll: _busy
                  ? null
                  : () =>
                        _merge([for (final group in view.groups) group.group]),
              onReveal: view.maskedPrivateCount > 0
                  ? () => unawaited(_reveal(view.maskedNeedsVerification))
                  : null,
            ),
            for (final group in view.groups) ...<Widget>[
              const SizedBox(height: AppSpacing.l),
              StorageDuplicateGroupCard(
                key: ValueKey<String>('duplicate_${group.group.keeper.key}'),
                view: group,
                onMerge: _busy ? null : () => _merge([group.group]),
                onOpen: _showDetail,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 顶部说明卡：合并做什么、汇总、私密副本的揭示与整宽“全部合并”。
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.view,
    required this.onMergeAll,
    required this.onReveal,
  });

  final StorageDuplicatesView view;
  final VoidCallback? onMergeAll;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onReveal = this.onReveal;
    final saved = l10n.formatByteSize(view.savedBytes);
    return SettingsCardGroup(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.storageMgmtDuplicatesSummary(view.groups.length, saved),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                l10n.storageMgmtDuplicatesIntro,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (onReveal != null) ...<Widget>[
                const SizedBox(height: AppSpacing.s),
                Row(
                  children: <Widget>[
                    FaIcon(
                      FontAwesomeIcons.lock,
                      size: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.s),
                    Expanded(
                      child: Text(
                        l10n.storageMgmtPrivateHidden(view.maskedPrivateCount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onReveal,
                      child: Text(l10n.storageMgmtReveal),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.l),
              FilledButton.tonalIcon(
                style: AppGlassField.tonalButtonStyle(context),
                onPressed: onMergeAll,
                icon: const FaIcon(FontAwesomeIcons.clone, size: 14),
                label: Text(
                  l10n.storageMgmtMergeAll(saved),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
