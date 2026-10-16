import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/delayed_loading_indicator.dart';
import '../controllers/anniversary_edit_controller.dart';
import '../controllers/anniversary_navigation.dart';
import '../models/anniversary_draft.dart';
import '../providers/anniversary_providers.dart';
import '../viewmodels/anniversary_countdown.dart';
import '../viewmodels/anniversary_rule.dart';
import '../widgets/anniversary_detail_cards.dart';
import '../widgets/anniversary_diary_picker.dart';
import '../widgets/anniversary_diary_sections.dart';

/// 纪念日详情：倒数卡、信息卡、关联的日记与“历年这一天”。
///
/// 输入：纪念日业务 id 与（可选）打开方已有的那一行（首帧即完整内容）；
/// 之后跟随 [anniversaryProvider] 更新。顶栏可编辑、置顶与删除；删除后
/// 返回上一页并在那里给出可撤销的提示。被别处删除时（列表撤销前的同一行
/// 不会出现在这里）直接返回。
class AnniversaryDetailPage extends ConsumerWidget {
  const AnniversaryDetailPage({
    super.key,
    required this.anniversaryId,
    this.initial,
  });

  final String anniversaryId;
  final Anniversary? initial;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Anniversary row,
  ) async {
    final result = await openAnniversaryEditor(
      context,
      database: ref.read(appDatabaseProvider),
      draft: AnniversaryDraft.fromRow(row),
      editing: row,
    );
    if (result is AnniversaryDeleted && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _pickDiary(
    BuildContext context,
    WidgetRef ref,
    Anniversary row,
    AnniversaryRule rule,
  ) async {
    final pick = await showAnniversaryDiaryPicker(
      context,
      date: rule.base,
      selectedDiaryId: row.linkedDiaryId,
    );
    if (pick == null) return;
    await ref
        .read(appDatabaseProvider)
        .setAnniversaryLink(row.anniversaryId, pick.diaryId);
  }

  Future<void> _showMore(
    BuildContext context,
    WidgetRef ref,
    Anniversary row,
  ) async {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final database = ref.read(appDatabaseProvider);
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (BuildContext sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s,
            0,
            AppSpacing.s,
            AppSpacing.l,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: FaIcon(
                  FontAwesomeIcons.thumbtack,
                  size: 16,
                  color: colorScheme.primary,
                ),
                title: Text(
                  row.isPinned ? l10n.anniversaryUnpin : l10n.anniversaryPin,
                ),
                onTap: () => Navigator.of(sheetContext).pop('pin'),
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: FaIcon(
                  FontAwesomeIcons.trashCan,
                  size: 16,
                  color: colorScheme.error,
                ),
                title: Text(
                  l10n.anniversaryDelete,
                  style: TextStyle(color: colorScheme.error),
                ),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'pin':
        await database.setAnniversaryPinned(row.anniversaryId, !row.isPinned);
      case 'delete':
        final confirmed = await AnniversaryEditController.confirmDelete(
          context,
          row.title,
        );
        if (!confirmed || !context.mounted) return;
        final navigator = Navigator.of(context);
        // 撤销提示挂在上一页：先拿到它的 context，再出栈。
        final deleted = await database.deleteAnniversary(row.anniversaryId);
        navigator.pop();
        final host = navigator.context;
        if (deleted != null && host.mounted) {
          unawaited(showAnniversaryDeletedUndo(host, database, deleted));
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(anniversaryProvider(anniversaryId));
    final row = async.hasValue ? async.value : initial;
    final rule = row == null ? null : AnniversaryRule.fromRow(row);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return Scaffold(
      appBar: AppTopBar(
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
        title: Text(l10n.anniversaryListTitle),
        actions: <Widget>[
          if (row != null) ...<Widget>[
            IconButton(
              tooltip: l10n.commonEdit,
              onPressed: () => unawaited(_edit(context, ref, row)),
              icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 16),
            ),
            IconButton(
              tooltip: l10n.anniversaryMoreActions,
              onPressed: () => unawaited(_showMore(context, ref, row)),
              icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 16),
            ),
          ],
        ],
      ),
      body: row == null || rule == null
          ? async.isLoading
                ? const DelayedLoadingIndicator()
                : const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.s,
                AppSpacing.l,
                AppSpacing.xxxl,
              ),
              children: <Widget>[
                AnniversaryHeroCard(
                  row: row,
                  countdown: AnniversaryCountdown.of(rule, today),
                ),
                const SizedBox(height: AppSpacing.m),
                AnniversaryInfoCard(
                  row: row,
                  countdown: AnniversaryCountdown.of(rule, today),
                ),
                AnniversaryLinkedDiarySection(
                  row: row,
                  onPick: () => unawaited(_pickDiary(context, ref, row, rule)),
                ),
                AnniversaryPastDiariesSection(row: row, rule: rule),
              ],
            ),
    );
  }
}
