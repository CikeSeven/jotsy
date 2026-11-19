import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_platform.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/expressive_button_group.dart';
import '../../../core/database/mind_map/mind_map_document.dart';
import '../controllers/mind_map_io_flow.dart';

/// 导出导图的面板：顶上“画布 | 大纲”切换（[outline] 为一开始选中大纲，
/// 编辑页传工作区当前的视图 `MindMapEditingController.outlineView`），下面
/// 是这一类的格式，每种一行，
/// 行尾是去处（分享、保存到文件，图片在手机上还能存相册）；点整行走默认
/// 去处（能系统分享的平台为分享，否则保存）。大纲一类的末行是“复制为大纲
/// 文字”。选好即关面板，在宿主页面上导出并提示。
Future<void> showMindMapExportSheet(
  BuildContext host,
  MindMapDocument document, {
  bool outline = false,
}) {
  return showAppModalBottomSheet<void>(
    context: host,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(host)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) => _MindMapExportSheet(
      initialOutline: outline,
      onExport: (MindMapExportKind kind, MindMapDelivery delivery) {
        Navigator.of(sheetContext).pop();
        if (host.mounted) exportMindMap(host, document, kind, delivery);
      },
      onCopyOutline: () {
        Navigator.of(sheetContext).pop();
        if (host.mounted) copyMindMapOutline(host, document);
      },
    ),
  );
}

class _MindMapExportSheet extends StatefulWidget {
  const _MindMapExportSheet({
    required this.initialOutline,
    required this.onExport,
    required this.onCopyOutline,
  });

  final bool initialOutline;
  final void Function(MindMapExportKind kind, MindMapDelivery delivery)
  onExport;
  final VoidCallback onCopyOutline;

  @override
  State<_MindMapExportSheet> createState() => _MindMapExportSheetState();
}

class _MindMapExportSheetState extends State<_MindMapExportSheet> {
  late bool _outline = widget.initialOutline;

  (FaIconData, String, String) _describe(
    AppLocalizations l10n,
    MindMapExportKind kind,
  ) => switch (kind) {
    MindMapExportKind.image => (
      FontAwesomeIcons.solidImage,
      l10n.mindMapExportImage,
      l10n.mindMapExportImageHint,
    ),
    MindMapExportKind.pdf => (
      FontAwesomeIcons.solidFilePdf,
      'PDF',
      l10n.mindMapExportPdfHint,
    ),
    MindMapExportKind.xmind => (
      FontAwesomeIcons.sitemap,
      'XMind',
      l10n.mindMapExportXmindHint,
    ),
    MindMapExportKind.freeMind => (
      FontAwesomeIcons.diagramProject,
      'FreeMind',
      l10n.mindMapExportFreeMindHint,
    ),
    MindMapExportKind.outlinePdf => (
      FontAwesomeIcons.solidFilePdf,
      'PDF',
      l10n.diaryExportFormatPdfDescription,
    ),
    MindMapExportKind.word => (
      FontAwesomeIcons.solidFileWord,
      l10n.diaryExportFormatWord,
      l10n.diaryExportFormatWordDescription,
    ),
    MindMapExportKind.html => (
      FontAwesomeIcons.globe,
      l10n.diaryExportFormatHtml,
      l10n.mindMapExportHtmlHint,
    ),
    MindMapExportKind.markdown => (
      FontAwesomeIcons.markdown,
      'Markdown',
      l10n.mindMapExportMarkdownHint,
    ),
    MindMapExportKind.opml => (
      FontAwesomeIcons.listUl,
      'OPML',
      l10n.mindMapExportOpmlHint,
    ),
    MindMapExportKind.text => (
      FontAwesomeIcons.solidFileLines,
      l10n.diaryExportFormatText,
      l10n.diaryExportFormatTextDescription,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final share = AppPlatform.supportsSystemFileShare;
    void run(MindMapExportKind kind, MindMapDelivery delivery) =>
        widget.onExport(kind, delivery);

    Widget row(MindMapExportKind kind) {
      final (icon, title, subtitle) = _describe(l10n, kind);
      return _ExportRow(
        key: ValueKey<MindMapExportKind>(kind),
        icon: icon,
        title: title,
        subtitle: subtitle,
        onTap: () =>
            run(kind, share ? MindMapDelivery.share : MindMapDelivery.save),
        actions: <Widget>[
          if (kind == MindMapExportKind.image &&
              AppPlatform.savesImagesToGallery)
            IconButton(
              tooltip: l10n.mindMapSaveGallery,
              onPressed: () => run(kind, MindMapDelivery.gallery),
              icon: const FaIcon(FontAwesomeIcons.images, size: 16),
            ),
          if (share)
            IconButton(
              tooltip: l10n.mindMapShare,
              onPressed: () => run(kind, MindMapDelivery.share),
              icon: const FaIcon(FontAwesomeIcons.shareNodes, size: 16),
            ),
          IconButton(
            tooltip: l10n.mindMapSaveFile,
            onPressed: () => run(kind, MindMapDelivery.save),
            icon: const FaIcon(FontAwesomeIcons.download, size: 16),
          ),
        ],
      );
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                l10n.mindMapExport,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: ExpressiveButtonGroup<bool>(
                minSegmentWidth: 88,
                segments: <ButtonSegment<bool>>[
                  ButtonSegment<bool>(
                    value: false,
                    icon: const FaIcon(FontAwesomeIcons.sitemap, size: 14),
                    label: Text(l10n.mindMapCanvasView),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: const FaIcon(FontAwesomeIcons.listUl, size: 14),
                    label: Text(l10n.mindMapOutline),
                  ),
                ],
                selected: <bool>{_outline},
                onSelectionChanged: (value) =>
                    setState(() => _outline = value.first),
              ),
            ),
            AnimatedSize(
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.medium,
              ),
              curve: ExpressiveMotion.spatial,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final kind in MindMapExportKind.values)
                    if (kind.outline == _outline) row(kind),
                  if (_outline)
                    _ExportRow(
                      icon: FontAwesomeIcons.copy,
                      title: l10n.mindMapCopyOutline,
                      subtitle: l10n.mindMapCopyOutlineHint,
                      onTap: widget.onCopyOutline,
                      actions: const <Widget>[],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportRow extends StatelessWidget {
  const _ExportRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.actions,
  });

  final FaIconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: FaIcon(icon, size: 17, color: scheme.onSecondaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      ),
    );
  }
}
