import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/expressive_motion.dart';
import '../app_surface/widgets/app_glass_field.dart';
import 'expressive_state_blend.dart';

/// 列表右侧的字母索引条：按下或上下拖动即跳到对应分组。
///
/// 输入：分组字母 [letters]（只列出现有的分组）、当前所在分组
/// [activeLetter]（由列表随滚动更新）；输出：[onLetterSelected]，按下时与
/// 拖到另一个字母时各调用一次，调用方据此直接跳转（跟手，不做补间）。
///
/// - 布局：占满父级给的高度（整条都可以按），字母按 [maxSlotExtent] 等高
///   排在竖直居中的一段里；放不下（每格不足 [minSlotExtent]，多见于键盘
///   弹起后）时整条不显示，免得字挤成一团。
/// - 按住期间：字母段后衬一条胶囊底，左侧出现水滴形气泡放大显示当前字母，
///   拖到新字母轻震一次（`selectionClick`）；松手后气泡淡出，高亮回到
///   [activeLetter]。
/// - 字母不随系统字号缩放：格高由可用高度决定，放大后会溢出；气泡负责
///   放大显示。
class AlphabetIndexBar extends StatefulWidget {
  const AlphabetIndexBar({
    super.key,
    required this.letters,
    required this.activeLetter,
    required this.onLetterSelected,
  });

  /// 索引条宽度；调用方据此给列表留出右侧空间。
  static const double width = 22;
  static const double maxSlotExtent = 20;
  static const double minSlotExtent = 13;
  static const double _bubbleSize = 52;
  static const double _bubbleGap = 12;
  static const double _touchSlop = 2;

  final List<String> letters;
  final ValueListenable<String?> activeLetter;
  final ValueChanged<String> onLetterSelected;

  @override
  State<AlphabetIndexBar> createState() => _AlphabetIndexBarState();
}

class _AlphabetIndexBarState extends State<AlphabetIndexBar>
    with SingleTickerProviderStateMixin {
  /// 手指按住的字母序号；松手后为 null。
  int? _touched;

  /// 气泡淡出期间仍停在最后一个字母上。
  int _bubbleIndex = 0;

  /// 气泡出现进度：按下时正向、松手时反向；完全收起后不再构建气泡。
  late final AnimationController _bubble = AnimationController(vsync: this);
  late final Animation<double> _bubbleOpacity = CurvedAnimation(
    parent: _bubble,
    curve: ExpressiveMotion.effects,
    reverseCurve: ExpressiveMotion.exit,
  );
  late final Animation<double> _bubbleScale = Tween<double>(begin: 0.6, end: 1)
      .animate(
        CurvedAnimation(
          parent: _bubble,
          curve: ExpressiveMotion.spatial,
          reverseCurve: ExpressiveMotion.exit,
        ),
      );

  @override
  void dispose() {
    _bubble.dispose();
    super.dispose();
  }

  void _touch(int index) {
    if (index == _touched) return;
    if (_touched == null) {
      // 时长每次按下时取，系统“减少动态效果”时为 0，气泡直接出现。
      _bubble.duration = ExpressiveMotion.duration(
        context,
        ExpressiveMotion.fast,
      );
      unawaited(_bubble.forward());
    }
    setState(() {
      _touched = index;
      _bubbleIndex = index;
    });
    unawaited(HapticFeedback.selectionClick());
    widget.onLetterSelected(widget.letters[index]);
  }

  void _release() {
    if (_touched == null) return;
    unawaited(_bubble.reverse());
    setState(() => _touched = null);
  }

  @override
  void didUpdateWidget(covariant AlphabetIndexBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 检索改变分组时字母会变少，序号夹回范围内。
    final last = widget.letters.length - 1;
    if (_bubbleIndex > last) _bubbleIndex = math.max(last, 0);
    if ((_touched ?? 0) > last) {
      _touched = null;
      unawaited(_bubble.reverse());
    }
  }

  @override
  Widget build(BuildContext context) {
    final letters = widget.letters;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final height = constraints.maxHeight;
        final count = letters.length;
        final slot = count == 0
            ? 0.0
            : math.min(AlphabetIndexBar.maxSlotExtent, height / count);
        if (count == 0 || slot < AlphabetIndexBar.minSlotExtent) {
          return const SizedBox.shrink();
        }
        final top = (height - slot * count) / 2;
        int indexAt(double dy) =>
            ((dy - top) / slot).floor().clamp(0, count - 1).toInt();
        final touching = _touched != null;
        final fade = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
        // 气泡转了 45°，上下各比布局框多出 (√2 − 1) / 2 个边长；夹在范围
        // 内时把这部分算上，靠近两端时尖角不会被列表区域裁掉。
        const bubble = AlphabetIndexBar._bubbleSize;
        const overhang = bubble * (math.sqrt2 - 1) / 2;
        final bubbleTop = (top + (_bubbleIndex + 0.5) * slot - bubble / 2)
            .clamp(overhang, math.max(overhang, height - bubble - overhang))
            .toDouble();
        // 格高只有约 20dp，系统默认的 18dp 拖动阈值几乎是一整格：手指滑到
        // 下一个字母前都不会更新。这里把阈值收到 [_touchSlop]，同时也让索引条
        // 比外层面板的拖动更早赢得手势竞争。
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            gestureSettings: DeviceGestureSettings(
              touchSlop: AlphabetIndexBar._touchSlop,
            ),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // 按下即跳（不等越过拖动阈值），轻点一个字母同样生效；越过阈值
            // 那一下的位移只在 onStart 里给出。
            onVerticalDragDown: (details) =>
                _touch(indexAt(details.localPosition.dy)),
            onVerticalDragStart: (details) =>
                _touch(indexAt(details.localPosition.dy)),
            onVerticalDragUpdate: (details) =>
                _touch(indexAt(details.localPosition.dy)),
            onVerticalDragEnd: (_) => _release(),
            onVerticalDragCancel: _release,
            child: Stack(
              // 气泡画在索引条左侧、自身范围之外。
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned(
                  left: 0,
                  right: 0,
                  top: top - 4,
                  height: slot * count + 8,
                  child: AnimatedOpacity(
                    opacity: touching ? 1 : 0,
                    duration: fade,
                    curve: touching
                        ? ExpressiveMotion.effects
                        : ExpressiveMotion.exit,
                    // 胶囊底跟随“控件”材质（只换填充，不加描边）；没有模糊，
                    // 放在 AnimatedOpacity 里淡入无妨。
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color:
                            AppGlassField.of(context)?.fill ??
                            Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(
                          AlphabetIndexBar.width / 2,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: top,
                  child: ValueListenableBuilder<String?>(
                    valueListenable: widget.activeLetter,
                    builder: (BuildContext context, String? active, _) =>
                        Column(
                          children: <Widget>[
                            for (var i = 0; i < count; i++)
                              _IndexLetter(
                                letter: letters[i],
                                extent: slot,
                                highlighted: touching
                                    ? i == _touched
                                    : letters[i] == active,
                                onSelected: () =>
                                    widget.onLetterSelected(letters[i]),
                              ),
                          ],
                        ),
                  ),
                ),
                Positioned(
                  right: AlphabetIndexBar.width + AlphabetIndexBar._bubbleGap,
                  top: bubbleTop,
                  child: AnimatedBuilder(
                    animation: _bubble,
                    builder: (BuildContext context, Widget? _) =>
                        _bubble.isDismissed
                        ? const SizedBox.shrink()
                        : IgnorePointer(
                            child: FadeTransition(
                              opacity: _bubbleOpacity,
                              child: ScaleTransition(
                                scale: _bubbleScale,
                                alignment: Alignment.centerRight,
                                child: _IndexBubble(
                                  letter:
                                      letters[_bubbleIndex.clamp(0, count - 1)],
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 索引条上的一个字母；高亮时衬 `primary` 圆底（经 [ExpressiveStateBlend]
/// 补间）。读屏上是一个可点的按钮。
class _IndexLetter extends StatelessWidget {
  const _IndexLetter({
    required this.letter,
    required this.extent,
    required this.highlighted,
    required this.onSelected,
  });

  final String letter;
  final double extent;
  final bool highlighted;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dot = math.min(extent, 18.0);
    final fontSize = (extent * 0.58).clamp(9.0, 11.0).toDouble();
    return MergeSemantics(
      child: Semantics(
        button: true,
        onTap: onSelected,
        child: SizedBox(
          height: extent,
          child: Center(
            child: ExpressiveStateBlend(
              active: highlighted,
              builder: (BuildContext context, double t, Widget? _) => Container(
                width: dot,
                height: dot,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: t),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  letter,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: Color.lerp(
                      colorScheme.onSurfaceVariant,
                      colorScheme.onPrimary,
                      t,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 按住时的放大气泡：水滴形（尖角指向索引条），`primaryContainer` 底。
class _IndexBubble extends StatelessWidget {
  const _IndexBubble({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const size = AlphabetIndexBar._bubbleSize;
    // 三个圆角 + 一个直角的方块转 -45°，直角就指向右侧的索引条；字再
    // 转回来保持正立。
    return ExcludeSemantics(
      child: Transform.rotate(
        angle: -math.pi / 4,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(size / 2),
              topRight: Radius.circular(size / 2),
              bottomLeft: Radius.circular(size / 2),
            ),
          ),
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Text(
              letter,
              textScaler: TextScaler.noScaling,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
