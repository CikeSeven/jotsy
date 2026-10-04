import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_controls.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/app/theme/expressive_surfaces.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';
import 'package:node_diary/ui/diaries/widgets/diary_waveform_visualizer.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

/// Redesigned Material 3 Expressive recording panel.
///
/// Features real-time voiceprint (amplitude soundwave) visualization,
/// inline recording renaming, tactile morphing controls, and clean surfaces.
class DiaryRecordingPanel extends StatelessWidget {
  const DiaryRecordingPanel({
    super.key,
    required this.phase,
    required this.elapsed,
    required this.failure,
    this.amplitude = 0.0,
    this.recordingName,
    this.onNameChanged,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onClose,
  });

  final DiaryRecordingPhase phase;
  final Duration elapsed;
  final DiaryRecordingFailure? failure;
  final double amplitude;
  final String? recordingName;
  final ValueChanged<String>? onNameChanged;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;
  final VoidCallback onClose;

  Future<void> _openRenameDialog(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme colors,
  ) async {
    final currentTitle = recordingName ?? l10n.recordingDefaultTitle;
    final textController = TextEditingController(text: currentTitle);
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

    if (chosen != null && onNameChanged != null) {
      onNameChanged!(chosen.isEmpty ? l10n.recordingDefaultTitle : chosen);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final recording = phase == DiaryRecordingPhase.recording;
    final paused = phase == DiaryRecordingPhase.paused;
    final busy =
        phase == DiaryRecordingPhase.preparing ||
        phase == DiaryRecordingPhase.finishing;
    final hasSession = recording || paused;
    final displayName = recordingName ?? l10n.recordingDefaultTitle;

    return Material(
      color: ExpressiveSurfaces.cardColor(colors),
      shape: ExpressiveSurfaces.cardShape(colors),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Name title pill + close button
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _openRenameDialog(context, l10n, colors),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(
                              FontAwesomeIcons.microphoneLines,
                              size: 13,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: colors.onSurface,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            FaIcon(
                              FontAwesomeIcons.penToSquare,
                              size: 11,
                              color: colors.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: l10n.recordingClose,
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: const FaIcon(FontAwesomeIcons.xmark, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Top center: Microphone button or Loading
            SizedBox(
              height: 96,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.square(
                    dimension: 88,
                    child: busy
                        ? const Center(
                            child: SizedBox.square(
                              dimension: 40,
                              child: ClipRect(
                                child: ExpressiveLoadingIndicator(size: 40),
                              ),
                            ),
                          )
                        : FilledButton(
                            style: ButtonStyle(
                              animationDuration: ExpressiveMotion.duration(
                                context,
                                ExpressiveMotion.fast,
                              ),
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.zero,
                              ),
                              shape: WidgetStateProperty.resolveWith((states) {
                                return RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    states.contains(WidgetState.pressed)
                                        ? 24
                                        : 44,
                                  ),
                                );
                              }),
                              backgroundColor: WidgetStatePropertyAll(
                                recording
                                    ? colors.primaryContainer
                                    : colors.secondaryContainer,
                              ),
                            ),
                            onPressed: hasSession ? null : onStart,
                            child: Tooltip(
                              message: l10n.recordingStart,
                              child: FaIcon(
                                FontAwesomeIcons.microphone,
                                size: 32,
                                color: recording
                                    ? colors.onPrimaryContainer
                                    : colors.onSecondaryContainer,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // Timer display
            Text(
              formatRecordingDuration(elapsed),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),

            // Dynamic live voiceprint soundwave
            if (hasSession) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LiveVoiceprintVisualizer(
                  amplitude: amplitude,
                  isRecording: recording,
                  isPaused: paused,
                  height: 36,
                ),
              ),
            ],

            if (paused) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.recordingPaused,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            if (failure != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FaIcon(
                    FontAwesomeIcons.circleExclamation,
                    size: 13,
                    color: colors.error,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      switch (failure!) {
                        DiaryRecordingFailure.permissionDenied =>
                          l10n.recordingPermissionDenied,
                        DiaryRecordingFailure.recordingFailed =>
                          l10n.recordingFailed,
                        DiaryRecordingFailure.saveFailed =>
                          l10n.recordingSaveFailed,
                      },
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.error),
                    ),
                  ),
                ],
              ),
            ],

            // Session action controls (Pause/Resume, Finish)
            if (hasSession) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    tooltip: paused
                        ? l10n.recordingResume
                        : l10n.recordingPause,
                    style: ButtonStyle(
                      shape: ExpressiveControls.shape,
                      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                    ),
                    onPressed: paused ? onResume : onPause,
                    icon: FaIcon(
                      paused ? FontAwesomeIcons.play : FontAwesomeIcons.pause,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 24),
                  IconButton.filled(
                    tooltip: l10n.recordingFinish,
                    style: ButtonStyle(
                      shape: ExpressiveControls.shape,
                      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
                    ),
                    onPressed: onFinish,
                    icon: const FaIcon(FontAwesomeIcons.stop, size: 18),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
