import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/theme/expressive_controls.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_field.dart';
import 'package:node_diary/ui/diaries/models/diary_recording_state.dart';
import 'package:node_diary/ui/widgets/delayed_loading_gate.dart';
import 'package:node_diary/ui/widgets/expressive_entrance.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:node_diary/ui/widgets/expressive_state_blend.dart';

/// 录音面板底部的操作区：一个随阶段变形的主按钮，加上会话中才展开的暂停/继续键。
///
/// 主按钮始终是“当前阶段最该点的那个动作”——待机时是麦克风（开始），录音/暂停
/// 时是方形的结束键。这样最大、最醒目的控件永远可用，不再出现“最大的按钮是
/// 灰掉的摆设、真正的操作藏在下面小按钮里”。
///
/// [settled] 决定版面，[phase] 决定可交互性：暂停/继续的原生调用期间 [phase] 为
/// `preparing`，版面保持不变，只是暂时不响应点击。
class DiaryRecordingControls extends StatelessWidget {
  const DiaryRecordingControls({
    super.key,
    required this.settled,
    required this.phase,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
  });

  static const double heroSize = 72;
  static const double secondarySize = 56;
  static const double _gap = 20;

  final DiaryRecordingPhase settled;
  final DiaryRecordingPhase phase;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final session = settled != DiaryRecordingPhase.idle;
    final busy =
        phase == DiaryRecordingPhase.preparing ||
        phase == DiaryRecordingPhase.finishing;
    // 暂停/继续的原生调用只有几十毫秒，出等待指示只会闪一下；只有开始（可能在
    // 等权限弹窗）和结束（落盘）才值得给等待反馈。
    final waiting =
        busy && !(session && phase == DiaryRecordingPhase.preparing);

    return SizedBox(
      height: heroSize,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 暂停键从主按钮左侧展开：宽度补间推着主按钮平滑右移，而不是弹出新控件。
          AnimatedSize(
            duration: ExpressiveMotion.durationNonZero(
              context,
              ExpressiveMotion.medium,
            ),
            curve: ExpressiveMotion.effects,
            alignment: Alignment.centerRight,
            // 不裁剪：按钮始终贴着主按钮左侧淡入，而不是被逐渐张开的边界切成半个圆。
            clipBehavior: Clip.none,
            child: session
                ? Padding(
                    padding: const EdgeInsets.only(right: _gap),
                    child: ExpressiveEntrance(
                      offset: const Offset(0.4, 0),
                      child: _SecondaryButton(
                        paused: settled == DiaryRecordingPhase.paused,
                        enabled: !busy,
                        onPause: onPause,
                        onResume: onResume,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          _HeroButton(
            session: session,
            busy: busy,
            waiting: waiting,
            onPressed: session ? onFinish : onStart,
          ),
        ],
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.session,
    required this.busy,
    required this.waiting,
    required this.onPressed,
  });

  final bool session;
  final bool busy;
  final bool waiting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    // 实心主色只在“正在录音、可以结束”时出现；待机与等待都用柔和容器色。
    // ButtonStyle 只补间形状，换色经 ExpressiveStateBlend 与形变同步过渡。
    final soft = !session || waiting;
    // 待机是圆，会话中收成圆角方块（“停止”的形状），按压再收紧一档。
    final restingRadius = session ? 26.0 : 36.0;

    return Tooltip(
      message: session ? l10n.recordingFinish : l10n.recordingStart,
      child: ExpressiveStateBlend(
        active: !soft,
        duration: ExpressiveMotion.medium,
        child: _buildIcon(),
        builder: (context, t, icon) => FilledButton(
          onPressed: busy ? null : onPressed,
          style: ButtonStyle(
            animationDuration: ExpressiveMotion.duration(
              context,
              ExpressiveMotion.medium,
            ),
            fixedSize: const WidgetStatePropertyAll(
              Size.square(DiaryRecordingControls.heroSize),
            ),
            padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            // 禁用态也使用同一套颜色：busy 是“正在处理”而不是“不可用”，不能闪成灰色。
            backgroundColor: WidgetStatePropertyAll(
              Color.lerp(colors.primaryContainer, colors.primary, t),
            ),
            foregroundColor: WidgetStatePropertyAll(
              Color.lerp(colors.onPrimaryContainer, colors.onPrimary, t),
            ),
            shape: WidgetStateProperty.resolveWith(
              (states) => RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  states.contains(WidgetState.pressed)
                      ? restingRadius - 10
                      : restingRadius,
                ),
              ),
            ),
          ),
          child: icon,
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return DelayedLoadingGate(
      loading: waiting,
      builder: (context, showLoading) => ExpressiveIconSwap(
        switchKey: showLoading ? 'loading' : (session ? 'stop' : 'mic'),
        child: showLoading
            ? const ExpressiveLoadingIndicator(size: 40)
            : FaIcon(
                session ? FontAwesomeIcons.stop : FontAwesomeIcons.microphone,
                size: session ? 22 : 28,
              ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.paused,
    required this.enabled,
    required this.onPause,
    required this.onResume,
  });

  final bool paused;
  final bool enabled;
  final VoidCallback onPause;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final style = ButtonStyle(
      shape: ExpressiveControls.shape,
      animationDuration: ExpressiveMotion.duration(
        context,
        ExpressiveMotion.fast,
      ),
      fixedSize: const WidgetStatePropertyAll(
        Size.square(DiaryRecordingControls.secondarySize),
      ),
      backgroundColor: WidgetStatePropertyAll(colors.secondaryContainer),
      foregroundColor: WidgetStatePropertyAll(colors.onSecondaryContainer),
    );
    return IconButton.filledTonal(
      tooltip: paused ? l10n.recordingResume : l10n.recordingPause,
      // 面板为玻璃时换成玻璃底色与描边（主录音键是强调色，不跟随）。
      style: AppGlassField.tonalButtonStyle(context)?.merge(style) ?? style,
      onPressed: enabled ? (paused ? onResume : onPause) : null,
      icon: ExpressiveIconSwap(
        switchKey: paused ? 'play' : 'pause',
        child: FaIcon(
          paused ? FontAwesomeIcons.play : FontAwesomeIcons.pause,
          size: 20,
        ),
      ),
    );
  }
}
