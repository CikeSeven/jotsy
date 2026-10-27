import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../calendar/widgets/calendar_day_content_switcher.dart';
import '../../calendar/widgets/calendar_diary_mini_card.dart';
import '../../diaries/models/diary_preview_sequence.dart';
import '../../notebooks/providers/notebook_providers.dart';
import '../../widgets/image_viewer_hero.dart';
import '../controllers/anniversary_navigation.dart';
import '../providers/anniversary_providers.dart';
import '../viewmodels/anniversary_calendar.dart';
import '../viewmodels/anniversary_rule.dart';

/// 详情页区块标题：图标 + 粗体小标题，与日历“那年今日”同款；[action] 在
/// 行尾。
class AnniversarySectionHeader extends StatelessWidget {
  const AnniversarySectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.action,
  });

  final FaIconData icon;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = this.action;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.l,
        0,
        AppSpacing.s,
      ),
      child: Semantics(
        header: true,
        child: Row(
          children: <Widget>[
            FaIcon(icon, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ?action,
          ],
        ),
      ),
    );
  }
}

/// 内容出现、换成另一种状态时高度过渡、内容交叉淡入（不在一帧内跳动）。
class _Settling extends StatelessWidget {
  const _Settling({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: ExpressiveMotion.durationNonZero(
        context,
        ExpressiveMotion.medium,
      ),
      curve: ExpressiveMotion.effects,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: AnimatedSwitcher(
        duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
        switchInCurve: ExpressiveMotion.effects,
        switchOutCurve: ExpressiveMotion.exit,
        layoutBuilder: CalendarDayContentSwitcher.topAlignedSwitcherLayout,
        child: child,
      ),
    );
  }
}

/// 关联的日记：已关联且可看时为日记小卡片（点按打开预览）；日记已进回收站
/// 或被删除时提示并可取消关联；未关联时提供“关联一篇日记”。
class AnniversaryLinkedDiarySection extends ConsumerWidget {
  const AnniversaryLinkedDiarySection({
    super.key,
    required this.row,
    required this.onPick,
  });

  final Anniversary row;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final linkedId = row.linkedDiaryId;
    final Widget body;
    if (linkedId == null) {
      body = Align(
        key: const ValueKey<String>('unlinked'),
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          onPressed: onPick,
          icon: const FaIcon(FontAwesomeIcons.link, size: 14),
          label: Text(l10n.anniversaryLinkPick),
        ),
      );
    } else {
      final linked = ref.watch(anniversaryLinkedDiaryProvider(linkedId));
      final diary = linked.value;
      if (!linked.hasValue) {
        body = const SizedBox(
          key: ValueKey<String>('loading'),
          width: double.infinity,
        );
      } else if (diary == null &&
          (ref.watch(privateDiaryIdsProvider).value?.contains(linkedId) ??
              false)) {
        // 关联的日记在隐藏 / 上锁的日记本里：它还在，只是这里不显示，不提供
        // “取消关联”。
        body = Text(
          key: const ValueKey<String>('private'),
          l10n.notebookAnniversaryLinkPrivate,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      } else if (diary == null || !isOpenableDiary(diary)) {
        body = Row(
          key: const ValueKey<String>('missing'),
          children: <Widget>[
            Expanded(
              child: Text(
                l10n.anniversaryLinkMissing,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: () => unawaited(
                ref
                    .read(appDatabaseProvider)
                    .setAnniversaryLink(row.anniversaryId, null),
              ),
              child: Text(l10n.anniversaryUnlink),
            ),
          ],
        );
      } else {
        body = CalendarDiaryMiniCard(
          key: ValueKey<String>('linked-${diary.diary.diaryId}'),
          diary: diary,
          eyebrow: DateFormat.yMMMEd(
            l10n.localeName,
          ).format(diary.diary.createdAt.toLocal()),
          onOpenDiary: (DiaryWithTags diary, ImageViewerHero? hero) =>
              unawaited(
                openDiaryFromAnniversary(
                  context,
                  ref,
                  diary: diary,
                  coverHero: hero,
                ),
              ),
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnniversarySectionHeader(
          icon: FontAwesomeIcons.bookOpen,
          title: l10n.anniversaryLinkedDiaryTitle,
          action: linkedId == null
              ? null
              : TextButton(onPressed: onPick, child: Text(l10n.commonEdit)),
        ),
        _Settling(child: body),
      ],
    );
  }
}

/// “历年这一天”：纪念日每一次那天写下的日记（不重复的为“这一天的日记”）。
/// 未解封的时间胶囊与已经作为关联日记显示的那篇不列出；首次还没到时整块
/// 不显示。
class AnniversaryPastDiariesSection extends ConsumerWidget {
  const AnniversaryPastDiariesSection({
    super.key,
    required this.row,
    required this.rule,
  });

  final Anniversary row;
  final AnniversaryRule rule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final now = DateTime.now();
    final occurrences = <DateTime, AnniversaryOccurrence>{
      for (final occurrence in AnniversaryCalendar.past(rule, now))
        occurrence.date: occurrence,
    };
    if (occurrences.isEmpty) {
      return const SizedBox.shrink();
    }
    final diaries = ref
        .watch(anniversaryPastDiariesProvider(rule))
        .value
        ?.where(
          (DiaryWithTags diary) =>
              diary.diary.diaryId != row.linkedDiaryId &&
              isOpenableDiary(diary, now: now),
        )
        .toList(growable: false);

    String eyebrowOf(DiaryWithTags diary) {
      final created = diary.diary.createdAt.toLocal();
      final day = DateTime(created.year, created.month, created.day);
      final occurrence = occurrences[day];
      if (!rule.repeats || occurrence == null) {
        return DateFormat.yMMMEd(l10n.localeName).format(day);
      }
      final label = occurrence.ordinal == 0
          ? l10n.anniversaryBaseDay
          : l10n.anniversaryOrdinal(occurrence.ordinal);
      return '$label · ${DateFormat.y(l10n.localeName).format(day)}';
    }

    final Widget body;
    if (diaries == null) {
      body = const SizedBox(
        key: ValueKey<String>('loading'),
        width: double.infinity,
      );
    } else if (diaries.isEmpty) {
      body = Padding(
        key: const ValueKey<String>('empty'),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        child: Text(
          l10n.anniversaryPastDiariesEmpty,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    } else {
      body = Column(
        key: ValueKey<String>(
          diaries.map((DiaryWithTags d) => d.diary.diaryId).join('|'),
        ),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final diary in diaries)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s),
              child: CalendarDiaryMiniCard(
                diary: diary,
                eyebrow: eyebrowOf(diary),
                onOpenDiary: (DiaryWithTags diary, ImageViewerHero? hero) =>
                    unawaited(
                      openDiaryFromAnniversary(
                        context,
                        ref,
                        diary: diary,
                        coverHero: hero,
                        sequence: DiaryPreviewSequence.fromItems(diaries),
                      ),
                    ),
              ),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnniversarySectionHeader(
          icon: FontAwesomeIcons.clockRotateLeft,
          title: rule.repeats
              ? l10n.anniversaryPastDiariesTitle
              : l10n.anniversaryBaseDayDiariesTitle,
        ),
        _Settling(child: body),
      ],
    );
  }
}
