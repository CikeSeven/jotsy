import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/widgets/home_hint_visibility_scope.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';
import '../../../widgets/expressive_state_blend.dart';
import '../../controllers/diary_block_reorder.dart';
import '../../controllers/diary_editor_controller.dart';

/// 长按生效时回调：按下的指针 id、长按位置（全局坐标）；从菜单里的
/// “长按拖动”发起时另给这一项的全局矩形，跟手的拖动条（[DiaryBlockDragChip]）
/// 从这里接过它。拖动随后由 `DiaryBlockHandleLayer` 经全局指针路由跟踪，
/// 与发起它的组件是否还在树上无关。
typedef DiaryBlockDragStart =
    void Function(int pointer, Offset position, {Rect? menuItem});

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
/// - 轻点：Expressive 菜单，依次为上移 / 长按拖动 / 下移（相邻位置，缩进
///   层级不变，见 [_StepMenuItem]）。
/// - 长按把手：开始拖动，把手跟着手指走。
/// - 在菜单里长按“长按拖动”：菜单收起（上移 / 下移随之消失），这一项变成
///   跟手的拖动条留在手指下（由把手层画），把手本身隐去（[hidden]）——
///   手里只拿着一样东西。轻点这一项只提示用法，并告诉用户也可以直接长按
///   把手。
class DiaryBlockHandle extends StatelessWidget {
  const DiaryBlockHandle({
    super.key,
    required this.node,
    required this.controller,
    required this.dragging,
    required this.onDragStart,
    this.hidden = false,
  });

  final af.Node node;
  final DiaryEditorController controller;
  final bool dragging;
  final DiaryBlockDragStart onDragStart;

  /// 从菜单发起的拖动中：淡出、不接收点按。仍留在树上，正在收起的菜单
  /// 以它为锚点。
  final bool hidden;

  void _showDragTip(BuildContext context) {
    if (!context.mounted) return;
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(content: Text(context.l10n.diaryEditorDragBlockTip)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final fast = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: fast,
      curve: ExpressiveMotion.effects,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: IgnorePointer(
        ignoring: hidden,
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: fast,
          curve: ExpressiveMotion.effects,
          child: ExpressiveMenuAnchor(
            placement: ExpressiveMenuPlacement.start,
            menuChildren: [
              _StepMenuItem(node: node, controller: controller, up: true),
              _DragMenuItem(
                onDragStart: onDragStart,
                // 提示挂在把手的 context 上：菜单项随菜单收起而卸载。
                onTap: () => _showDragTip(context),
              ),
              _StepMenuItem(node: node, controller: controller, up: false),
            ],
            builder: (context, menu, _) => Semantics(
              button: true,
              label: l10n.diaryEditorDragBlock,
              onTap: menu.toggle,
              excludeSemantics: true,
              child: _LongPressDragStarter(
                onTap: menu.toggle,
                onDragStart: (pointer, position) {
                  // 菜单开着时直接长按把手：收起菜单，只拖把手。
                  if (menu.isExpanded) menu.close();
                  onDragStart(pointer, position);
                },
                child: Padding(
                  padding: diaryBlockHandleHitSlop,
                  child: ExpressiveStateBlend(
                    active: menu.isExpanded || dragging,
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
          ),
        ),
      ),
    );
  }
}

/// 上移 / 下移一格，缩进层级不变（[DiaryBlockGaps.step]）：子块可以移出
/// 父块，接到相邻块的子块里；朝那个方向没有放得下这一层级的位置时禁用。
/// 随文档变化重算是否可用——菜单开着时把手不一定重建。
class _StepMenuItem extends StatelessWidget {
  const _StepMenuItem({
    required this.node,
    required this.controller,
    required this.up,
  });

  final af.Node node;
  final DiaryEditorController controller;
  final bool up;

  af.Path? _destination() => node.parent == null
      ? null
      : DiaryBlockGaps(controller.document.root, node).step(up: up);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => ExpressiveMenuItem(
      onPressed: _destination() == null
          ? null
          : () {
              final destination = _destination();
              if (destination != null) {
                moveDiaryEditorBlock(controller, node, destination);
              }
            },
      leadingIcon: _menuIcon(
        up ? FontAwesomeIcons.angleUp : FontAwesomeIcons.angleDown,
      ),
      child: Text(
        up
            ? context.l10n.diaryEditorMoveBlockUp
            : context.l10n.diaryEditorMoveBlockDown,
      ),
    ),
  );
}

/// 菜单前置图标占固定 16dp 宽：Font Awesome 按字形宽度绘制，点阵比箭头
/// 窄，不固定的话三行文字的起点会错开。
Widget _menuIcon(FaIconData icon) => SizedBox(
  width: ExpressiveMenuItem.iconSize,
  child: Center(child: FaIcon(icon)),
);

/// “长按拖动”这一项的样子：菜单里与跟手的拖动条共用。[held] 时一直保持
/// 按下的叠色与收紧的圆角（长按胜出后水波纹的按下态随点按手势一起取消，
/// 这里接着画）。
Widget _dragItem(
  BuildContext context, {
  required bool held,
  required VoidCallback onPressed,
}) {
  final colors = Theme.of(context).colorScheme;
  return ExpressiveMenuItem(
    onPressed: onPressed,
    leadingIcon: _menuIcon(FontAwesomeIcons.gripVertical),
    style: held
        ? ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(
              colors.primary.withValues(alpha: 0.12),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  ExpressiveMenuItem.pressedRadius,
                ),
              ),
            ),
          )
        : null,
    child: Text(context.l10n.diaryEditorDragBlockHold),
  );
}

/// 菜单里的“长按拖动”。长按生效时收起菜单，并把这一项的全局矩形交给
/// [onDragStart]：把手层在同一位置画出跟手的拖动条，菜单淡出时它留在
/// 手指下。轻点由菜单项照常收起菜单，再执行 [onTap]。
class _DragMenuItem extends StatelessWidget {
  const _DragMenuItem({required this.onDragStart, required this.onTap});

  final DiaryBlockDragStart onDragStart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => _LongPressDragStarter(
    onDragStart: (pointer, position) {
      final box = context.findRenderObject();
      final rect = box is RenderBox && box.hasSize
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      ExpressiveMenuAnchorState.maybeOf(context)?.close();
      onDragStart(pointer, position, menuItem: rect);
    },
    child: _dragItem(context, held: false, onPressed: onTap),
  );
}

/// 从菜单拖动时跟着手指的“长按拖动”：菜单收起后只剩这一项，带着菜单的
/// 玻璃表面（内边距与菜单面板相同，8dp）浮在手指下，保持按下的样子。
/// [reveal] 驱动表面与内容的显隐（松手后淡出）；玻璃不能放进透明度层。
class DiaryBlockDragChip extends StatelessWidget {
  const DiaryBlockDragChip({
    super.key,
    required this.width,
    required this.reveal,
  });

  /// 与菜单面板相同的内边距：拖动条的内容与菜单里那一项重合。
  static const double padding = 8;

  /// 菜单项的宽度。
  final double width;
  final Animation<double> reveal;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: ExpressiveMenuSurface(
        reveal: reveal,
        child: Padding(
          padding: const EdgeInsets.all(padding),
          child: SizedBox(
            width: width,
            child: _dragItem(context, held: true, onPressed: () {}),
          ),
        ),
      ),
    ),
  );
}

/// 长按（系统长按时限）后交出指针 id 与位置。[GestureDetector] 的长按回调
/// 不带指针 id，这里在按下时记下；轻点照常交给 [onTap] 或子组件自己的点按
/// （长按生效前手指一动，竖向拖动就交给外层滚动）。
class _LongPressDragStarter extends StatefulWidget {
  const _LongPressDragStarter({
    required this.onDragStart,
    required this.child,
    this.onTap,
  });

  final void Function(int pointer, Offset position) onDragStart;
  final VoidCallback? onTap;
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
