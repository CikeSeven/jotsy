import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/services/storage/storage_usage_models.dart';
import '../../diaries/widgets/diary_day_photos/diary_day_photo_badges.dart';
import 'storage_media_view.dart';

/// 存储管理的文案与配色换算（类别名、图标、分段颜色、引用描述）。

extension StorageCategoryPresentation on StorageCategory {
  String label(AppLocalizations l10n) => switch (this) {
    StorageCategory.images => l10n.storageMgmtCategoryImages,
    StorageCategory.videos => l10n.storageMgmtCategoryVideos,
    StorageCategory.audio => l10n.storageMgmtCategoryAudio,
    StorageCategory.attachments => l10n.storageMgmtCategoryAttachments,
    StorageCategory.covers => l10n.storageMgmtCategoryCovers,
    StorageCategory.backgrounds => l10n.storageMgmtCategoryBackgrounds,
    StorageCategory.fonts => l10n.storageMgmtCategoryFonts,
    StorageCategory.database => l10n.storageMgmtCategoryDatabase,
    StorageCategory.cache => l10n.storageMgmtCategoryCache,
    StorageCategory.app => l10n.storageMgmtCategoryApp,
    StorageCategory.unused => l10n.storageMgmtCategoryUnused,
    StorageCategory.other => l10n.storageMgmtCategoryOther,
  };

  FaIconData get icon => switch (this) {
    StorageCategory.images => FontAwesomeIcons.image,
    StorageCategory.videos => FontAwesomeIcons.film,
    StorageCategory.audio => FontAwesomeIcons.microphone,
    StorageCategory.attachments => FontAwesomeIcons.paperclip,
    StorageCategory.covers => FontAwesomeIcons.bookOpen,
    StorageCategory.backgrounds => FontAwesomeIcons.panorama,
    StorageCategory.fonts => FontAwesomeIcons.font,
    StorageCategory.database => FontAwesomeIcons.database,
    StorageCategory.cache => FontAwesomeIcons.boxArchive,
    StorageCategory.app => FontAwesomeIcons.cube,
    StorageCategory.unused => FontAwesomeIcons.fileCircleXmark,
    StorageCategory.other => FontAwesomeIcons.ellipsis,
  };

  /// 分段条与图例的颜色：只取配色方案的语义色（明暗主题自动适配），三种
  /// 强调色各用实色与半透明两档区分相邻类别；“未使用”用 error 系提示可清理，
  /// 数据库 / 缓存 / 其他这类非媒体数据用中性的描边色。
  Color color(ColorScheme scheme) => switch (this) {
    StorageCategory.images => scheme.primary,
    StorageCategory.videos => scheme.tertiary,
    StorageCategory.audio => scheme.secondary,
    StorageCategory.attachments => scheme.primary.withValues(alpha: 0.5),
    StorageCategory.covers => scheme.tertiary.withValues(alpha: 0.5),
    StorageCategory.backgrounds => scheme.secondary.withValues(alpha: 0.5),
    StorageCategory.fonts => scheme.primary.withValues(alpha: 0.3),
    StorageCategory.database => scheme.outline,
    StorageCategory.cache => scheme.outlineVariant,
    StorageCategory.app => scheme.tertiary.withValues(alpha: 0.3),
    StorageCategory.unused => scheme.error.withValues(alpha: 0.72),
    StorageCategory.other => scheme.outline.withValues(alpha: 0.5),
  };
}

/// 引用的一行描述（详情面板的“用在”与列表标题）。
String storageRefLabel(AppLocalizations l10n, StorageMediaRef ref) =>
    switch (ref) {
      StorageDiaryRef(:final title, :final isCover) =>
        isCover
            ? l10n.storageMgmtRefDiaryCover(_titleOr(title, l10n))
            : _titleOr(title, l10n),
      StorageCommentRef(:final diaryTitle) => l10n.storageMgmtRefComment(
        _titleOr(diaryTitle, l10n),
      ),
      StorageNotebookCoverRef(:final name) => l10n.storageMgmtRefNotebookCover(
        name,
      ),
      StorageDraftRef(:final title) => l10n.storageMgmtRefDraft(
        title.trim().isEmpty ? l10n.storageMgmtUntitledDraft : title.trim(),
      ),
      StorageOtherRef() => l10n.storageMgmtRefOther,
    };

FaIconData storageRefIcon(StorageMediaRef ref) => switch (ref) {
  StorageDiaryRef(:final isCover) =>
    isCover ? FontAwesomeIcons.panorama : FontAwesomeIcons.bookBookmark,
  StorageCommentRef() => FontAwesomeIcons.comment,
  StorageNotebookCoverRef() => FontAwesomeIcons.book,
  StorageDraftRef() => FontAwesomeIcons.penToSquare,
  StorageOtherRef() => FontAwesomeIcons.link,
};

/// 列表与网格上一个媒体的标题：打码时只说来自哪里，否则取第一处引用。
String storageMediaTitle(
  AppLocalizations l10n,
  StorageMediaEntry entry, {
  required bool masked,
}) {
  if (masked) {
    return entry.visibility == StorageRefVisibility.capsule
        ? l10n.storageMgmtMaskedCapsule
        : l10n.storageMgmtMaskedPrivate;
  }
  if (entry.refs.isEmpty) return entry.fileName;
  return storageRefLabel(l10n, entry.refs.first);
}

/// 图片格式的大写短名（JPEG、PNG…）；认不出时取扩展名。
String storageFormatLabel(StorageMediaEntry entry) {
  final format = entry.image?.format;
  if (format != null && format != StorageImageFormat.other) {
    return format.name.toUpperCase();
  }
  final dot = entry.fileName.lastIndexOf('.');
  return dot < 0 ? '' : entry.fileName.substring(dot + 1).toUpperCase();
}

String _titleOr(String title, AppLocalizations l10n) =>
    title.trim().isEmpty ? l10n.storageMgmtUntitledDiary : title.trim();

/// 列表与详情的一行规格：日期 · 尺寸（视频加时长）· 格式。打码时不写日期
/// （与回收站里私密日记的占位同一口径）。
String storageMediaDetails(AppLocalizations l10n, StorageMediaItemView item) {
  final entry = item.entry;
  final image = entry.image;
  final video = item.video;
  final format = storageFormatLabel(entry);
  return <String>[
    if (!item.masked) l10n.formatFullDate(entry.displayDate),
    if (image?.width != null && image?.height != null)
      '${image!.width}×${image.height}',
    if (video != null && video.width > 0) '${video.width}×${video.height}',
    if (video != null && video.durationMs > 0)
      dayPhotoDurationLabel(video.duration),
    if (format.isNotEmpty) format,
  ].join(' · ');
}
