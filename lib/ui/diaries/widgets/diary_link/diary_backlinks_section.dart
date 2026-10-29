import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../app/theme/expressive_motion.dart';
import '../../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../../widgets/delayed_loading_indicator.dart';
import '../../controllers/diary_link_open_flow.dart';
import '../../providers/diary_link_providers.dart';

/// 预览页反向链接区的数据（见 `DiaryPreviewContent.backlinks`）；null 即不
/// 显示：在回收站、未解封的胶囊、截取分享长图期间、没有日记提到这一篇。
class DiaryPreviewBacklinks {
  const DiaryPreviewBacklinks({required this.target, required this.items});

  final DiaryLinkTarget target;
  final List<DiaryBacklink> items;
}

/// 正文里最多列几篇，再多经“全部 N 篇”打开面板。
const int kDiaryBacklinksInlineLimit = 5;

/// 预览页的“提到这篇的日记”：标题行（同留言区，`titleSmall` w600 次要色）+
/// 最近的几篇（标题、日期与一行摘要），点按打开那篇。
class DiaryBacklinksSection extends ConsumerWidget {
  const DiaryBacklinksSection({super.key, required this.data, this.textColor});

  final DiaryPreviewBacklinks data;

  /// 预览页正文色（自定义纸张时不是主题色）。
  final Color? textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final items = data.items;
    final shown = items.take(kDiaryBacklinksInlineLimit).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            l10n.diaryBacklinksTitle(items.length),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final item in shown)
          DiaryBacklinkTile(
            backlink: item,
            textColor: textColor,
            onTap: () => unawaited(
              openDiaryLinkTarget(
                context,
                ref,
                DiaryLinkTarget.diary(item.diaryId),
              ),
            ),
          ),
        if (items.length > shown.length)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => unawaited(
                showDiaryBacklinksSheet(
                  context,
                  target: data.target,
                  title: l10n.diaryBacklinksTitle(items.length),
                  onOpen: (diaryId) => unawaited(
                    openDiaryLinkTarget(
                      context,
                      ref,
                      DiaryLinkTarget.diary(diaryId),
                    ),
                  ),
                ),
              ),
              child: Text(l10n.diaryBacklinksShowAll(items.length)),
            ),
          ),
      ],
    );
  }
}

/// 一篇提到目标的日记：链接图标 + 标题（没有标题时用摘要开头）+ 日期，
/// 下一行灰色单行摘要。最小高 48。
class DiaryBacklinkTile extends StatelessWidget {
  const DiaryBacklinkTile({
    super.key,
    required this.backlink,
    required this.onTap,
    this.textColor,
  });

  final DiaryBacklink backlink;
  final VoidCallback onTap;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ink = textColor ?? colors.onSurface;
    final excerpt = backlink.excerpt.replaceAll(RegExp(r'\s+'), ' ').trim();
    final title = backlink.title.trim().isNotEmpty
        ? backlink.title.trim()
        : excerpt.isNotEmpty
        ? excerpt
        : l10n.autoT0065;
    final date = DateFormat.yMMMd(l10n.localeName).format(backlink.createdAt);
    return Semantics(
      button: true,
      label: '$title, $date',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: FaIcon(
                    FontAwesomeIcons.link,
                    size: 12,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: ink,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            date,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (backlink.title.trim().isNotEmpty &&
                          excerpt.isNotEmpty)
                        Text(
                          excerpt,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 全部提到 [target] 的日记（预览页“全部 N 篇”、日记本头部的胶囊）。点按
/// 一篇先收起面板再经 [onOpen] 打开（由入口用自己的 context 与 ref 打开：
/// 面板收起后它的 ref 不再可用），返回时回到原页面。
Future<void> showDiaryBacklinksSheet(
  BuildContext context, {
  required DiaryLinkTarget target,
  required String title,
  required ValueChanged<String> onOpen,
}) {
  return showAppModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    // 底部面板默认滑入不读取系统“减少动态效果”；该模式下直接出现。
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (sheetContext) =>
        _BacklinksSheet(target: target, title: title, onOpen: onOpen),
  );
}

class _BacklinksSheet extends ConsumerWidget {
  const _BacklinksSheet({
    required this.target,
    required this.title,
    required this.onOpen,
  });

  final DiaryLinkTarget target;
  final String title;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final items = ref.watch(diaryBacklinksProvider(target)).value;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (items == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: DelayedLoadingIndicator(),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  for (final item in items)
                    DiaryBacklinkTile(
                      backlink: item,
                      onTap: () {
                        Navigator.of(context).pop();
                        onOpen(item.diaryId);
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
