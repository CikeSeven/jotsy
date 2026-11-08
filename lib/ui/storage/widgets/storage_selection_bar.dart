import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/form_width.dart';
import '../../widgets/width_layout_builder.dart';

/// 媒体页有勾选时从底部升起的操作栏：上面一行“已选 N 项 · 共 X”，下面
/// “压缩”（[onCompress] 为 null 时不出现：平台不支持或选中项都不能压）与
/// error 系的“删除”。升降动画与回收站的操作栏一致（放在 body 的 Column
/// 里，列表随之让位）。
class StorageSelectionBar extends StatelessWidget {
  const StorageSelectionBar({
    super.key,
    required this.visible,
    required this.count,
    required this.bytes,
    required this.onCompress,
    required this.onDelete,
  });

  final bool visible;
  final int count;
  final int bytes;
  final VoidCallback? onCompress;
  final VoidCallback? onDelete;

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
              key: const ValueKey<String>('storage_bar'),
              count: count,
              bytes: bytes,
              onCompress: onCompress,
              onDelete: onDelete,
            )
          : const SizedBox(
              key: ValueKey<String>('storage_bar_hidden'),
              width: double.infinity,
            ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    super.key,
    required this.count,
    required this.bytes,
    required this.onCompress,
    required this.onDelete,
  });

  final int count;
  final int bytes;
  final VoidCallback? onCompress;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final onCompress = this.onCompress;
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: WidthLayoutBuilder(
          builder: (BuildContext context, double width) => Padding(
            padding: EdgeInsets.symmetric(
              horizontal: FormWidth.gutter(width),
              vertical: AppSpacing.m,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l10n.storageMgmtSelectionSummary(
                    count,
                    l10n.formatByteSize(bytes),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Row(
                  children: <Widget>[
                    if (onCompress != null) ...<Widget>[
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: onCompress,
                          style: AppGlassField.tonalButtonStyle(context),
                          icon: const FaIcon(
                            FontAwesomeIcons.compress,
                            size: 14,
                          ),
                          label: Text(l10n.storageMgmtCompress),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.m),
                    ],
                    Expanded(
                      child: FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.errorContainer,
                          foregroundColor: scheme.onErrorContainer,
                        ),
                        onPressed: onDelete,
                        icon: const FaIcon(FontAwesomeIcons.trashCan, size: 14),
                        label: Text(l10n.commonDelete),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
