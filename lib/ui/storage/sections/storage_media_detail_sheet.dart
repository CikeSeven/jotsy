import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/file_open_service.dart';
import '../../../core/services/storage/storage_usage_models.dart';
import '../../diaries/widgets/diary_image_source.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/expressive_image_frame.dart';
import '../../widgets/image_viewer_hero.dart';
import '../../widgets/image_viewer_page.dart';
import '../../widgets/long_image/long_image_policy.dart';
import '../../widgets/text_selection_menu/app_text_context_menu.dart';
import '../../widgets/width_layout_builder.dart';
import '../viewmodels/storage_labels.dart';
import '../viewmodels/storage_media_view.dart';
import '../widgets/storage_media_thumb.dart';
import '../widgets/storage_media_tile.dart';

/// 单个媒体的详情面板：大预览（图片点开看图页，其余交给系统应用打开）、
/// 大小与规格、“用在”哪些日记 / 日记本封面 / 留言 / 草稿，以及压缩与删除。
///
/// 打码的项不显示预览、文件名与引用的标题，只写有几处私密内容。三个回调
/// 都在面板关闭之后执行（打开日记、压缩、删除都会换到别的界面）。
Future<void> showStorageMediaDetail(
  BuildContext context, {
  required StorageMediaItemView item,
  required VoidCallback? onCompress,
  required VoidCallback onDelete,
  required ValueChanged<String> onOpenDiary,
}) => showAppModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (BuildContext sheetContext) {
    void closeThen(VoidCallback action) {
      Navigator.of(sheetContext).pop();
      action();
    }

    final compress = onCompress;
    return _DetailBody(
      item: item,
      onCompress: compress == null ? null : () => closeThen(compress),
      onDelete: () => closeThen(onDelete),
      onOpenDiary: (id) => closeThen(() => onOpenDiary(id)),
    );
  },
);

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.item,
    required this.onCompress,
    required this.onDelete,
    required this.onOpenDiary,
  });

  final StorageMediaItemView item;
  final VoidCallback? onCompress;
  final VoidCallback onDelete;
  final ValueChanged<String> onOpenDiary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final entry = item.entry;
    final estimate = item.estimatedBytes;
    final onCompress = this.onCompress;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController controller) => ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl + MediaQuery.paddingOf(context).bottom,
        ),
        children: <Widget>[
          _Preview(item: item),
          const SizedBox(height: AppSpacing.l),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  storageMediaTitle(l10n, entry, masked: item.masked),
                  style: theme.textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Text(
                l10n.formatByteSize(entry.bytes),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            storageMediaDetails(l10n, item),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (!item.masked) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            SelectableText(
              entry.fileName,
              contextMenuBuilder: appTextContextMenuBuilder,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.l),
          Text(
            l10n.storageMgmtUsedIn(entry.refs.length),
            style: theme.textTheme.titleSmall?.copyWith(color: scheme.primary),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (item.masked)
            Text(
              entry.visibility == StorageRefVisibility.capsule
                  ? l10n.storageMgmtMaskedCapsule
                  : l10n.storageMgmtMaskedPrivate,
              style: theme.textTheme.bodyMedium,
            )
          else
            for (final ref in entry.refs)
              _RefRow(ref: ref, onOpen: onOpenDiary),
          const SizedBox(height: AppSpacing.l),
          if (!entry.isEditable)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.m),
              child: Text(
                l10n.storageMgmtCannotDelete,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          // 能压缩时“压缩 · 约省 X”占去剩余宽度、放不下就折成两行，“删除”
          // 只取文字宽度：两个按钮平分宽度时省多少会被截掉，那正是用户要看
          // 的数字。只有删除时它占满整行。
          Row(
            children: <Widget>[
              if (onCompress != null && estimate != null) ...<Widget>[
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: onCompress,
                    style: AppGlassField.tonalButtonStyle(context),
                    icon: const FaIcon(FontAwesomeIcons.compress, size: 14),
                    label: Text(
                      l10n.storageMgmtCompressSaving(
                        l10n.formatByteSize(entry.bytes - estimate),
                      ),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.m),
                _DeleteButton(onPressed: entry.isEditable ? onDelete : null),
              ] else
                Expanded(
                  child: _DeleteButton(
                    onPressed: entry.isEditable ? onDelete : null,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// error 系的“删除”按钮。
class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.errorContainer,
        foregroundColor: scheme.onErrorContainer,
      ),
      onPressed: onPressed,
      icon: const FaIcon(FontAwesomeIcons.trashCan, size: 14),
      label: Text(context.l10n.commonDelete),
    );
  }
}

/// 面板顶部的预览：图片按面板宽度保持比例缩小解码、点按进看图页；视频
/// 显示一帧与播放按钮、录音与附件显示图标，点按交给系统应用打开；打码
/// 时只有锁。
class _Preview extends StatelessWidget {
  const _Preview({required this.item});

  static const double _height = 220;

  final StorageMediaItemView item;

  Object get _heroTag => 'storage_media_${item.entry.key}';

  @override
  Widget build(BuildContext context) {
    final entry = item.entry;
    final radius = BorderRadius.circular(AppSpacing.l);
    if (item.masked || entry.kind != DiaryBlockMediaKind.image) {
      return ClipRRect(
        borderRadius: radius,
        child: SizedBox(
          height: _height,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              StorageMediaThumb(
                entry: entry,
                masked: item.masked,
                extent: _height,
              ),
              if (!item.masked)
                Material(
                  type: MaterialType.transparency,
                  child: InkWell(onTap: () => unawaited(_openExternally())),
                ),
            ],
          ),
        ),
      );
    }
    // 按面板里实际可用的宽度解码（宽窗口时面板比屏幕窄）。
    return WidthLayoutBuilder(
      builder: (BuildContext previewContext, double width) => GestureDetector(
        onTap: () => unawaited(
          openImageViewer(
            previewContext,
            items: [ImageViewerItem(source: entry.path)],
            initialIndex: 0,
            hero: ImageViewerHero.capture(previewContext, tag: _heroTag),
          ),
        ),
        child: SizedBox(
          height: _height,
          child: Center(
            child: ImageViewerHeroSource(
              tag: _heroTag,
              borderRadius: radius,
              child: ClipRRect(
                borderRadius: radius,
                child: Image(
                  image: boundedImageProvider(
                    diaryImageProvider(entry.path),
                    width:
                        (width * MediaQuery.devicePixelRatioOf(previewContext))
                            .round(),
                  ),
                  fit: BoxFit.contain,
                  frameBuilder: expressiveImageFrameBuilder,
                  errorBuilder: (context, _, _) => StorageMediaThumb(
                    entry: entry,
                    masked: false,
                    extent: _height,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openExternally() async {
    await const FileOpenService().open(item.entry.path);
  }
}

/// “用在”里的一处：能打开的日记（不在回收站）带箭头，点按关面板后打开。
class _RefRow extends StatelessWidget {
  const _RefRow({required this.ref, required this.onOpen});

  final StorageMediaRef ref;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ref = this.ref;
    final (String? diaryId, DateTime? date, bool deleted) = switch (ref) {
      StorageDiaryRef(:final diaryId, :final createdAt, :final isDeleted) => (
        diaryId,
        createdAt,
        isDeleted,
      ),
      StorageCommentRef(
        :final diaryId,
        :final diaryCreatedAt,
        :final diaryIsDeleted,
      ) =>
        (diaryId, diaryCreatedAt, diaryIsDeleted),
      _ => (null, null, false),
    };
    // 面板只在没打码（公开，或私密已揭示）时列出引用，这里不必再看私密；
    // 胶囊的内容永远打码，不会走到这里。
    final openable =
        diaryId != null &&
        !deleted &&
        ref.visibility != StorageRefVisibility.capsule;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      titleAlignment: ListTileTitleAlignment.center,
      leading: FaIcon(storageRefIcon(ref), size: 16, color: scheme.primary),
      title: Text(
        storageRefLabel(l10n, ref),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: date == null && !deleted
          ? null
          : Text(
              [
                if (date != null) l10n.formatFullDate(date),
                if (deleted) l10n.storageMgmtBadgeTrash,
              ].join(' · '),
            ),
      trailing: openable
          ? FaIcon(
              FontAwesomeIcons.angleRight,
              size: 14,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            )
          : (ref is StorageOtherRef
                ? StorageBadge(
                    label: l10n.storageMgmtBadgeLocked,
                    background: scheme.surfaceContainerHighest,
                    foreground: scheme.onSurfaceVariant,
                  )
                : null),
      onTap: openable ? () => onOpen(diaryId) : null,
    );
  }
}
