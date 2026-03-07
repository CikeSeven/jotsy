import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';

/// 列表项左滑/右滑手势后的操作背景层。
///
/// 该组件只负责动作背景的视觉呈现（图标 + 文本 + 颜色），
/// 不处理任何手势逻辑，手势由上层 `Dismissible` 管理。
class SwipeActionBackground extends StatelessWidget {
  const SwipeActionBackground({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    this.horizontalMargin = AppSpacing.m,
  });

  final String label;
  final IconData icon;
  final Color color;
  final double horizontalMargin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
