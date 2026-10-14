import 'dart:async';

import 'package:flutter/material.dart';
import 'package:node_diary/app/theme/app_effects.dart';
import 'package:node_diary/app/theme/app_radii.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/core/services/audio_playback_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_audio_player_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_audio_waveform.dart';
import 'package:node_diary/ui/diaries/widgets/diary_audio_player_controls.dart';
import 'package:node_diary/ui/diaries/widgets/diary_recording_rename_dialog.dart';
import 'package:node_diary/ui/diaries/widgets/diary_waveform_visualizer.dart';

/// Redesigned Material 3 Expressive audio player for diary notes.
///
/// Features interactive audio waveform seeking, audio renaming,
/// refined surface aesthetics, and lifecycle-safe playback teardown.
class DiaryAudioPlayer extends StatefulWidget {
  const DiaryAudioPlayer({
    super.key,
    required this.recording,
    this.onRename,
    this.player,
  });

  final DiaryAudioAttachment recording;
  final ValueChanged<String>? onRename;
  final AudioPlaybackService? player;

  @override
  State<DiaryAudioPlayer> createState() => _DiaryAudioPlayerState();
}

class _DiaryAudioPlayerState extends State<DiaryAudioPlayer>
    with WidgetsBindingObserver {
  late DiaryAudioPlayerController _controller;
  late List<double> _displayWaveform;

  @override
  void initState() {
    super.initState();
    _controller = DiaryAudioPlayerController(
      recording: widget.recording,
      player: widget.player,
    );
    _displayWaveform = _buildWaveform();
    WidgetsBinding.instance.addObserver(this);
  }

  List<double> _buildWaveform() => generateEffectiveWaveform(
    samples: widget.recording.waveform,
    seedKey: widget.recording.path,
    duration: widget.recording.duration,
  );

  @override
  void didUpdateWidget(DiaryAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.recording.path != oldWidget.recording.path ||
        widget.player != oldWidget.player) {
      _controller.dispose();
      _controller = DiaryAudioPlayerController(
        recording: widget.recording,
        player: widget.player,
      );
      _displayWaveform = _buildWaveform();
    } else if (widget.recording.waveform != oldWidget.recording.waveform ||
        widget.recording.duration != oldWidget.recording.duration) {
      _displayWaveform = _buildWaveform();
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

  Future<void> _rename() async {
    final chosen = await showDiaryRecordingRenameDialog(
      context,
      initialName: widget.recording.name ?? context.l10n.recordingAttachment,
    );
    if (mounted && chosen != null) widget.onRename?.call(chosen);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final colors = Theme.of(context).colorScheme;
      final l10n = context.l10n;
      final totalMs = _controller.duration.inMilliseconds.toDouble();
      final currentMs = _controller.position.inMilliseconds.toDouble();
      final progress = totalMs > 0
          ? (currentMs / totalMs).clamp(0.0, 1.0)
          : 0.0;
      final failed = _controller.hasFailed;
      final playing = _controller.isPlaying;
      final cardColor = ExpressiveSurfaces.cardColor(colors);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            boxShadow: AppEffects.restingCardShadow(colors),
          ),
          child: Material(
            // 正在播放的卡片染上一层淡淡的主色容器色，多段录音并列时一眼能看出
            // 哪一段在响；颜色由 Material 自带的隐式动画过渡。
            animationDuration: ExpressiveMotion.duration(
              context,
              ExpressiveMotion.medium,
            ),
            color: playing
                ? Color.lerp(cardColor, colors.primaryContainer, 0.28)
                : cardColor,
            shape: ExpressiveSurfaces.cardShape(colors),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DiaryAudioPlayerHeader(
                    title: failed
                        ? l10n.recordingPlaybackFailed
                        : widget.recording.name ?? l10n.recordingAttachment,
                    failed: failed,
                    position: _controller.position,
                    duration: _controller.duration,
                    onRename: widget.onRename != null && !failed
                        ? _rename
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      DiaryAudioPlayButton(
                        playing: playing,
                        loading: _controller.isLoading,
                        failed: failed,
                        onPressed: () => unawaited(_controller.toggle()),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: failed
                            ? Text(
                                l10n.recordingPlaybackFailed,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.error),
                              )
                            : DiaryWaveformBarVisualizer(
                                waveform: _displayWaveform,
                                progress: progress,
                                height: 36,
                                onSeek: totalMs <= 0
                                    ? null
                                    : (p) => unawaited(
                                        _controller.seek(
                                          Duration(
                                            milliseconds: (p * totalMs).toInt(),
                                          ),
                                        ),
                                      ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
