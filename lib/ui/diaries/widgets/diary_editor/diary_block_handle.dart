import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../app/theme/app_effects.dart';
import '../../../../app/theme/expressive_motion.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/widgets/home_hint_visibility_scope.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';
import '../../../widgets/expressive_state_blend.dart';
import '../../controllers/diary_block_reorder.dart';
import '../../controllers/diary_editor_controller.dart';

/// 长按生效时回调：按下的指针 id 与长按位置（全局坐标）。拖动随后由
/// `DiaryBlockHandleLayer` 经全局指针路由跟踪，与发起它的组件是否还在
/// 树上无关。
typedef DiaryBlockDragStart = void Function(int pointer, Offset position);

/// 把手的可见尺寸：竖向小胶囊，宽 16 正好放进 16dp 的页面左边距。
const double diaryBlockHandleWidth = 16;
const double diaryBlockHandleHeight = 26;

/// 触控区域比可见尺寸大：左侧外扩 8dp、上下各 4dp；右侧只外扩 2dp——再多
/// 就压住正文开头，点行首放光标会误触把手。
const EdgeInsets diaryBlockHandleHitSlop = EdgeInsets.fromLTRB(8, 4, 2, 4);

/// 段落把手本体。
///
/// - 轻点：Expressive 菜单，依次为上移 / 拖动段落 / 下移（同级相邻位置）。
/// - 长按把手，或在菜单里长按“拖动段落”：开始拖动。菜单项在长按生效时
///   先收起菜单再交给 [onDragStart]；轻点它只提示“长按后拖动”，并告诉用户
///   也可以直接长按把手。
class DiaryBlockHandle extends StatelessWidget {
  const DiaryBlockHandle({
    super.key,
    required this.node,
    required this.controller,
    required this.dragging,
    required this.onDragStart,
  });

  final af.Node node;
  final DiaryEditorController controller;
  final bool dragging;
  final DiaryBlockDragStart onDragStart;

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
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      curve: ExpressiveMotion.effects,
      builder: (context, t, child) => Opacity(opacity: t, child: child),
      child: ExpressiveMenuAnchor(
        placement: ExpressiveMenuPlacement.start,
        menuChildren: [
          ExpressiveMenuItem(
            onPressed: node.previous == null
                ? null
                : () => moveDiaryEditorBlock(
                    controller,
                    node,
                    node.previous!.path,
                  ),
            leadingIcon: _menuIcon(FontAwesomeIcons.angleUp),
            child: Text(l10n.diaryEditorMoveBlockUp),
          ),
          _DragMenuItem(
            onDragStart: onDragStart,
            // 提示挂在把手的 context 上：菜单项随菜单收起而卸载。
            onTap: () => _showDragTip(context),
          ),
          ExpressiveMenuItem(
            onPressed: node.next == null
                ? null
                : () => moveDiaryEditorBlock(
                    controller,
                    node,
                    node.next!.path.next,
                  ),
            leadingIcon: _menuIcon(FontAwesomeIcons.angleDown),
            child: Text(l10n.diaryEditorMoveBlockDown),
          ),
        ],
        builder: (context, menu, _) => Semantics(
          button: true,
          label: l10n.diaryEditorDragBlock,
          onTap: menu.toggle,
          excludeSemantics: true,
          child: _LongPressDragStarter(
            onTap: menu.toggle,
            onDragStart: onDragStart,
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
                  child: FaIcon(
                    FontAwesomeIcons.gripVertical,
                    size: 11,
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

/// 菜单前置图标占固定 16dp 宽：Font Awesome 按字形宽度绘制，点阵比箭头
/// 窄，不固定的话三行文字的起点会错开。
Widget _menuIcon(FaIconData icon) => SizedBox(
  width: ExpressiveMenuItem.iconSize,
  child: Center(child: FaIcon(icon)),
);

/// 菜单里的“拖动段落”：行尾弱化的“长按”点明用法。长按生效时先收起菜单
/// 再开始拖动——这一项随菜单卸载，拖动本身不依赖它。轻点由菜单项照常收起
/// 菜单，再执行 [onTap]。
class _DragMenuItem extends StatelessWidget {
  const _DragMenuItem({required this.onDragStart, required this.onTap});

  final DiaryBlockDragStart onDragStart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return _LongPressDragStarter(
      onDragStart: (pointer, position) {
        ExpressiveMenuAnchorState.maybeOf(context)?.close();
        onDragStart(pointer, position);
      },
      child: ExpressiveMenuItem(
        onPressed: onTap,
        leadingIcon: _menuIcon(FontAwesomeIcons.gripVertical),
        trailingIcon: ExcludeSemantics(
          child: Text(
            l10n.diaryEditorDragBlockHold,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        child: Text(l10n.diaryEditorDragBlock),
      ),
    );
  }
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

  final DiaryBlockDragStart onDragStart;
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

/// 落点线：2dp 圆头横线，左端一个 6dp 圆点标出插入层级的起点。
class DiaryBlockDropLine extends StatelessWidget {
  const DiaryBlockDropLine({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ),
      Positioned(
        left: -3,
        top: -2,
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    ],
  );
}

/// 拖动中跟手的卡片：块的前两行文字（媒体等为“拖动段落”），浮动面板的
/// 表面与投影规格。
class DiaryBlockDragFeedback extends StatelessWidget {
  const DiaryBlockDragFeedback({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.5),
            width: 0.8,
          ),
          boxShadow: AppEffects.softShadow(colors),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              FontAwesomeIcons.gripVertical,
              size: 12,
              color: colors.primary,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
