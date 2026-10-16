import 'package:flutter/material.dart';
import 'package:node_diary/ui/widgets/delayed_loading_gate.dart';
import 'package:node_diary/ui/widgets/expressive_icon_swap.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

import 'publish_panel_tile.dart';

/// “此时此地”里的一行：前置图标 + 可手填的输入框 + 右侧自动获取按钮。
///
/// 地点与天气共用。按钮在请求开始时立即禁用防止连点；请求超过
/// [DelayedLoadingGate.defaultDelay] 才把图标换成加载指示器，命中缓存的
/// 快速返回不会闪一下转圈，切换本身经 [ExpressiveIconSwap] 过渡。
class PublishResolvableField extends StatelessWidget {
  const PublishResolvableField({
    super.key,
    required this.leading,
    required this.controller,
    required this.hintText,
    required this.resolveTooltip,
    required this.resolveIcon,
    required this.resolving,
    required this.onResolve,
    this.leadingGap = 12,
  });

  final Widget leading;
  final TextEditingController controller;
  final String hintText;
  final String resolveTooltip;
  final Widget resolveIcon;
  final bool resolving;
  final VoidCallback? onResolve;
  final double leadingGap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PublishPanelTile(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
      child: Row(
        children: <Widget>[
          leading,
          SizedBox(width: leadingGap),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 1,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.75,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: resolving ? null : onResolve,
            tooltip: resolveTooltip,
            visualDensity: VisualDensity.compact,
            icon: DelayedLoadingGate(
              loading: resolving,
              builder: (BuildContext context, bool showLoading) =>
                  ExpressiveIconSwap(
                    switchKey: showLoading,
                    child: showLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: ExpressiveLoadingIndicator(),
                          )
                        : resolveIcon,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
