import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';

/// 标签管理列表的一行：色块 + 名称 + 删除 + 拖拽手柄。
///
/// 输入：[index] 为在可排序列表中的位置（拖拽手柄需要）；[dragEnabled] 为
/// false 时（该行正在收起删除）不能再被拿起。副作用：无，点击/删除交给回调。
/// 修改颜色后色块与“#”颜色随 fast 补间过渡，而不是硬切。
class TagManagementTile extends StatelessWidget {
  const TagManagementTile({
    super.key,
    required this.tag,
    required this.index,
    required this.deleteTooltip,
    required this.dragEnabled,
    required this.onEdit,
    required this.onDelete,
  });

  final Tag tag;
  final int index;
  final String deleteTooltip;
  final bool dragEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onEdit,
      leading: _TagSwatch(color: Color(tag.color)),
      title: Text(
        tag.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: deleteTooltip,
            onPressed: onDelete,
            icon: const FaIcon(FontAwesomeIcons.trashCan, size: 14),
          ),
          const SizedBox(width: 12),
          ReorderableDragStartListener(
            index: index,
            enabled: dragEnabled,
            child: const SizedBox(
              width: 44,
              height: 40,
              child: ColoredBox(
                color: Colors.transparent,
                child: Center(child: _TagDragHandle()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagSwatch extends StatelessWidget {
  const _TagSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      curve: ExpressiveMotion.effects,
      builder: (BuildContext context, Color? value, Widget? child) {
        final swatch = value ?? color;
        return Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: swatch.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: swatch.withValues(alpha: 0.4), width: 1),
          ),
          alignment: Alignment.center,
          child: Text(
            '#',
            style: TextStyle(
              color: swatch,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        );
      },
    );
  }
}

class _TagDragHandle extends StatelessWidget {
  const _TagDragHandle();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return SizedBox(
      width: 16,
      height: 18,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _buildBar(color),
          _buildBar(color),
          _buildBar(color),
        ],
      ),
    );
  }

  Widget _buildBar(Color color) {
    return Container(
      width: 2,
      height: 16,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(1.2),
      ),
    );
  }
}
