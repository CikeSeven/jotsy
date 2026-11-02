import 'package:flutter/material.dart';

/// 人设的表情头像（圆形、次要容器色底）。
class AiPersonaAvatar extends StatelessWidget {
  const AiPersonaAvatar({super.key, required this.emoji, this.size = 36});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.5, height: 1)),
    );
  }
}
