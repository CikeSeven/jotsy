import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/mind_map/mind_map_document.dart';
import '../../../core/services/app_platform.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../controllers/mind_map_io_flow.dart';

/// 导出导图的面板：每种格式一行，行尾是去处（分享、保存到文件，图片在
/// 手机上还能存相册）；点整行走默认去处（能系统分享的平台为分享，否则
/// 保存）。末行“复制为大纲文字”。选好即关面板，在宿主页面上导出并提示。
Future<void> showMindMapExportSheet(
  BuildContext host,
  MindMapDocument document,
) => showAppModalBottomSheet<void>(
  context: host,
  useSafeArea: true,
  showDragHandle: true,
  isScrollControlled: true,
  sheetAnimationStyle: ExpressiveMotion.reduceMotion(host)
      ? AnimationStyle.noAnimation
      : null,
  builder: (BuildContext sheetContext) {
    final l10n = sheetContext.l10n;
    final theme = Theme.of(sheetContext);
    void run(MindMapExportKind kind, MindMapDelivery delivery) {
      Navigator.of(sheetContext).pop();
      if (host.mounted) exportMindMap(host, document, kind, delivery);
    }

    final share = AppPlatform.supportsSystemFileShare;
    Widget row(
      MindMapExportKind kind,
      FaIconData icon,
      String title,
      String subtitle,
    ) => _ExportRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: () =>
          run(kind, share ? MindMapDelivery.share : MindMapDelivery.save),
      actions: <Widget>[
        if (kind == MindMapExportKind.image && AppPlatform.savesImagesToGallery)
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
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                l10n.mindMapExport,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            row(
              MindMapExportKind.image,
              FontAwesomeIcons.solidImage,
              l10n.mindMapExportImage,
              l10n.mindMapExportImageHint,
            ),
            row(
              MindMapExportKind.pdf,
              FontAwesomeIcons.solidFilePdf,
              'PDF',
              l10n.mindMapExportPdfHint,
            ),
            row(
              MindMapExportKind.xmind,
              FontAwesomeIcons.sitemap,
              'XMind',
              l10n.mindMapExportXmindHint,
            ),
            row(
              MindMapExportKind.markdown,
              FontAwesomeIcons.markdown,
              'Markdown',
              l10n.mindMapExportMarkdownHint,
            ),
            row(
              MindMapExportKind.opml,
              FontAwesomeIcons.listUl,
              'OPML',
              l10n.mindMapExportOpmlHint,
            ),
            row(
              MindMapExportKind.freeMind,
              FontAwesomeIcons.diagramProject,
              'FreeMind',
              l10n.mindMapExportFreeMindHint,
            ),
            _ExportRow(
              icon: FontAwesomeIcons.copy,
              title: l10n.mindMapCopyOutline,
              subtitle: l10n.mindMapCopyOutlineHint,
              onTap: () {
                Navigator.of(sheetContext).pop();
                if (host.mounted) copyMindMapOutline(host, document);
              },
              actions: const <Widget>[],
            ),
          ],
        ),
      ),
    );
  },
);

class _ExportRow extends StatelessWidget {
  const _ExportRow({
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
