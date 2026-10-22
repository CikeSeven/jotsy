import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../widgets/expressive_menu/expressive_menu.dart';
import '../../../widgets/expressive_state_blend.dart';
import '../../controllers/diary_block_reorder.dart';
import '../../controllers/diary_editor_controller.dart';

/// 每个原生块都经过此代理，嵌套块也能拖动；底层节点的 selectable key 保留
/// 在原组件上，外层把手和落点不会改变文字的几何或输入偏移。
class DiaryDraggableBlockBuilder extends af.BlockComponentBuilder {
  DiaryDraggableBlockBuilder(this.delegate, this.controller);
  final af.BlockComponentBuilder delegate;
  final DiaryEditorController controller;
  @override
  af.BlockComponentValidate get validate => delegate.validate;
  @override
  af.BlockComponentWidget build(af.BlockComponentContext context) =>
      _DraggableBlock(
        node: context.node,
        controller: controller,
        child: delegate.build(context) as Widget,
      );
}

class _DraggableBlock extends af.BlockComponentStatelessWidget {
  const _DraggableBlock({
    required super.node,
    required this.controller,
    required this.child,
  }) : super(configuration: const af.BlockComponentConfiguration());
  final DiaryEditorController controller;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      DiaryBlockDragHandle(node: node, controller: controller, child: child);
}

class DiaryBlockDragHandle extends StatefulWidget {
  const DiaryBlockDragHandle({
    super.key,
    required this.node,
    required this.controller,
    required this.child,
  });
  final af.Node node;
  final DiaryEditorController controller;
  final Widget child;
  @override
  State<DiaryBlockDragHandle> createState() => _DiaryBlockDragHandleState();
}

class _DiaryBlockDragHandleState extends State<DiaryBlockDragHandle> {
  bool _after = false;
  bool _dragging = false;
  bool _accepts(af.Node source) =>
      source != widget.node && !source.isParentOf(widget.node);
  void _position(Offset global) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final after = box.globalToLocal(global).dy >= box.size.height / 2;
    if (_after != after) setState(() => _after = after);
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    final state = widget.controller.state;
    final colors = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return DragTarget<af.Node>(
      onWillAcceptWithDetails: (details) => _accepts(details.data),
      onMove: (details) => _position(details.offset),
      onAcceptWithDetails: (details) {
        _position(details.offset);
        if (moveDiaryEditorBlock(
          widget.controller,
          details.data,
          _after ? node.path.next : node.path,
        )) {
          HapticFeedback.lightImpact();
        }
      },
      builder: (context, candidates, rejected) => Stack(
        clipBehavior: Clip.none,
        children: [
          // 把手必须处于父块的命中范围内：画在负边距里虽然能看到，Flutter
          // 仍不会把范围外的指针交给它。编辑态用独立沟槽，正文选区几何仍
          // 由原生块自身计算，阅读态没有这个沟槽。
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 24),
            child: Opacity(opacity: _dragging ? 0.35 : 1, child: widget.child),
          ),
          Positioned(
            left: 0,
            top: 0,
            child: SizedBox(
              width: 24,
              height: 34,
              child: LongPressDraggable<af.Node>(
                data: node,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                hapticFeedbackOnStart: false,
                onDragStarted: () {
                  setState(() => _dragging = true);
                  HapticFeedback.mediumImpact();
                },
                onDragUpdate: (details) => state.scrollService?.startAutoScroll(
                  details.globalPosition,
                ),
                onDragEnd: (_) {
                  state.scrollService?.stopAutoScroll();
                  if (mounted) setState(() => _dragging = false);
                },
                feedback: Material(
                  elevation: 6,
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 220,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        node.delta?.toPlainText().trim().isNotEmpty == true
                            ? node.delta!.toPlainText()
                            : l10n.diaryEditorDragBlock,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
                // Tooltip 默认也识别长按，会在拖动识别器之前赢得手势。
                // 保留辅助说明和桌面悬停，把触屏长按完整交给拖动。
                child: TooltipTheme(
                  data: const TooltipThemeData(
                    triggerMode: TooltipTriggerMode.manual,
                  ),
                  child: ExpressiveMenuButton(
                    tooltip: l10n.diaryEditorDragBlock,
                    icon: FaIcon(
                      FontAwesomeIcons.gripVertical,
                      size: 11,
                      color: colors.onSurfaceVariant,
                    ),
                    items: [
                      ExpressiveMenuItem(
                        onPressed: node.previous == null
                            ? null
                            : () => moveDiaryEditorBlock(
                                widget.controller,
                                node,
                                node.previous!.path,
                              ),
                        leadingIcon: const FaIcon(FontAwesomeIcons.angleUp),
                        child: Text(l10n.diaryEditorMoveBlockUp),
                      ),
                      ExpressiveMenuItem(
                        onPressed: node.next == null
                            ? null
                            : () => moveDiaryEditorBlock(
                                widget.controller,
                                node,
                                node.next!.path.next,
                              ),
                        leadingIcon: const FaIcon(FontAwesomeIcons.angleDown),
                        child: Text(l10n.diaryEditorMoveBlockDown),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: _after ? null : 0,
            bottom: _after ? 0 : null,
            child: IgnorePointer(
              child: ExpressiveStateBlend(
                active: candidates.isNotEmpty,
                builder: (context, t, _) => Container(
                  height: 2,
                  color: colors.primary.withValues(alpha: t),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
