import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_controls.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

/// Icon-led recording controls. Loading occupies its own bounded slot, never
/// the elapsed-time or error text; all colors follow the Expressive theme.
class DiaryRecordingPanel extends StatelessWidget {
  const DiaryRecordingPanel({
    super.key,
    required this.phase,
    required this.elapsed,
    required this.failure,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onClose,
  });

  final DiaryRecordingPhase phase;
  final Duration elapsed;
  final DiaryRecordingFailure? failure;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;
  final VoidCallback onClose;

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

    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 104,
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
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      tooltip: l10n.recordingClose,
                      onPressed: onClose,
                      icon: const FaIcon(FontAwesomeIcons.xmark, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              formatRecordingDuration(elapsed),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.onSurface,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            if (paused) ...[
              const SizedBox(height: 4),
              Text(l10n.recordingPaused),
            ],
            if (failure != null) ...[
              const SizedBox(height: 8),
              Text(
                switch (failure!) {
                  DiaryRecordingFailure.permissionDenied =>
                    l10n.recordingPermissionDenied,
                  DiaryRecordingFailure.recordingFailed => l10n.recordingFailed,
                  DiaryRecordingFailure.saveFailed => l10n.recordingSaveFailed,
                },
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],
            if (hasSession) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    tooltip: paused
                        ? l10n.recordingResume
                        : l10n.recordingPause,
                    style: ButtonStyle(shape: ExpressiveControls.shape),
                    onPressed: paused ? onResume : onPause,
                    icon: FaIcon(
                      paused ? FontAwesomeIcons.play : FontAwesomeIcons.pause,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 24),
                  IconButton.filled(
                    tooltip: l10n.recordingFinish,
                    style: ButtonStyle(shape: ExpressiveControls.shape),
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
