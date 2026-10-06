import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:node_diary/core/database/file_embed_codec.dart';
import 'package:node_diary/core/services/video_export_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_video_player.dart';
import 'package:video_player/video_player.dart';

class DiaryVideoEmbedBuilder extends quill.EmbedBuilder {
  const DiaryVideoEmbedBuilder({
    this.playerFactory,
    this.exportService = const VideoExportService(),
  });

  final VideoPlayerController Function(String source)? playerFactory;
  final VideoExportService exportService;

  @override
  String get key => quill.BlockEmbed.videoType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final video = DiaryFileAttachment.tryDecode(embedContext.node.value.data);
    if (video == null) {
      return Text(
        context.l10n.videoPlaybackFailed,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    return DiaryVideoPlayer(
      key: ValueKey(video.path),
      video: video,
      player: playerFactory?.call(video.path),
      exportService: exportService,
    );
  }
}
