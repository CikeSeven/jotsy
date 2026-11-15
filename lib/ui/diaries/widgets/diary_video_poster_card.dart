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
import 'package:node_diary/ui/diaries/widgets/diary_video_embed_menu.dart';
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
/// 尺寸与内嵌播放器初始化前完全一致：16:9 画面区 + 一行控件（最低 48dp，
/// 与进度条滑块同高），正文不会因平台不同而错位。控件行是播放按钮（交给
/// 系统播放器）、说明（有文件大小时一并显示）与导出按钮（编辑页为 ⋮ 菜单，
/// [menu]），没有进度条。[maxWidth] 同播放器的“调整大小”。
class DiaryVideoPosterCard extends StatefulWidget {
  const DiaryVideoPosterCard({
    super.key,
    required this.video,
    this.openService = const FileOpenService(),
    this.exportService = const VideoExportService(),
    this.maxWidth,
    this.menu,
  });

  final DiaryFileAttachment video;
  final FileOpenService openService;
  final VideoExportService exportService;
  final double? maxWidth;
  final DiaryVideoEmbedMenu? menu;

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

  Future<void> _openExternally() =>
      openDiaryVideoExternally(context, opener: _open, video: widget.video);

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
          final menu = widget.menu;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: widget.maxWidth ?? double.infinity,
              ),
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
                    // 与播放器的控件行同高（播放按钮 + 进度滑块）。
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
                      child: ConstrainedBox(
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
                            const SizedBox(width: 4),
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
                            if (menu != null)
                              DiaryVideoMenuButton(
                                video: video,
                                menu: menu,
                                exportController: _export,
                              )
                            else
                              DiaryVideoExportButton(
                                video: video,
                                controller: _export,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 把视频交给系统播放器打开（不能内嵌播放的平台：封面卡片与视频小图共用），
/// 打不开时经 [HomeHintVisibilityScope.showTrackedSnackBar] 说明原因。
Future<void> openDiaryVideoExternally(
  BuildContext context, {
  required DiaryFileOpenController opener,
  required DiaryFileAttachment video,
}) async {
  final failure = await opener.open(video.path);
  if (!context.mounted || failure == null) return;
  await HomeHintVisibilityScope.showTrackedSnackBar(
    context: context,
    snackBar: SnackBar(
      content: Text(diaryFileOpenFailureMessage(context.l10n, failure)),
    ),
  );
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
