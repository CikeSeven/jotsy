import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_audio_player_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

/// Readable in both editing and preview mode; route/lifecycle teardown stops
/// playback so a removed embed never leaves audio playing in the background.
class DiaryAudioPlayer extends StatefulWidget {
  const DiaryAudioPlayer({super.key, required this.recording});
  final DiaryAudioAttachment recording;

  @override
  State<DiaryAudioPlayer> createState() => _DiaryAudioPlayerState();
}

class _DiaryAudioPlayerState extends State<DiaryAudioPlayer>
    with WidgetsBindingObserver {
  late DiaryAudioPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DiaryAudioPlayerController(recording: widget.recording);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(DiaryAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recording.path != oldWidget.recording.path) {
      _controller.dispose();
      _controller = DiaryAudioPlayerController(recording: widget.recording);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(_controller.pause());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final colors = Theme.of(context).colorScheme;
      final l10n = context.l10n;
      final total = _controller.duration.inMilliseconds.toDouble();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Material(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
            child: Row(
              children: [
                if (_controller.isLoading)
                  const SizedBox.square(
                    dimension: 48,
                    child: Center(child: ExpressiveLoadingIndicator(size: 28)),
                  )
                else
                  IconButton(
                    tooltip: _controller.isPlaying
                        ? l10n.recordingPlaybackPause
                        : l10n.recordingPlaybackPlay,
                    onPressed: () => unawaited(_controller.toggle()),
                    color: colors.onSecondaryContainer,
                    icon: FaIcon(
                      _controller.isPlaying
                          ? FontAwesomeIcons.pause
                          : FontAwesomeIcons.play,
                      size: 18,
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _controller.hasFailed
                            ? l10n.recordingPlaybackFailed
                            : l10n.recordingAttachment,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: _controller.hasFailed
                              ? colors.error
                              : colors.onSecondaryContainer,
                        ),
                      ),
                      Text(
                        '${formatRecordingDuration(_controller.position)} / '
                        '${formatRecordingDuration(_controller.duration)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                      Slider(
                        value: total > 0
                            ? _controller.position.inMilliseconds
                                  .toDouble()
                                  .clamp(0, total)
                            : 0,
                        max: total > 0 ? total : 1,
                        onChanged: _controller.isLoading || total <= 0
                            ? null
                            : (value) => unawaited(
                                _controller.seek(
                                  Duration(milliseconds: value.toInt()),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
