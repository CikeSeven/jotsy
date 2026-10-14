import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';
import 'package:node_diary/ui/widgets/delayed_loading_gate.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';

/// 顶行：录音徽标、名称（可重命名）、已播/总时长。
class DiaryAudioPlayerHeader extends StatelessWidget {
  const DiaryAudioPlayerHeader({
    super.key,
    required this.title,
    required this.failed,
    required this.position,
    required this.duration,
    required this.onRename,
  });

  final String title;
  final bool failed;
  final Duration position;
  final Duration duration;

  /// 为 null 时不显示重命名入口（只读或播放失败）。
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SizedBox.square(
            dimension: 28,
            child: Center(
              child: FaIcon(
                FontAwesomeIcons.microphoneLines,
                size: 12,
                color: colors.onPrimaryContainer,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: failed ? colors.error : colors.onSurface,
                  ),
                ),
              ),
              if (onRename != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: context.l10n.recordingRename,
                  iconSize: 12,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  onPressed: onRename,
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
        // 已播放时长高亮、总时长弱化：播放时视线只需要追踪前半段数字。
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: formatRecordingDuration(position),
                style: TextStyle(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(text: ' / ${formatRecordingDuration(duration)}'),
            ],
          ),
          style: textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w500,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// 播放/暂停按钮：播放中从圆形收成圆角方块并换成实心主色（与录音面板的主按钮
/// 同一套“选中即变形”语言）；图标切换带缩放淡入。
class DiaryAudioPlayButton extends StatelessWidget {
  const DiaryAudioPlayButton({
    super.key,
    required this.playing,
    required this.loading,
    required this.failed,
    required this.onPressed,
  });

  static const double _size = 44;

  final bool playing;
  final bool loading;
  final bool failed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final restingRadius = playing ? 16.0 : _size / 2;
    // 形状随 ButtonStyle 的隐式动画形变，但它不补间颜色：tonal ↔ 实心主色的
    // 换色经 ExpressiveStateBlend 与形变同步过渡，而不是一帧跳色。
    return ExpressiveStateBlend(
      active: playing,
      duration: ExpressiveMotion.medium,
      child: _buildIcon(),
      builder: (context, t, icon) => IconButton.filledTonal(
        tooltip: playing
            ? l10n.recordingPlaybackPause
            : l10n.recordingPlaybackPlay,
        style: ButtonStyle(
          animationDuration: ExpressiveMotion.duration(
            context,
            ExpressiveMotion.medium,
          ),
          fixedSize: const WidgetStatePropertyAll(Size.square(_size)),
          // 失败时交还给主题的禁用配色，才能看出“不可用”。
          backgroundColor: failed
              ? null
              : WidgetStatePropertyAll(
                  Color.lerp(colors.secondaryContainer, colors.primary, t),
                ),
          foregroundColor: failed
              ? null
              : WidgetStatePropertyAll(
                  Color.lerp(colors.onSecondaryContainer, colors.onPrimary, t),
                ),
          shape: WidgetStateProperty.resolveWith(
            (states) => RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                states.contains(WidgetState.pressed) ? 12 : restingRadius,
              ),
            ),
          ),
        ),
        onPressed: failed ? null : onPressed,
        icon: icon!,
      ),
    );
  }

  Widget _buildIcon() {
    // 取音频通常很快：延迟出现等待指示，避免每次点播放都闪一下。
    return DelayedLoadingGate(
      loading: loading,
      builder: (context, showLoading) => ExpressiveIconSwap(
        switchKey: showLoading ? 'loading' : (playing ? 'pause' : 'play'),
        child: showLoading
            ? const ExpressiveLoadingIndicator(size: 24)
            : FaIcon(
                playing ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                size: 15,
              ),
      ),
    );
  }
}
