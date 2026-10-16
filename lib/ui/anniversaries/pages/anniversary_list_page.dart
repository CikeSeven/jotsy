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
import '../../widgets/empty_hint.dart';
import '../../widgets/list_item_presence.dart';
import '../controllers/anniversary_navigation.dart';
import '../models/anniversary_draft.dart';
import '../providers/anniversary_providers.dart';
import '../viewmodels/anniversary_countdown.dart';
import '../viewmodels/anniversary_rule.dart';
import '../widgets/anniversary_list_card.dart';

/// 全部纪念日：置顶在前，其余按下一次由近到远，已过去的倒数日排最后。
///
/// 输入：[anniversaryListProvider]；点卡片进入详情，右上角“+”新建。新出现
/// 的条目（在这里新建、撤销删除后回来）以展开动画插入；首次加载的列表直接
/// 显示，不逐条展开。
class AnniversaryListPage extends ConsumerStatefulWidget {
  const AnniversaryListPage({super.key});

  @override
  ConsumerState<AnniversaryListPage> createState() =>
      _AnniversaryListPageState();
}

class _AnniversaryListPageState extends ConsumerState<AnniversaryListPage> {
  /// 已经显示过的条目；为 null 表示还没拿到第一份列表。
  Set<String>? _known;
  final Set<String> _appearing = <String>{};

  void _trackAppearing(List<Anniversary> rows) {
    final ids = rows.map((Anniversary row) => row.anniversaryId).toSet();
    final known = _known;
    if (known != null) {
      _appearing
        ..retainAll(ids)
        ..addAll(ids.difference(known));
    }
    _known = ids;
  }

  Future<void> _create() async {
    await openAnniversaryEditor(
      context,
      database: ref.read(appDatabaseProvider),
      draft: AnniversaryDraft.forDay(DateTime.now(), today: DateTime.now()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rowsAsync = ref.watch(anniversaryListProvider);
    final rows = rowsAsync.value;
    if (rows != null) {
      _trackAppearing(rows);
    }
    return Scaffold(
      appBar: AppTopBar(
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
        title: Text(l10n.anniversaryListTitle),
        actions: <Widget>[
          IconButton(
            tooltip: l10n.anniversaryNewTitle,
            onPressed: () => unawaited(_create()),
            icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
        switchInCurve: ExpressiveMotion.effects,
        switchOutCurve: ExpressiveMotion.exit,
        child: rows == null
            ? const DelayedLoadingIndicator(key: ValueKey<String>('loading'))
            : rows.isEmpty
            ? _EmptyState(
                key: const ValueKey<String>('empty'),
                onCreate: () => unawaited(_create()),
              )
            : _buildList(context, rows),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Anniversary> rows) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final entries = <(Anniversary, AnniversaryCountdown)>[
      for (final row in rows)
        if (AnniversaryRule.fromRow(row) case final rule?)
          (row, AnniversaryCountdown.of(rule, today)),
    ]..sort(AnniversaryCountdown.compareForList);
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    return ListView.builder(
      key: const ValueKey<String>('list'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.l,
        AppSpacing.s,
        AppSpacing.l,
        AppSpacing.xxxl,
      ),
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) {
        final (row, countdown) = entries[index];
        return ListItemPresence(
          key: ValueKey<String>(row.anniversaryId),
          visible: true,
          appearing: _appearing.contains(row.anniversaryId),
          duration: duration,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.m),
            child: AnniversaryListCard(
              row: row,
              countdown: countdown,
              onTap: () => unawaited(
                openAnniversaryDetail(
                  context,
                  anniversaryId: row.anniversaryId,
                  initial: row,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            EmptyHint(
              icon: FontAwesomeIcons.heart,
              message: l10n.anniversaryEmpty,
            ),
            const SizedBox(height: AppSpacing.l),
            FilledButton.tonal(
              onPressed: onCreate,
              child: Text(l10n.calendarDayActionAnniversary),
            ),
          ],
        ),
      ),
    );
  }
}
