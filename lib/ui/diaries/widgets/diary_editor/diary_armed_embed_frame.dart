import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../../../app/theme/expressive_motion.dart';
import '../../controllers/diary_embed_editing.dart';

/// 包住嵌入块（图片、视频、音频、附件、分隔线、日记卡片）原有的渲染器：
/// 退格 / Delete 把它选中时（[DiaryArmedEmbed]，插入点仍在旁边那行）在块上
/// 叠一层选中样式，再按一次即删除。只在可编辑的正文里装（只读正文从不
/// 选中）。原渲染器的组件、校验与起止位置原样保留，块组件仍带 `node.key`，
/// 选区与段落把手照常找到它。
class DiaryArmedEmbedBuilder extends af.BlockComponentBuilder {
  DiaryArmedEmbedBuilder(this.delegate, this.state)
    : super(configuration: delegate.configuration) {
    validate = delegate.validate;
    showActions = delegate.showActions;
    actionBuilder = delegate.actionBuilder;
    actionTrailingBuilder = delegate.actionTrailingBuilder;
  }

  final af.BlockComponentBuilder delegate;
  final af.EditorState state;

  @override
  af.Position start(af.Node node) => delegate.start(node);

  @override
  af.Position end(af.Node node) => delegate.end(node);

  @override
  af.BlockComponentWidget build(af.BlockComponentContext context) =>
      _ArmedEmbedFrame(
        node: context.node,
        armed: DiaryArmedEmbed.of(state).node,
        child: delegate.build(context) as Widget,
      );
}

class _ArmedEmbedFrame extends af.BlockComponentStatelessWidget {
  const _ArmedEmbedFrame({
    required super.node,
    required this.armed,
    required this.child,
  }) : super(configuration: const af.BlockComponentConfiguration());

  final ValueListenable<af.Node?> armed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // 选中样式与上游块选区同一底色（主色 20%），外加 2dp 主色描边，在图片
    // 这类本身有颜色的块上也认得出来；不拦截点按。
    final overlay = IgnorePointer(
      child: DecoratedBox(
        key: ValueKey('diary-armed-embed-${node.id}'),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.2),
          border: Border.all(color: colors.primary, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: ValueListenableBuilder<af.Node?>(
            valueListenable: armed,
            builder: (context, value, overlay) => AnimatedOpacity(
              opacity: identical(value, node) ? 1 : 0,
              duration: ExpressiveMotion.duration(
                context,
                ExpressiveMotion.fast,
              ),
              curve: ExpressiveMotion.effects,
              child: overlay,
            ),
            child: overlay,
          ),
        ),
      ],
    );
  }
}
