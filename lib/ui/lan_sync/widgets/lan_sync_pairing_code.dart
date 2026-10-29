// 配对面板上的 6 位核对码（DESIGN.md §5.27“配对面板”）。
//
// 分 3 + 3 两组（组间 12、格间 8），每格 46 × 62、16 圆角、`primaryContainer`
// 底、32 / w800 `onPrimaryContainer` 等宽数字。挂载时逐格自下而上弹入：一个
// AnimationController 驱动六段错开的 Interval，每格错开 [stagger]（`medium`
// 的 16%，即 40ms），每格自身走 `medium`、位移取 `spatial`、透明度取
// `effects`。格子是不透明的实色块（不是玻璃），用 Opacity 淡入不会丢模糊。
// 减少动画时总时长为 0，直接显示终态。
//
// 读屏把整块读作“配对码 482 916”，单个数字不再分别读出。

import 'package:flutter/material.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';

class LanSyncPairingCode extends StatefulWidget {
  const LanSyncPairingCode({super.key, required this.code});

  /// 6 位十进制核对码；不足或超出 6 位时按原样逐字显示（不应出现）。
  final String code;

  /// 相邻两格弹入的间隔：`medium` 的 16%（40ms）。
  static Duration get stagger => ExpressiveMotion.medium * 0.16;

  @override
  State<LanSyncPairingCode> createState() => _LanSyncPairingCodeState();
}

class _LanSyncPairingCodeState extends State<LanSyncPairingCode>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  late final List<CurvedAnimation> _positions = <CurvedAnimation>[
    for (var i = 0; i < widget.code.length; i++)
      CurvedAnimation(
        parent: _controller,
        curve: _intervalFor(i, ExpressiveMotion.spatial),
      ),
  ];
  late final List<CurvedAnimation> _opacities = <CurvedAnimation>[
    for (var i = 0; i < widget.code.length; i++)
      CurvedAnimation(
        parent: _controller,
        curve: _intervalFor(i, ExpressiveMotion.effects),
      ),
  ];
  bool _started = false;

  /// 全部格子弹完的总时长（未经减少动画换算）。
  Duration get _total {
    final digits = widget.code.length;
    return ExpressiveMotion.medium +
        LanSyncPairingCode.stagger * (digits > 1 ? digits - 1 : 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final duration = ExpressiveMotion.duration(context, _total);
    if (duration == Duration.zero) {
      _controller.value = 1;
    } else {
      _controller
        ..duration = duration
        ..forward();
    }
  }

  @override
  void dispose() {
    for (final animation in <CurvedAnimation>[..._positions, ..._opacities]) {
      animation.dispose();
    }
    _controller.dispose();
    super.dispose();
  }

  /// 第 [index] 格的动画区间（占总时长的比例）。
  Interval _intervalFor(int index, Curve curve) {
    final total = _total.inMicroseconds;
    final start = (LanSyncPairingCode.stagger * index).inMicroseconds / total;
    final end = start + ExpressiveMotion.medium.inMicroseconds / total;
    return Interval(start, end.clamp(0, 1).toDouble(), curve: curve);
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.code;
    final half = code.length ~/ 2;
    final first = code.substring(0, half);
    final second = code.substring(half);
    final tiles = <Widget>[];
    for (var i = 0; i < code.length; i++) {
      if (i > 0) tiles.add(SizedBox(width: i == half ? 12 : 8));
      tiles.add(
        _AnimatedTile(
          digit: code[i],
          position: _positions[i],
          opacity: _opacities[i],
        ),
      );
    }
    return Semantics(
      container: true,
      label: context.l10n.lanSyncPairCodeSemantics(first, second),
      child: ExcludeSemantics(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: tiles),
        ),
      ),
    );
  }
}

class _AnimatedTile extends StatelessWidget {
  const _AnimatedTile({
    required this.digit,
    required this.position,
    required this.opacity,
  });

  final String digit;
  final Animation<double> position;
  final Animation<double> opacity;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tile = Container(
      width: 46,
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        digit,
        style: theme.textTheme.headlineMedium?.copyWith(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: colors.onPrimaryContainer,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
    return AnimatedBuilder(
      animation: position,
      child: tile,
      builder: (BuildContext context, Widget? child) {
        // 自下而上：从下方 24dp 处弹到原位，spatial 允许轻微过冲。
        final dy = (1 - position.value) * 24;
        return Opacity(
          opacity: opacity.value.clamp(0, 1).toDouble(),
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
    );
  }
}
