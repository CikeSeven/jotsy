import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../app_surface/widgets/app_page_backdrop.dart';

/// 列表类二级页（归档、回收站等）的空状态：居中的语义图标 + 说明文案。
///
/// 与日记首页空态保持同一视觉语言（38dp secondary 图标、onSurfaceVariant
/// 文案），替代此前仅一行纯文本的空态。
class EmptyHint extends StatelessWidget {
  const EmptyHint({super.key, required this.icon, required this.message});

  final FaIconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // 空状态直接画在页面背景上：有背景图时图标与文字经同一可读性兜底。
    final iconStyle = AppPageBackdrop.onBackgroundTextStyle(
      context,
      TextStyle(color: colorScheme.secondary),
    );
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FaIcon(
              icon,
              size: 38,
              color: iconStyle?.color,
              shadows: iconStyle?.shadows,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppPageBackdrop.onBackgroundTextStyle(
                context,
                Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
