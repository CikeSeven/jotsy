import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/expressive_state_blend.dart';

/// 长按生效时回调：按下的指针 id、长按位置（全局坐标）。拖动随后由
/// `DiaryBlockHandleLayer` 经全局指针路由跟踪，与把手是否还在树上无关。
typedef DiaryBlockDragStart = void Function(int pointer, Offset position);

/// 把手的可见尺寸：竖向小胶囊，宽 16 正好放进 16dp 的页面左边距。
const double diaryBlockHandleWidth = 16;
const double diaryBlockHandleHeight = 26;

/// 把手点阵图标的字号。
const double _gripSize = 11;

/// Font Awesome 的点阵字形在它的行框里偏下 0.034em（11dp 时实测墨迹比行框
/// 中线低 0.375dp）。按行框居中后点阵整体比胶囊中线低，手机上差 1 个多物理
/// 像素就能看出和首行文字没对齐；上移这么多，点阵中线才落在把手中线上。
const double _gripInkDrop = _gripSize * 0.034;

/// 触控区域比可见尺寸大：左侧外扩 8dp、上下各 4dp；右侧只外扩 2dp——再多
/// 就压住正文开头，点行首放光标会误触把手。
const EdgeInsets diaryBlockHandleHitSlop = EdgeInsets.fromLTRB(8, 4, 2, 4);

/// 段落把手本体。
///
/// - 轻点：进入段落选择模式并选中这一块（[onTap]，见 `DiaryBlockSelection`）；
///   底部工具栏换成段落操作栏，上移 / 下移可以连点，点别的段落可以多选。
/// - 长按：开始拖动这一块，把手跟着手指走（[onDragStart]）。
class DiaryBlockHandle extends StatelessWidget {
  const DiaryBlockHandle({
    super.key,
    required this.dragging,
    required this.onTap,
    required this.onDragStart,
  });

  final bool dragging;
  final VoidCallback onTap;
  final DiaryBlockDragStart onDragStart;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final fast = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: fast,
      curve: ExpressiveMotion.effects,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: Semantics(
        button: true,
        label: context.l10n.diaryEditorBlockHandle,
        onTap: onTap,
        excludeSemantics: true,
        child: _LongPressDragStarter(
          onTap: onTap,
          onDragStart: onDragStart,
          child: Padding(
            padding: diaryBlockHandleHitSlop,
            child: ExpressiveStateBlend(
              active: dragging,
              builder: (context, t, _) => Container(
                width: diaryBlockHandleWidth,
                height: diaryBlockHandleHeight,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer.withValues(alpha: t),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Transform.translate(
                  offset: const Offset(0, -_gripInkDrop),
                  child: FaIcon(
                    FontAwesomeIcons.gripVertical,
                    size: _gripSize,
                    color: Color.lerp(
                      colors.onSurfaceVariant.withValues(alpha: 0.65),
                      colors.onSecondaryContainer,
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

/// 长按（系统长按时限）后交出指针 id 与位置。[GestureDetector] 的长按回调
/// 不带指针 id，这里在按下时记下；轻点交给 [onTap]（长按生效前手指一动，
/// 竖向拖动就交给外层滚动）。
class _LongPressDragStarter extends StatefulWidget {
  const _LongPressDragStarter({
    required this.onDragStart,
    required this.onTap,
    required this.child,
  });

  final DiaryBlockDragStart onDragStart;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_LongPressDragStarter> createState() => _LongPressDragStarterState();
}

class _LongPressDragStarterState extends State<_LongPressDragStarter> {
  int? _pointer;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) => _pointer = event.pointer,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPressStart: (details) {
        final pointer = _pointer;
        if (pointer != null) {
          widget.onDragStart(pointer, details.globalPosition);
        }
      },
      child: widget.child,
    ),
  );
}
