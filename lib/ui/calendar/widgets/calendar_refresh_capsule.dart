import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../widgets/delayed_loading_gate.dart';
import '../../widgets/expressive_loading_indicator.dart';

/// 日历卡片右上角的刷新/错误胶囊。
///
/// 输入：月份打点是否在加载、加载错误；无副作用。
///
/// 翻月后 family provider 换 key，首帧必为 loading；本地查询通常几毫秒即
/// 返回，经 [DelayedLoadingGate] 延迟显示加载胶囊，避免每次翻月都闪一下。
/// 错误态立即显示。
class CalendarRefreshCapsule extends StatelessWidget {
  const CalendarRefreshCapsule({
    super.key,
    required this.loading,
    required this.error,
  });

  static const double _indicatorSize = 18;

  final bool loading;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    return DelayedLoadingGate(
      loading: loading,
      builder: (BuildContext context, bool showLoading) =>
          _buildCapsule(context, showLoading: showLoading),
    );
  }

  Widget _buildCapsule(BuildContext context, {required bool showLoading}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final error = this.error;
    final showOverlay = showLoading || error != null;
    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      child: showOverlay
          ? DecoratedBox(
              key: ValueKey<Object>(error ?? 'loading'),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (showLoading)
                      const ExpressiveLoadingIndicator(size: _indicatorSize),
                    if (error != null) ...<Widget>[
                      FaIcon(
                        FontAwesomeIcons.circleInfo,
                        size: _indicatorSize,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 190),
                        child: Text(
                          context.l10n.autoT0210(error.toString()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          : const SizedBox.shrink(key: ValueKey<String>('idle')),
    );
  }
}
