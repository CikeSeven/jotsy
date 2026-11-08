// 工具涉及对象的小胶囊（DESIGN §5.29“对象胶囊”）：领域色淡底、14dp 图标
// 圆点 + 名称（最宽 200，单行省略），点按打开那一篇 / 一本 / 一项；某一天
// 只展示、不可点。超过 [max] 个时末尾一枚“+N”。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../models/ai_tool_subject.dart';
import '../../viewmodels/ai_tool_facts.dart';
import '../../widgets/ai_tint_badge.dart';

class AiSubjectChips extends StatelessWidget {
  const AiSubjectChips({
    super.key,
    required this.subjects,
    required this.onOpen,
    this.more = 0,
    this.max = 8,
  });

  final List<AiToolSubject> subjects;
  final ValueChanged<AiToolSubject> onOpen;

  /// 存储时就没记下的个数（`moreSubjects`）。
  final int more;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = subjects.take(max).toList();
    final hidden = subjects.length - shown.length + more;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        for (final subject in shown)
          _SubjectChip(subject: subject, onOpen: onOpen),
        if (hidden > 0) _MoreChip(count: hidden),
      ],
    );
  }
}

class _SubjectChip extends StatelessWidget {
  const _SubjectChip({required this.subject, required this.onOpen});

  final AiToolSubject subject;
  final ValueChanged<AiToolSubject> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final palette = aiTintColors(
      theme.colorScheme,
      aiSubjectTint(subject.kind),
    );
    final tappable = subject.kind != AiSubjectKind.day;
    return Material(
      color: palette.fill.withValues(alpha: 0.55),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: tappable ? () => onOpen(subject) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 10, 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AiTintBadge(
                icon: aiSubjectIcon(subject.kind),
                tint: aiSubjectTint(subject.kind),
                size: 20,
                circle: true,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  aiSubjectName(l10n, subject),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: palette.on,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreChip extends StatelessWidget {
  const _MoreChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: colors.surfaceContainerHighest,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FaIcon(
              FontAwesomeIcons.plus,
              size: 9,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 3),
            Text(
              '$count',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
