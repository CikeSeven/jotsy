import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/file_open_service.dart';
import 'package:node_diary/core/services/video_export_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_file_open_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_export_controller.dart';
import 'package:node_diary/ui/diaries/widgets/diary_attachment_tile.dart';
import 'package:node_diary/ui/diaries/widgets/diary_playback_interaction_guard.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_export_button.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/delayed_loading_gate.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:path/path.dart' as p;

/// 不能在日记里直接播放视频的平台（Linux / Windows，
/// `AppPlatform.supportsInlineVideo` 为 false）上代替 `DiaryVideoPlayer` 的
/// 封面卡片：点按卡片（或播放按钮）交给系统播放器打开，不创建任何
/// video_player 控制器。
///
/// 尺寸与内嵌播放器初始化前完全一致：16:9 画面区 + 两行 44dp 控件区
/// （第二行最低 48dp，与进度条滑块同高），正文不会因平台不同而错位。第一行
/// 与播放器相同（文件名、导出视频、全屏位换成“用系统播放器打开”），第二行
/// 放播放按钮与说明（有文件大小时一并显示），没有进度条。
class DiaryVideoPosterCard extends StatefulWidget {
  const DiaryVideoPosterCard({
    super.key,
    required this.video,
    this.openService = const FileOpenService(),
    this.exportService = const VideoExportService(),
  });

  final DiaryFileAttachment video;
  final FileOpenService openService;
  final VideoExportService exportService;

  @override
  State<DiaryVideoPosterCard> createState() => _DiaryVideoPosterCardState();
}

class _DiaryVideoPosterCardState extends State<DiaryVideoPosterCard> {
  late final DiaryFileOpenController _open = DiaryFileOpenController(
    service: widget.openService,
  );
  late DiaryVideoExportController _export = DiaryVideoExportController(
    service: widget.exportService,
  );

  @override
  void didUpdateWidget(DiaryVideoPosterCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exportService != widget.exportService) {
      _export.dispose();
      _export = DiaryVideoExportController(service: widget.exportService);
    }
  }

  @override
  void dispose() {
    _open.dispose();
    _export.dispose();
    super.dispose();
  }

  Future<void> _openExternally() async {
    final path = widget.video.path;
    final failure = await _open.open(path);
    if (!mounted || failure == null || path != widget.video.path) return;
    await HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(diaryFileOpenFailureMessage(context.l10n, failure)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final video = widget.video;
    final size = video.sizeBytes;
    final extension = p.extension(video.displayName).replaceFirst('.', '');
    final hint = <String>[
      l10n.videoPosterHint,
      if (size != null)
        [
          if (extension.isNotEmpty) extension.toUpperCase(),
          l10n.formatByteSize(size),
        ].join(' '),
    ].join(' · ');
    return DiaryPlaybackInteractionGuard(
      child: AnimatedBuilder(
        animation: _open,
        builder: (context, _) {
          final onOpen = _open.isOpening
              ? null
              : () => unawaited(_openExternally());
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Material(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: InkWell(
                      onTap: onOpen,
                      child: Center(
                        child: _PlayBadge(loading: _open, onOpen: onOpen),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                video.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                            DiaryVideoExportButton(
                              video: video,
                              controller: _export,
                            ),
                            SizedBox.square(
                              dimension: 44,
                              child: IconButton(
                                tooltip: l10n.videoOpenExternally,
                                onPressed: onOpen,
                                icon: const FaIcon(
                                  FontAwesomeIcons.arrowUpRightFromSquare,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // 与播放器第二行（播放按钮 + 进度滑块）同高。
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: kMinInteractiveDimension,
                          ),
                          child: Row(
                            children: <Widget>[
                              SizedBox.square(
                                dimension: 44,
                                child: IconButton(
                                  tooltip: l10n.videoOpenExternally,
                                  onPressed: onOpen,
                                  icon: const FaIcon(
                                    FontAwesomeIcons.play,
                                    size: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  hint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 画面区中央的大播放按钮（与内嵌播放器暂停时的按钮同款）；交给系统打开
/// 超过 300ms 时换成等待指示。
class _PlayBadge extends StatelessWidget {
  const _PlayBadge({required this.loading, required this.onOpen});

  final DiaryFileOpenController loading;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return DelayedLoadingGate(
      loading: loading.isOpening,
      builder: (context, showLoading) => ExpressiveIconSwap(
        switchKey: showLoading,
        child: showLoading
            ? ExpressiveLoadingIndicator(
                size: 40,
                semanticLabel: context.l10n.attachmentOpening,
              )
            : IconButton.filledTonal(
                tooltip: context.l10n.videoOpenExternally,
                onPressed: onOpen,
                icon: const FaIcon(FontAwesomeIcons.play, size: 24),
              ),
      ),
    );
  }
}
