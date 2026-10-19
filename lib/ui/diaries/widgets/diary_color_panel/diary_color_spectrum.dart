/// 自定义取色页的三个色谱控件：饱和度 / 亮度面、色相条、不透明度条。
///
/// - 输入：当前值；
/// - 输出：拖动中逐帧 `onChanged`（只更新面板里的预览），松手或手势被取消
///   时 `onChangeEnd`（由取色页写入正文，每次松手一步撤销）；
/// - 手指一按下就开始取色并接管手势：点一下即跳到该处，面板在矮窗口里纵向
///   滚动时也不会被滚动抢走；拖动中圆点放大一圈（`fast` + spatial）；
/// - 读屏：色相与不透明度是可调滑块（每步 10° / 10%），调整即写入。
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_spectrum_painters.dart';

/// 饱和度（横向）× 亮度（纵向）面。
class DiaryColorSaturationValueArea extends StatelessWidget {
  const DiaryColorSaturationValueArea({
    super.key,
    required this.color,
    required this.onChanged,
    required this.onChangeEnd,
    this.onChangeStart,
  });

  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    return Semantics(
      label: context.l10n.diaryColorPanelSaturationValue,
      value:
          '${(color.saturation * 100).round()}% · '
          '${(color.value * 100).round()}%',
      child: _SpectrumControl(
        painter: (double thumbRadius) => DiaryColorSaturationValuePainter(
          color: color,
          thumbRadius: thumbRadius,
          outline: outline,
        ),
        onChanged: (Offset fraction) => onChanged(
          color.withSaturation(fraction.dx).withValue(1 - fraction.dy),
        ),
        onChangeStart: onChangeStart,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

/// 竖向色相条（0°–360°）。
class DiaryColorHueSlider extends StatelessWidget {
  const DiaryColorHueSlider({
    super.key,
    required this.hue,
    required this.onChanged,
    required this.onChangeEnd,
    this.onChangeStart,
  });

  final double hue;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback onChangeEnd;

  static const double _step = 10;

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outlineVariant;
    void nudge(double delta) {
      onChanged((hue + delta).clamp(0, 360).toDouble());
      onChangeEnd();
    }

    return Semantics(
      slider: true,
      label: context.l10n.diaryColorPanelHue,
      value: '${hue.round()}°',
      increasedValue: '${(hue + _step).clamp(0, 360).round()}°',
      decreasedValue: '${(hue - _step).clamp(0, 360).round()}°',
      onIncrease: () => nudge(_step),
      onDecrease: () => nudge(-_step),
      child: _SpectrumControl(
        painter: (double thumbRadius) => DiaryColorHuePainter(
          hue: hue,
          thumbRadius: thumbRadius,
          outline: outline,
        ),
        onChanged: (Offset fraction) => onChanged(fraction.dy * 360),
        onChangeStart: onChangeStart,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

/// 竖向不透明度条（上不透明、下全透明），只在背景色目标出现。
class DiaryColorAlphaSlider extends StatelessWidget {
  const DiaryColorAlphaSlider({
    super.key,
    required this.color,
    required this.onChanged,
    required this.onChangeEnd,
    this.onChangeStart,
  });

  /// 带当前透明度的颜色。
  final Color color;
  final ValueChanged<double> onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback onChangeEnd;

  static const double _step = 0.1;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final alpha = color.a;
    String percent(double value) => '${(value.clamp(0, 1) * 100).round()}%';
    void nudge(double delta) {
      onChanged((alpha + delta).clamp(0, 1).toDouble());
      onChangeEnd();
    }

    return Semantics(
      slider: true,
      label: context.l10n.diaryColorPanelOpacity,
      value: percent(alpha),
      increasedValue: percent(alpha + _step),
      decreasedValue: percent(alpha - _step),
      onIncrease: () => nudge(_step),
      onDecrease: () => nudge(-_step),
      child: _SpectrumControl(
        painter: (double thumbRadius) => DiaryColorAlphaPainter(
          color: color,
          thumbRadius: thumbRadius,
          outline: colors.outlineVariant,
          checkerLight: colors.surfaceContainerLowest,
          checkerDark: colors.surfaceContainerHighest,
        ),
        onChanged: (Offset fraction) => onChanged(1 - fraction.dy),
        onChangeStart: onChangeStart,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

/// 按下即接管的拖动识别：在手势竞技场关闭前就宣布获胜，外层滚动拿不到。
class _ImmediatePanRecognizer extends PanGestureRecognizer {
  _ImmediatePanRecognizer({super.debugOwner});

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  String get debugDescription => 'immediate pan';
}

/// 色谱控件的公共部分：手势、位置换算与拖动中放大的圆点。
class _SpectrumControl extends StatefulWidget {
  const _SpectrumControl({
    required this.painter,
    required this.onChanged,
    required this.onChangeEnd,
    this.onChangeStart,
  });

  final CustomPainter Function(double thumbRadius) painter;

  /// 圆点中心在行程里的位置，横纵都已夹在 0–1。
  final ValueChanged<Offset> onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback onChangeEnd;

  @override
  State<_SpectrumControl> createState() => _SpectrumControlState();
}

class _SpectrumControlState extends State<_SpectrumControl> {
  bool _active = false;
  Size _size = Size.zero;

  Offset _fraction(Offset local) {
    final travel = diaryColorThumbTravel(_size);
    double along(double value, double start, double extent) =>
        extent <= 0 ? 0 : ((value - start) / extent).clamp(0, 1).toDouble();
    return Offset(
      along(local.dx, travel.left, travel.width),
      along(local.dy, travel.top, travel.height),
    );
  }

  void _handleStart(DragStartDetails details) {
    setState(() => _active = true);
    widget.onChangeStart?.call();
    widget.onChanged(_fraction(details.localPosition));
  }

  void _handleUpdate(DragUpdateDetails details) {
    widget.onChanged(_fraction(details.localPosition));
  }

  /// 松手与手势被取消（如面板收起）同样结束：预览里的颜色写入正文，
  /// 面板与正文不会停在不一致的状态。
  void _handleEnd() {
    if (!_active) return;
    if (mounted) setState(() => _active = false);
    widget.onChangeEnd();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _size = constraints.biggest;
        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: <Type, GestureRecognizerFactory>{
            _ImmediatePanRecognizer:
                GestureRecognizerFactoryWithHandlers<_ImmediatePanRecognizer>(
                  () => _ImmediatePanRecognizer(debugOwner: this),
                  (_ImmediatePanRecognizer recognizer) => recognizer
                    ..dragStartBehavior = DragStartBehavior.down
                    ..onStart = _handleStart
                    ..onUpdate = _handleUpdate
                    ..onEnd = ((_) => _handleEnd())
                    ..onCancel = _handleEnd,
                ),
          },
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(
              end: _active
                  ? kDiaryColorThumbActiveRadius
                  : kDiaryColorThumbRadius,
            ),
            duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
            curve: ExpressiveMotion.spatial,
            builder: (BuildContext context, double radius, Widget? child) =>
                CustomPaint(size: _size, painter: widget.painter(radius)),
          ),
        );
      },
    );
  }
}
