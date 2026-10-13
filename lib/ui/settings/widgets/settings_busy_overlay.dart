import 'package:flutter/material.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../widgets/expressive_entrance.dart';
import '../../widgets/expressive_loading_indicator.dart';

/// 设置二级页（数据管理、WebDAV）耗时操作的全屏等待遮罩。
///
/// 输入：[message] 当前步骤文案，[semanticLabel] 读屏标签。需放在 Stack 中。
/// 插入时淡入（此前 `if (_busy)` 硬切，导入流程在多个步骤间切换时会闪）；
/// 页面返回拦截由宿主页的 PopScope 负责。
class SettingsBusyOverlay extends StatelessWidget {
  const SettingsBusyOverlay({
    super.key,
    required this.message,
    required this.semanticLabel,
  });

  final String message;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: ExpressiveEntrance(
        offset: Offset.zero,
        duration: ExpressiveMotion.fast,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.82),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ExpressiveLoadingIndicator(
                    size: 72,
                    semanticLabel: semanticLabel,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
