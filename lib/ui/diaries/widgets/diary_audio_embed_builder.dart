import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_audio_player.dart';

class DiaryAudioEmbedBuilder extends quill.EmbedBuilder {
  const DiaryAudioEmbedBuilder();

  @override
  String get key => diaryAudioEmbedType;

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final audio = DiaryAudioAttachment.tryDecode(embedContext.node.value.data);
    if (audio == null) {
      return Text(
        context.l10n.recordingPlaybackFailed,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      );
    }
    return DiaryAudioPlayer(
      key: ValueKey(audio.path),
      recording: audio,
      onRename: embedContext.readOnly
          ? null
          : (newName) {
              final trimmed = newName.trim();
              final updated = audio.copyWith(
                name: trimmed.isNotEmpty ? trimmed : null,
              );
              final offset = embedContext.node.offset;
              embedContext.controller.replaceText(
                offset,
                1,
                quill.BlockEmbed(diaryAudioEmbedType, updated.encode()),
                null,
              );
            },
    );
  }
}
