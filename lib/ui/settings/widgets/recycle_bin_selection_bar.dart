import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';

/// 回收站有勾选时从底部升起的操作栏：“恢复”与 `error` 系的“彻底删除”两个
/// 等宽按钮，`surfaceContainer` 底。
///
/// 出现时高度从 0 展开、内容贴顶随上缘一起升起并淡入，消失时反向收起；
/// 列表随之平滑让位（放在 body 的 Column 里，而不是 Scaffold 底栏槽位：
/// 槽位常驻会让 body 失去底部安全区）。离场的仍是旧按钮，收起途中不会闪成
/// 停用态。减少动画时直接出现 / 消失。
class RecycleBinSelectionBar extends StatelessWidget {
  const RecycleBinSelectionBar({
    super.key,
    required this.visible,
    required this.onRestore,
    required this.onPurge,
  });

  final bool visible;

  /// 为 null 时按钮停用（正在提交）。
  final VoidCallback? onRestore;
  final VoidCallback? onPurge;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      switchInCurve: ExpressiveMotion.effects,
      switchOutCurve: ExpressiveMotion.exit,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: child,
          ),
        );
      },
      child: visible
          ? _Bar(
              key: const ValueKey<String>('recycle_bar'),
              onRestore: onRestore,
              onPurge: onPurge,
            )
          : const SizedBox(
              key: ValueKey<String>('recycle_bar_hidden'),
              width: double.infinity,
            ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({super.key, required this.onRestore, required this.onPurge});

  final VoidCallback? onRestore;
  final VoidCallback? onPurge;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.l,
            vertical: AppSpacing.m,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: onRestore,
                  icon: const FaIcon(
                    FontAwesomeIcons.arrowRotateLeft,
                    size: 14,
                  ),
                  label: Text(l10n.autoT0030),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: scheme.errorContainer,
                    foregroundColor: scheme.onErrorContainer,
                  ),
                  onPressed: onPurge,
                  icon: const FaIcon(FontAwesomeIcons.trashCan, size: 14),
                  label: Text(l10n.autoT0028),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
