import 'package:flutter/material.dart';

/// 三竖线拖拽手柄（替代默认双竖线图标）。放在 `ReorderableDragStartListener` 里使用，
/// 设置页的工具栏排序与卡片区块排序共用。
class TripleBarDragHandle extends StatelessWidget {
  const TripleBarDragHandle({super.key});

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
