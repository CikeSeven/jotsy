import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../notebooks/providers/notebook_providers.dart';
import '../../../notebooks/viewmodels/notebook_view.dart';
import '../../../notebooks/widgets/notebook_cover_tile.dart';
import '../../../settings/providers/app_features_provider.dart';
import '../../../widgets/long_image/long_image_cover_alignment.dart';
import '../../../widgets/long_image/long_image_policy.dart';
import '../../models/diary_image_embed_data.dart';
import '../../models/time_capsule.dart';
import '../../providers/diary_link_providers.dart';
import '../../viewmodels/diary_card_view_data.dart';
import '../../viewmodels/diary_link_label.dart';

/// 日记链接卡片的外观（正文里的 `link_card` 块，见 `DiaryLinkCardBlock`）。
///
/// 显示目标的实时内容，[snapshot]（插入时的标题快照）只在加载中与目标已
/// 不存在时代替标题：
/// - 日记：缩略图（第一张图，cover 裁切）+ 标题 + 日期 + 两行摘要；未解封
///   的胶囊只有标题与解封日期；私密日记（在隐藏 / 上锁的本子里）只显示
///   “私密日记”，不露出标题、摘要与图片；
/// - 日记本：书架上的小封面 + 本名 + 篇数；日记本功能关闭时不可点、没有
///   箭头；
/// - 目标不存在：断链图标 + 快照 + “不存在或已删除”。
///
/// 底色与提示块的中性档同为 `surfaceContainerHigh`；最小高度 72，加载前后
/// 不跳动。[onTap] 为 null 时不可点。
class DiaryLinkCard extends ConsumerWidget {
  const DiaryLinkCard({
    super.key,
    required this.target,
    this.snapshot,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTapUp,
    this.tapUnavailable = false,
  });

  /// 地址认不出时为 null（按不存在显示）。
  final DiaryLinkTarget? target;
  final String? snapshot;
  final VoidCallback? onTap;
  final GestureLongPressStartCallback? onLongPress;
  final GestureTapUpCallback? onSecondaryTapUp;

  /// 目标打不开（不存在、日记本功能关闭）时 [onTap] 是否仍然有效：编辑态
  /// 点按弹出的菜单里还有删除。
  final bool tapUnavailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = this.target;
    final content = switch (target?.kind) {
      DiaryLinkKind.diary => _diary(context, ref, target!.id),
      DiaryLinkKind.notebook => _notebook(context, ref, target!.id),
      null => _missing(context, DiaryLinkKind.diary),
    };
    final colors = Theme.of(context).colorScheme;
    final tappable = onTap != null && (content.openable || tapUnavailable);
    return Semantics(
      button: tappable,
      label: content.title,
      excludeSemantics: true,
      child: Material(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          onLongPressStart: onLongPress,
          onSecondaryTapUp: onSecondaryTapUp,
          child: InkWell(
            onTap: tappable ? onTap : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    content.leading,
                    const SizedBox(width: 12),
                    Expanded(child: _texts(context, content)),
                    if (content.openable) ...[
                      const SizedBox(width: 8),
                      FaIcon(
                        FontAwesomeIcons.angleRight,
                        size: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _texts(BuildContext context, _CardContent content) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final subtitle = content.subtitle;
    final excerpt = content.excerpt;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          content.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: content.muted ? colors.onSurfaceVariant : colors.onSurface,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
        if (excerpt != null && excerpt.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            excerpt,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  _CardContent _diary(BuildContext context, WidgetRef ref, String diaryId) {
    final l10n = context.l10n;
    final linked = ref.watch(diaryLinkDiaryProvider(diaryId));
    final diary = linked.value?.diary;
    if (diary == null) {
      if (!linked.hasValue) return _loading(context, DiaryLinkKind.diary);
      final private =
          ref.watch(privateDiaryIdsProvider).value?.contains(diaryId) ?? false;
      if (!private) return _missing(context, DiaryLinkKind.diary);
      return _CardContent(
        leading: _iconTile(context, FontAwesomeIcons.lock),
        title: l10n.diaryLinkCardPrivate,
        openable: true,
        muted: true,
      );
    }
    final now = DateTime.now();
    final locale = l10n.localeName;
    final sealed = TimeCapsuleState.fromFields(
      lockedAt: diary.capsuleLockedAt,
      unlockAt: diary.capsuleUnlockAt,
      now: now,
    ).isLocked;
    final view = sealed ? null : DiaryCardViewData.of(diary);
    final cover = view?.previewCover;
    return _CardContent(
      leading: cover == null
          ? _iconTile(
              context,
              sealed
                  ? FontAwesomeIcons.hourglassHalf
                  : FontAwesomeIcons.bookOpen,
            )
          : _coverTile(context, cover),
      title: diaryLinkLabel(l10n, diary, now: now),
      subtitle: sealed
          ? l10n.diaryLinkCardSealed(
              DateFormat.yMMMd(locale).format(diary.capsuleUnlockAt!),
            )
          : DateFormat.yMMMd(locale).format(diary.createdAt),
      // 没有标题时标题已取了摘要的开头，不再重复。
      excerpt: diary.title.trim().isEmpty ? null : view?.previewText,
      openable: true,
    );
  }

  _CardContent _notebook(
    BuildContext context,
    WidgetRef ref,
    String notebookId,
  ) {
    final l10n = context.l10n;
    final enabled = ref.watch(
      appFeaturesProvider.select((features) => features.notebooks),
    );
    final tree = ref.watch(notebookTreeProvider);
    final notebook = tree?[notebookId];
    if (!enabled) {
      return _CardContent(
        leading: _iconTile(context, FontAwesomeIcons.book),
        title: notebook?.name ?? snapshot ?? l10n.diaryLinkGroupNotebooks,
        openable: false,
      );
    }
    if (notebook == null) {
      return tree == null
          ? _loading(context, DiaryLinkKind.notebook)
          : _missing(context, DiaryLinkKind.notebook);
    }
    final counts =
        ref.watch(notebookEntryCountsProvider).value ?? const <String, int>{};
    final count = watchNotebookDisplayCount(ref, notebook, counts);
    return _CardContent(
      leading: _notebookCover(notebook),
      title: notebook.name,
      subtitle: count == null ? null : l10n.diaryLinkCardNotebookCount(count),
      openable: true,
    );
  }

  _CardContent _loading(BuildContext context, DiaryLinkKind kind) =>
      _CardContent(
        leading: _iconTile(
          context,
          kind == DiaryLinkKind.notebook
              ? FontAwesomeIcons.book
              : FontAwesomeIcons.bookOpen,
        ),
        title: snapshot ?? '',
        openable: false,
      );

  _CardContent _missing(BuildContext context, DiaryLinkKind kind) {
    final l10n = context.l10n;
    final reason = kind == DiaryLinkKind.notebook
        ? l10n.diaryLinkMissingNotebook
        : l10n.diaryLinkMissingDiary;
    return _CardContent(
      leading: _iconTile(context, FontAwesomeIcons.linkSlash),
      title: snapshot ?? reason,
      subtitle: snapshot == null ? null : reason,
      openable: false,
      muted: true,
    );
  }

  Widget _iconTile(BuildContext context, FaIconData icon) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: FaIcon(icon, size: 18, color: colors.onSecondaryContainer),
    );
  }

  Widget _coverTile(BuildContext context, String source) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 48,
        height: 48,
        child: CoverCroppedImage(
          image: boundedImageProvider(
            resolveDiaryImageProvider(source),
            width: (48 * dpr).round(),
          ),
          errorBuilder: (context, _, _) =>
              _iconTile(context, FontAwesomeIcons.bookOpen),
        ),
      ),
    );
  }

  Widget _notebookCover(NotebookView notebook) => NotebookCoverTile.mini(
    icon: notebook.icon,
    color: notebook.color,
    coverPath: notebook.coverPath,
    style: notebook.coverStyle,
    closed: notebook.isClosed,
  );
}

/// 卡片一种状态下的内容。
class _CardContent {
  const _CardContent({
    required this.leading,
    required this.title,
    required this.openable,
    this.subtitle,
    this.excerpt,
    this.muted = false,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final String? excerpt;

  /// 目标还在、能打开（显示箭头，点按有效）。
  final bool openable;

  /// 私密或不存在：标题用次要色。
  final bool muted;
}
