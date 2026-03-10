import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';

/// 应用启动加载页。
///
/// 使用 Material 3 Expressive 风格的 loading 动画，作为进入首页前的统一等待界面。
class AppLoadingPage extends StatelessWidget {
  const AppLoadingPage({super.key, this.message = '正在加载...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LoadingIndicatorM3E(
              variant: LoadingIndicatorM3EVariant.contained,
              constraints: const BoxConstraints.tightFor(
                width: 72,
                height: 72,
              ),
              semanticLabel: '应用加载中',
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
