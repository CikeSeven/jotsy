import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../widgets/expressive_image_frame.dart';
import '../../../widgets/long_image/long_image_policy.dart';

/// 背景图的焦点取景器：整张图按原比例显示在限高的框里，点按或拖动设定
/// 焦点，焦点处画一个小圆环。
///
/// 输入：图片文件、原图尺寸（经 `ImageDimensions` 读取，只读文件头）与当前
/// 焦点（`Alignment` 坐标，-1..1）；输出：拖动中经 [onPreview] 给出新焦点
/// （只改草稿，预览实时变化），松手（含单击、手势被取消）经 [onCommit] 提交。
///
/// 框的比例与原图相同，所以框内坐标就是图片坐标，不必再换算 contain 的
/// 留白。焦点按“图片上的位置”理解：x = 0 为左缘、1 为右缘，对应
/// `Alignment.x` = -1..1——cover 裁切时 Alignment 决定保留哪一侧，用户点在
/// 图片左侧，裁切就偏向左侧。
///
/// 手势用自带的 [_EagerPanRecognizer]：按下即赢得手势竞争。取景器在可滚动
/// 的选项面板里，普通的拖动识别器（含 SDK 的 Immediate 多指拖动，它同样要
/// 先越过斜率）与列表的纵向滚动同时竞争，纵向一拖就被滚动抢走，焦点只能
/// 横着挪；按下即接受也让单击不必等手势竞技场结算。只认第一根手指。
class AppSurfaceFocusViewfinder extends StatefulWidget {
  const AppSurfaceFocusViewfinder({
    super.key,
    required this.file,
    required this.imageSize,
    required this.alignX,
    required this.alignY,
    required this.onPreview,
    required this.onCommit,
  });

  final File file;
  final Size imageSize;
  final double alignX;
  final double alignY;
  final void Function(double x, double y) onPreview;
  final void Function(double x, double y) onCommit;

  /// 取景器的最大高度：竖图不至于把下面的滑块挤出屏幕。
  static const double maxHeight = 200;

  @override
  State<AppSurfaceFocusViewfinder> createState() =>
      _AppSurfaceFocusViewfinderState();
}

class _AppSurfaceFocusViewfinderState extends State<AppSurfaceFocusViewfinder> {
  final GlobalKey _boxKey = GlobalKey(debugLabel: 'AppSurfaceFocusBox');
  Offset? _last;

  /// 全局坐标 → 焦点（-1..1，按 0.01 取整，与模型的步进一致）。
  Offset? _focusAt(Offset globalPosition) {
    final box = _boxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) return null;
    final local = box.globalToLocal(globalPosition);
    double axis(double value, double extent) {
      final ratio = (value / extent).clamp(0.0, 1.0);
      return ((ratio * 2 - 1) * 100).round() / 100;
    }

    return Offset(
      axis(local.dx, box.size.width),
      axis(local.dy, box.size.height),
    );
  }

  void _start(Offset globalPosition) {
    _last = null;
    _update(globalPosition);
  }

  void _update(Offset globalPosition) {
    final next = _focusAt(globalPosition);
    if (next == null || next == _last) return;
    _last = next;
    widget.onPreview(next.dx, next.dy);
  }

  /// 松手或手势被取消：提交最后的焦点（取消时不回退——草稿已经显示在预览
  /// 里，留在半途比跳回去更符合用户看到的样子）。
  void _finish() {
    final last = _last;
    _last = null;
    if (last != null && mounted) widget.onCommit(last.dx, last.dy);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final image = widget.imageSize;
    final aspect = image.width > 0 && image.height > 0
        ? image.width / image.height
        : 1.0;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        var width = constraints.maxWidth;
        var height = width / aspect;
        if (height > AppSurfaceFocusViewfinder.maxHeight) {
          height = AppSurfaceFocusViewfinder.maxHeight;
          width = height * aspect;
        }
        final fx = (widget.alignX.clamp(-1.0, 1.0) + 1) / 2;
        final fy = (widget.alignY.clamp(-1.0, 1.0) + 1) / 2;
        const ring = 24.0;
        return Center(
          child: Semantics(
            label: l10n.appSurfaceFocusSemantics(
              '${(fx * 100).round()}',
              '${(fy * 100).round()}',
            ),
            child: RawGestureDetector(
              gestures: <Type, GestureRecognizerFactory>{
                _EagerPanRecognizer:
                    GestureRecognizerFactoryWithHandlers<_EagerPanRecognizer>(
                      _EagerPanRecognizer.new,
                      (_EagerPanRecognizer recognizer) => recognizer
                        ..onStart = _start
                        ..onUpdate = _update
                        ..onEnd = _finish,
                    ),
              },
              child: ClipRRect(
                key: _boxKey,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      Image(
                        image: boundedImageProvider(
                          FileImage(widget.file),
                          width: (width * dpr).ceil(),
                          height: (height * dpr).ceil(),
                        ),
                        fit: BoxFit.fill,
                        frameBuilder: expressiveImageFrameBuilder,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) =>
                            ColoredBox(color: scheme.surfaceContainerHighest),
                      ),
                      Positioned(
                        left: fx * width - ring / 2,
                        top: fy * height - ring / 2,
                        width: ring,
                        height: ring,
                        child: const _FocusRing(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 焦点圆环：主题色环外再包一圈表面色，任意图片上都看得清。
class _FocusRing extends StatelessWidget {
  const _FocusRing();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: DecoratedBox(
        key: const ValueKey<String>('appSurfaceFocusRing'),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.surface, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: scheme.primary, width: 2.5),
            ),
          ),
        ),
      ),
    );
  }
}

/// 按下即接受的单指拖动识别器：按下给出起点，移动给出位置，抬起、取消或
/// 输掉竞争时结束。其余手指在第一根抬起前一律不认。
class _EagerPanRecognizer extends OneSequenceGestureRecognizer {
  ValueChanged<Offset>? onStart;
  ValueChanged<Offset>? onUpdate;
  VoidCallback? onEnd;
  int? _pointer;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) return;
    super.addAllowedPointer(event);
    _pointer = event.pointer;
    resolve(GestureDisposition.accepted);
    onStart?.call(event.position);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      onUpdate?.call(event.position);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _end();
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    super.rejectGesture(pointer);
    if (pointer == _pointer) {
      _end();
      stopTrackingPointer(pointer);
    }
  }

  void _end() {
    if (_pointer == null) return;
    _pointer = null;
    onEnd?.call();
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'app surface focus pan';
}
