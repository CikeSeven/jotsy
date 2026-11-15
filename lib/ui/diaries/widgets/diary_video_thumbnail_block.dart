import 'dart:async';

import 'package:flutter/material.dart';
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/app_platform.dart';
import 'package:node_diary/core/services/file_open_service.dart';
import 'package:node_diary/core/services/video_export_service.dart';
import 'package:node_diary/core/services/video_poster_cache.dart';
import 'package:node_diary/ui/diaries/controllers/diary_file_open_controller.dart';
import 'package:node_diary/ui/diaries/controllers/diary_video_export_controller.dart';
import 'package:node_diary/ui/diaries/pages/diary_video_fullscreen_page.dart';
import 'package:node_diary/ui/diaries/widgets/diary_playback_interaction_guard.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_embed_menu.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_export_button.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_poster_card.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_thumbnail.dart';
import 'package:node_diary/ui/widgets/expressive_menu/expressive_menu.dart';
import 'package:video_player/video_player.dart';

/// 正文里以小图显示的视频块（#252），画面见 [DiaryVideoThumbnail]。
///
/// 点按：
/// - 只读正文（[menu] 为 null）直接播放：能内嵌播放的平台打开全屏播放页
///   （[openDiaryVideoFullscreen]，本页自建播放器、就绪即播放），桌面交给
///   系统播放器；
/// - 编辑页从小图长出视频菜单（播放、恢复正常显示、保存到相册、删除，见
///   [diaryVideoMenuItems]），与图片小图点按弹出图片菜单一致，不弹键盘。
///
/// 小图本身不创建播放器：一排几段视频各开一个原生播放器既占解码器又费电，
/// 画面只是缓存的一帧。导出控制器归本组件，导出进行中“保存到相册”停用。
class DiaryVideoThumbnailBlock extends StatefulWidget {
  const DiaryVideoThumbnailBlock({
    super.key,
    required this.video,
    required this.posters,
    this.menu,
    this.playerFactory,
    this.exportService = const VideoExportService(),
    this.openService = const FileOpenService(),
  });

  final DiaryFileAttachment video;
  final VideoPosterCache posters;

  /// 编辑页的视频菜单动作；只读正文为 null。
  final DiaryVideoEmbedMenu? menu;
  final VideoPlayerController Function(String source)? playerFactory;
  final VideoExportService exportService;
  final FileOpenService openService;

  @override
  State<DiaryVideoThumbnailBlock> createState() =>
      _DiaryVideoThumbnailBlockState();
}

class _DiaryVideoThumbnailBlockState extends State<DiaryVideoThumbnailBlock> {
  late DiaryVideoExportController _export = DiaryVideoExportController(
    service: widget.exportService,
  );
  late DiaryFileOpenController _open = DiaryFileOpenController(
    service: widget.openService,
  );

  @override
  void didUpdateWidget(DiaryVideoThumbnailBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exportService != widget.exportService) {
      _export.dispose();
      _export = DiaryVideoExportController(service: widget.exportService);
    }
    if (oldWidget.openService != widget.openService) {
      _open.dispose();
      _open = DiaryFileOpenController(service: widget.openService);
    }
  }

  @override
  void dispose() {
    _export.dispose();
    _open.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (!AppPlatform.supportsInlineVideo) {
      if (_open.isOpening) return;
      await openDiaryVideoExternally(
        context,
        opener: _open,
        video: widget.video,
      );
      return;
    }
    await openDiaryVideoFullscreen(
      context,
      video: widget.video,
      playerFactory: widget.playerFactory,
      exportService: widget.exportService,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tile = DiaryVideoThumbnail(
      video: widget.video,
      posters: widget.posters,
    );
    final menu = widget.menu;
    return DiaryPlaybackInteractionGuard(
      child: menu == null
          ? GestureDetector(onTap: () => unawaited(_play()), child: tile)
          : AnimatedBuilder(
              animation: _export,
              builder: (context, child) => ExpressiveMenuAnchor(
                placement: ExpressiveMenuPlacement.start,
                menuChildren: diaryVideoMenuItems(
                  context,
                  menu: menu,
                  onPlay: () => unawaited(_play()),
                  onExport: _export.isBusy
                      ? null
                      : () => unawaited(
                          runDiaryVideoExport(
                            context,
                            video: widget.video,
                            controller: _export,
                          ),
                        ),
                ),
                builder: (context, anchor, child) =>
                    GestureDetector(onTap: anchor.open, child: child),
                child: child,
              ),
              child: tile,
            ),
    );
  }
}
