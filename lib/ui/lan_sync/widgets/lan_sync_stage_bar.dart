// 会话阶段条（DESIGN.md §5.27“同步中”）：连接 · 比对 · 传输 · 合并。
//
// 四个 24dp 圆点等分排开、由 2dp 线连接，按阶段下标分三种样子：
// - 已完成：`primary` 实心 + `onPrimary` 对勾（14）；
// - 当前：`primaryContainer` 底 + 4dp 外圈光晕 + 8dp `primary` 内点，
//   标签 `primary` w700（亮色下 primaryContainer 是深色，onPrimaryContainer
//   落在白卡片上几乎看不见）；
// - 未到：`outlineVariant` 空心。
// 阶段切换时圆点以 `medium` + `spatial` 缩放换形（位移 / 缩放允许弹性），
// 连线与标签颜色以 `medium` + `effects` 补间（颜色不越界）。读屏不读这里，
// 阶段由会话面板的读屏文字给出。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../models/lan_sync_session_view.dart';

enum _StepState { done, current, pending }

class LanSyncStageBar extends StatelessWidget {
  const LanSyncStageBar({super.key, required this.stage});

  final LanSyncSessionStage stage;

  static const double _dot = 24;

  static String _label(AppLocalizations l10n, LanSyncSessionStage stage) {
    return switch (stage) {
      LanSyncSessionStage.connecting => l10n.lanSyncStepConnect,
      LanSyncSessionStage.comparing => l10n.lanSyncStepCompare,
      LanSyncSessionStage.transferring => l10n.lanSyncStepTransfer,
      LanSyncSessionStage.merging => l10n.lanSyncStepMerge,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    const stages = LanSyncSessionStage.values;
    final current = stage.index;
    final duration = ExpressiveMotion.duration(
      context,
      ExpressiveMotion.medium,
    );
    _StepState stateOf(int index) => index < current
        ? _StepState.done
        : (index == current ? _StepState.current : _StepState.pending);

    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // 每个阶段占四分之一宽、圆点居中；连线画在相邻圆点的边缘之间。
          final slot = constraints.maxWidth / stages.length;
          // 当前阶段的光晕画在圆点外 4dp，不能被 Stack 裁掉。
          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              for (var i = 0; i < stages.length - 1; i++)
                Positioned(
                  left: slot * (i + 0.5) + _dot / 2 + 4,
                  width: (slot - _dot - 8).clamp(0.0, double.infinity),
                  top: _dot / 2 - 1,
                  height: 2,
                  child: AnimatedContainer(
                    duration: duration,
                    curve: ExpressiveMotion.effects,
                    decoration: BoxDecoration(
                      color: i < current
                          ? colors.primary
                          : colors.outlineVariant,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (var i = 0; i < stages.length; i++)
                    Expanded(
                      child: _Step(
                        state: stateOf(i),
                        label: _label(l10n, stages[i]),
                        duration: duration,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.state,
    required this.label,
    required this.duration,
  });

  final _StepState state;
  final String label;
  final Duration duration;

  Widget _dot(ColorScheme colors) {
    const size = LanSyncStageBar._dot;
    return switch (state) {
      _StepState.done => Container(
        key: const ValueKey<_StepState>(_StepState.done),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primary,
          shape: BoxShape.circle,
        ),
        child: FaIcon(
          FontAwesomeIcons.check,
          size: 14,
          color: colors.onPrimary,
        ),
      ),
      // 外圈光晕用不模糊的 spreadRadius 阴影画在盒子外，不占布局。
      _StepState.current => Container(
        key: const ValueKey<_StepState>(_StepState.current),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          shape: BoxShape.circle,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.primary.withValues(alpha: 0.16),
              spreadRadius: 4,
            ),
          ],
        ),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: colors.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
      _StepState.pending => Container(
        key: const ValueKey<_StepState>(_StepState.pending),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: colors.outlineVariant, width: 2),
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final labelStyle = theme.textTheme.labelMedium!.copyWith(
      fontSize: 12,
      fontWeight: switch (state) {
        _StepState.current => FontWeight.w700,
        _StepState.done => FontWeight.w600,
        _StepState.pending => FontWeight.w500,
      },
      color: switch (state) {
        _StepState.current => colors.primary,
        _StepState.done => colors.onSurface,
        _StepState.pending => colors.onSurfaceVariant,
      },
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox.square(
          dimension: LanSyncStageBar._dot,
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: ExpressiveMotion.spatial,
            switchOutCurve: ExpressiveMotion.exit,
            transitionBuilder: (Widget child, Animation<double> animation) =>
                ScaleTransition(scale: animation, child: child),
            child: _dot(colors),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedDefaultTextStyle(
          duration: duration,
          curve: ExpressiveMotion.effects,
          style: labelStyle,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
