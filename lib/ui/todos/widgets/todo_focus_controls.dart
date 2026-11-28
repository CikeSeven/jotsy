import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/expressive_icon_swap.dart';
import '../../widgets/expressive_state_blend.dart';
import '../models/todo_focus_run.dart';

/// 专注页的 M3 Expressive 形态形变操控栏：左结束 · 中央超大形变暂停/继续 ·
/// 右快捷 +5 分钟（休息时换成跳过休息）。
///
/// 核心视觉语言（对齐 Google Clock M3 Expressive）：
/// - 中央主按钮在运行中为柔和方圆（squircle，`primaryContainer` /
///   `tertiaryContainer`，安静不抢眼），暂停时弹性舒展为高对比全圆胶囊
///   （`primary` / `tertiary`），按下时真弹簧缩放到 0.94 并收紧圆角；
/// - 两侧次要按钮统一经 `AppGlassField.tonalButtonStyle` 跟随玻璃材质。
class TodoFocusControls extends StatelessWidget {
  const TodoFocusControls({
    super.key,
    required this.run,
    required this.onPause,
    required this.onResume,
    required this.onExtend,
    required this.onStop,
    required this.onSkipBreak,
  });

  final TodoFocusRun run;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onExtend;
  final VoidCallback onStop;
  final VoidCallback onSkipBreak;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tonal = AppGlassField.tonalButtonStyle(context);
    final canExtend =
        run.plannedSeconds < TodoFocusRules.maxPlannedMinutes * 60;

    final extendOwnStyle = FilledButton.styleFrom(
      minimumSize: const Size(74, 56),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      textStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
    final extendStyle = tonal?.merge(extendOwnStyle) ?? extendOwnStyle;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          width: 82,
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: IconButton.filledTonal(
              style: tonal,
              iconSize: 18,
              constraints: const BoxConstraints.tightFor(width: 56, height: 56),
              tooltip: l10n.todoFocusStop,
              onPressed: () {
                unawaited(HapticFeedback.lightImpact());
                onStop();
              },
              icon: const FaIcon(FontAwesomeIcons.stop),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.l),
        _MorphingPrimaryButton(
          paused: run.paused,
          isBreak: run.phase.isBreak,
          label: run.paused ? l10n.todoFocusResume : l10n.todoFocusPause,
          onPressed: () {
            unawaited(HapticFeedback.lightImpact());
            (run.paused ? onResume : onPause)();
          },
        ),
        const SizedBox(width: AppSpacing.l),
        SizedBox(
          width: 82,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: run.phase.isBreak
                ? IconButton.filledTonal(
                    style: tonal,
                    iconSize: 18,
                    constraints: const BoxConstraints.tightFor(
                      width: 56,
                      height: 56,
                    ),
                    tooltip: l10n.todoFocusSkipBreak,
                    onPressed: () {
                      unawaited(HapticFeedback.lightImpact());
                      onSkipBreak();
                    },
                    icon: const FaIcon(FontAwesomeIcons.forwardStep),
                  )
                : Tooltip(
                    message: l10n.todoFocusExtend,
                    child: FilledButton.tonal(
                      style: extendStyle,
                      onPressed: canExtend
                          ? () {
                              unawaited(HapticFeedback.selectionClick());
                              onExtend();
                            }
                          : null,
                      child: Text(l10n.todoFocusExtendShort),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// 中央主按钮：运行（方圆容器）↔ 暂停（高亮胶囊）弹性形变，带按压弹簧反馈。
class _MorphingPrimaryButton extends StatefulWidget {
  const _MorphingPrimaryButton({
    required this.paused,
    required this.isBreak,
    required this.label,
    required this.onPressed,
  });

  final bool paused;
  final bool isBreak;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_MorphingPrimaryButton> createState() => _MorphingPrimaryButtonState();
}

class _MorphingPrimaryButtonState extends State<_MorphingPrimaryButton>
    with SingleTickerProviderStateMixin {
  static const Tolerance _tolerance = Tolerance(distance: 1e-3, velocity: 1e-2);

  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );
  bool _pressed = false;

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
    ExpressiveMotion.springTo(
      context,
      _scale,
      value ? 0.94 : 1.0,
      spring: ExpressiveMotion.springSpatialFast,
      tolerance: _tolerance,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final paused = widget.paused;
    final isBreak = widget.isBreak;

    final runningBg = isBreak
        ? scheme.tertiaryContainer
        : scheme.primaryContainer;
    final runningFg = isBreak
        ? scheme.onTertiaryContainer
        : scheme.onPrimaryContainer;
    final pausedBg = isBreak ? scheme.tertiary : scheme.primary;
    final pausedFg = isBreak ? scheme.onTertiary : scheme.onPrimary;

    final radius = _pressed ? 16.0 : (paused ? 36.0 : 24.0);
    final targetWidth = paused ? 148.0 : 128.0;

    return Tooltip(
      message: widget.label,
      child: Semantics(
        button: true,
        label: widget.label,
        excludeSemantics: true,
        child: ScaleTransition(
          scale: _scale,
          child: ExpressiveStateBlend(
            active: paused,
            duration: ExpressiveMotion.medium,
            builder: (BuildContext context, double t, Widget? _) {
              final bg = Color.lerp(runningBg, pausedBg, t)!;
              final fg = Color.lerp(runningFg, pausedFg, t)!;
              return AnimatedContainer(
                duration: ExpressiveMotion.duration(
                  context,
                  ExpressiveMotion.medium,
                ),
                curve: ExpressiveMotion.spatial,
                width: targetWidth,
                height: 72,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(radius),
                ),
                child: Material(
                  type: MaterialType.transparency,
                  borderRadius: BorderRadius.circular(radius),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: widget.onPressed,
                    onHighlightChanged: _setPressed,
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          ExpressiveIconSwap(
                            switchKey: paused,
                            child: FaIcon(
                              paused
                                  ? FontAwesomeIcons.play
                                  : FontAwesomeIcons.pause,
                              size: 20,
                              color: fg,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s + 2),
                          AnimatedSwitcher(
                            duration: ExpressiveMotion.duration(
                              context,
                              ExpressiveMotion.fast,
                            ),
                            switchInCurve: ExpressiveMotion.effects,
                            switchOutCurve: ExpressiveMotion.exit,
                            child: Text(
                              widget.label,
                              key: ValueKey<String>(widget.label),
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: fg,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
