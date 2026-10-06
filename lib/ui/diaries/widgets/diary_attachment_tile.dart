import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/file_open_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_file_open_controller.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:path/path.dart' as p;

/// 编辑态、阅读态共用的文件卡片；文件打开由 controller/service 管理。
class DiaryAttachmentTile extends StatefulWidget {
  const DiaryAttachmentTile({
    super.key,
    required this.attachment,
    this.subtitle,
    this.icon,
    this.openService = const FileOpenService(),
  });

  final DiaryFileAttachment attachment;
  final String? subtitle;
  final FaIconData? icon;
  final FileOpenService openService;

  @override
  State<DiaryAttachmentTile> createState() => _DiaryAttachmentTileState();
}

class _DiaryAttachmentTileState extends State<DiaryAttachmentTile> {
  late final DiaryFileOpenController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DiaryFileOpenController(service: widget.openService);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final path = widget.attachment.path;
    final failure = await _controller.open(path);
    if (!mounted || failure == null || path != widget.attachment.path) return;
    final l10n = context.l10n;
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(switch (failure) {
          FileOpenFailure.missingFile => l10n.attachmentFileMissing,
          FileOpenFailure.noApp => l10n.attachmentNoApp,
          FileOpenFailure.permissionDenied => l10n.attachmentPermissionDenied,
          FileOpenFailure.failed => l10n.attachmentOpenFailed,
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final file = widget.attachment;
    final size = file.sizeBytes;
    final extension = p.extension(file.displayName).replaceFirst('.', '');
    final subtitle =
        widget.subtitle ??
        (size == null
            ? context.l10n.attachmentOpenHint
            : [
                if (extension.isNotEmpty) extension.toUpperCase(),
                _formatSize(size, context.l10n.localeName),
              ].join(' · '));
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Tooltip(
          message: context.l10n.attachmentOpen,
          child: Material(
            color: colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _controller.isOpening ? null : () => unawaited(_open()),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: FaIcon(
                        widget.icon ?? _fileIcon(extension),
                        size: 20,
                        color: colors.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (_controller.isOpening)
                      ExpressiveLoadingIndicator(
                        size: 24,
                        semanticLabel: context.l10n.attachmentOpening,
                      )
                    else
                      FaIcon(
                        FontAwesomeIcons.arrowUpRightFromSquare,
                        size: 16,
                        color: colors.primary,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static FaIconData _fileIcon(String extension) =>
      switch (extension.toLowerCase()) {
        'pdf' => FontAwesomeIcons.filePdf,
        'doc' || 'docx' => FontAwesomeIcons.fileWord,
        'xls' || 'xlsx' || 'csv' => FontAwesomeIcons.fileExcel,
        'ppt' || 'pptx' => FontAwesomeIcons.filePowerpoint,
        'zip' || 'rar' || '7z' || 'gz' => FontAwesomeIcons.fileZipper,
        'txt' || 'md' => FontAwesomeIcons.fileLines,
        _ => FontAwesomeIcons.paperclip,
      };

  static String _formatSize(int bytes, String locale) {
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    return '${NumberFormat('0.#', locale).format(value)} ${units[unit]}';
  }
}
