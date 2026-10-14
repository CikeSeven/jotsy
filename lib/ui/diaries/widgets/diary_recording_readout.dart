import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';

/// 计时器上方的一行状态：待机提示 / 录音中 / 已暂停 / 失败原因。
///
/// 一行同时只承载一种信息，且最小高度固定，这样状态切换只发生淡入淡出，
/// 面板整体高度不变。
class DiaryRecordingStatus extends StatelessWidget {
  const DiaryRecordingStatus({
    super.key,
    required this.settled,
    required this.failure,
    required this.breath,
  });

  final DiaryRecordingPhase settled;
  final DiaryRecordingFailure? failure;
  final Animation<double> breath;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final label = Theme.of(context).textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: colors.onSurfaceVariant,
    );

    final Widget line;
    if (failure != null) {
      line = _StatusLine(
        key: ValueKey<Object>(failure!),
        leading: FaIcon(
          FontAwesomeIcons.circleExclamation,
          size: 12,
          color: colors.error,
        ),
        text: switch (failure!) {
          DiaryRecordingFailure.permissionDenied =>
            l10n.recordingPermissionDenied,
          DiaryRecordingFailure.recordingFailed => l10n.recordingFailed,
          DiaryRecordingFailure.saveFailed => l10n.recordingSaveFailed,
        },
        style: label?.copyWith(color: colors.error),
      );
    } else {
      line = switch (settled) {
        DiaryRecordingPhase.recording => _StatusLine(
          key: const ValueKey<String>('recording'),
          leading: FadeTransition(
            opacity: breath,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.error,
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(dimension: 8),
            ),
          ),
          text: l10n.recordingStatusRecording,
          style: label,
        ),
        DiaryRecordingPhase.paused => _StatusLine(
          key: const ValueKey<String>('paused'),
          leading: FaIcon(
            FontAwesomeIcons.pause,
            size: 10,
            color: colors.onSurfaceVariant,
          ),
          text: l10n.recordingPaused,
          style: label,
        ),
        _ => _StatusLine(
          key: const ValueKey<String>('idle'),
          text: l10n.recordingIdleHint,
          style: label?.copyWith(fontWeight: FontWeight.w500),
        ),
      };
    }

    return AnimatedSize(
      duration: ExpressiveMotion.durationNonZero(
        context,
        ExpressiveMotion.fast,
      ),
      curve: ExpressiveMotion.effects,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24),
        // 淡出占前半程、淡入占后半程（fade through）：新旧文案不会同时可见，
        // 否则两行不同宽度的文字会在切换瞬间叠在一起。
        child: AnimatedSwitcher(
          duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
          switchInCurve: Interval(0.5, 1, curve: ExpressiveMotion.effects),
          switchOutCurve: Interval(0.5, 1, curve: ExpressiveMotion.exit),
          child: line,
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({super.key, this.leading, required this.text, this.style});

  final Widget? leading;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 8)],
        Flexible(
          child: Text(text, textAlign: TextAlign.center, style: style),
        ),
      ],
    );
  }
}

/// 大号等宽计时：待机时弱化，录音时全亮，暂停时随呼吸缓慢明灭（表示“停着但没丢”）。
class DiaryRecordingTimer extends StatelessWidget {
  const DiaryRecordingTimer({
    super.key,
    required this.text,
    required this.settled,
    required this.breath,
  });

  final String text;
  final DiaryRecordingPhase settled;
  final Animation<double> breath;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final paused = settled == DiaryRecordingPhase.paused;
    return AnimatedOpacity(
      opacity: settled == DiaryRecordingPhase.idle ? 0.38 : 1,
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      curve: ExpressiveMotion.effects,
      child: FadeTransition(
        opacity: paused ? breath : kAlwaysCompleteAnimation,
        // 大字号与系统字体放大叠加时按比例缩小而不是溢出。
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontSize: 44,
              height: 1.1,
              fontWeight: FontWeight.w500,
              color: colors.onSurface,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
    );
  }
}
