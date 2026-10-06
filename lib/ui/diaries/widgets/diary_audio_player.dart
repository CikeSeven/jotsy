import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_controls.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/core/database/audio_embed_codec.dart';
import 'package:node_diary/core/services/audio_playback_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/controllers/diary_audio_player_controller.dart';
import 'package:node_diary/ui/diaries/models/diary_audio_waveform.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';
import 'package:node_diary/ui/diaries/widgets/diary_waveform_visualizer.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

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
    _displayWaveform = generateEffectiveWaveform(
      samples: widget.recording.waveform,
      seedKey: widget.recording.path,
      duration: widget.recording.duration,
    );
    WidgetsBinding.instance.addObserver(this);
  }

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
      _displayWaveform = generateEffectiveWaveform(
        samples: widget.recording.waveform,
        seedKey: widget.recording.path,
        duration: widget.recording.duration,
      );
    } else if (widget.recording.waveform != oldWidget.recording.waveform ||
        widget.recording.duration != oldWidget.recording.duration) {
      _displayWaveform = generateEffectiveWaveform(
        samples: widget.recording.waveform,
        seedKey: widget.recording.path,
        duration: widget.recording.duration,
      );
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

  Future<void> _showRenameDialog(BuildContext context) async {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final currentName = widget.recording.name ?? l10n.recordingAttachment;
    final textController = TextEditingController(text: currentName);

    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.recordingRename),
          content: TextField(
            controller: textController,
            autofocus: true,
            maxLength: 30,
            decoration: InputDecoration(
              hintText: l10n.recordingNameHint,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onSubmitted: (val) => Navigator.of(dialogContext).pop(val.trim()),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurfaceVariant,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () =>
                  Navigator.of(dialogContext).pop(textController.text.trim()),
              child: Text(l10n.commonConfirm),
            ),
          ],
        );
      },
    );

    if (mounted && chosen != null && widget.onRename != null) {
      widget.onRename!(chosen);
    }
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
      final title = widget.recording.name ?? l10n.recordingAttachment;

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Material(
          color: ExpressiveSurfaces.cardColor(colors),
          shape: ExpressiveSurfaces.cardShape(colors),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Badge, Name with optional Rename action, and Time
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: FaIcon(
                        FontAwesomeIcons.microphoneLines,
                        size: 11,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              _controller.hasFailed
                                  ? l10n.recordingPlaybackFailed
                                  : title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _controller.hasFailed
                                        ? colors.error
                                        : colors.onSurface,
                                  ),
                            ),
                          ),
                          if (widget.onRename != null &&
                              !_controller.hasFailed) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: l10n.recordingRename,
                              iconSize: 12,
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                              onPressed: () => _showRenameDialog(context),
                              icon: FaIcon(
                                FontAwesomeIcons.penToSquare,
                                size: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${formatRecordingDuration(_controller.position)} / '
                      '${formatRecordingDuration(_controller.duration)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Player row: Play/Pause button + Waveform visualizer
                Row(
                  children: [
                    if (_controller.isLoading)
                      const SizedBox.square(
                        dimension: 42,
                        child: Center(
                          child: ExpressiveLoadingIndicator(size: 22),
                        ),
                      )
                    else
                      IconButton.filledTonal(
                        tooltip: _controller.isPlaying
                            ? l10n.recordingPlaybackPause
                            : l10n.recordingPlaybackPlay,
                        style: ButtonStyle(
                          shape: ExpressiveControls.shape,
                          minimumSize: const WidgetStatePropertyAll(
                            Size(42, 42),
                          ),
                        ),
                        onPressed: _controller.hasFailed
                            ? null
                            : () => unawaited(_controller.toggle()),
                        icon: FaIcon(
                          _controller.isPlaying
                              ? FontAwesomeIcons.pause
                              : FontAwesomeIcons.play,
                          size: 15,
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _controller.hasFailed
                          ? Text(
                              l10n.recordingPlaybackFailed,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.error),
                            )
                          : DiaryWaveformBarVisualizer(
                              waveform: _displayWaveform,
                              progress: progress,
                              height: 32,
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
      );
    },
  );
}
