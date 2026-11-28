import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../settings/providers/app_features_provider.dart';
import '../../widgets/list_item_presence.dart';
import '../controllers/todo_focus_controller.dart';
import '../controllers/todo_navigation.dart';
import '../models/todo_focus_run.dart';
import '../providers/todo_providers.dart';
import '../viewmodels/todo_focus_format.dart';

/// 待办页顶上的专注胶囊：在计时（或走完等下一步）时出现，写“专注中 ·
/// 12:34”/“休息中 · …”/“专注已暂停”/“时间到了”，点开回到专注页。没在计时
/// 或专注计时关着时收起（`medium`）。剩余时间每秒更新，只在走着时计时。
class TodoFocusBanner extends ConsumerStatefulWidget {
  const TodoFocusBanner({super.key});

  @override
  ConsumerState<TodoFocusBanner> createState() => _TodoFocusBannerState();
}

class _TodoFocusBannerState extends ConsumerState<TodoFocusBanner> {
  Timer? _tick;

  /// 收起途中仍写最后一次的文字，不先变空。
  String _label = '';

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _schedule(TodoFocusRun? run) {
    final running = run != null && !run.paused;
    if (running && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = ref.watch(
      appFeaturesProvider.select((features) => features.todoFocusEnabled),
    );
    final state = ref.watch(todoFocusProvider);
    final now = ref.watch(todoNowProvider);
    final run = enabled ? state.run : null;
    _schedule(run);
    final visible = enabled && !state.idle;
    final ended = visible && run == null;
    if (visible) {
      _label = switch (run) {
        null => l10n.todoFocusBannerEnded,
        final run when run.paused => l10n.todoFocusBannerPaused,
        final run when run.phase.isBreak => l10n.todoFocusBannerBreak(
          TodoFocusFormat.clock(run.remaining(now())),
        ),
        final run => l10n.todoFocusBannerRunning(
          TodoFocusFormat.clock(run.remaining(now())),
        ),
      };
    }

    final dotColor = run == null
        ? scheme.onPrimary
        : run.paused
        ? scheme.outline
        : run.phase.isBreak
        ? scheme.tertiary
        : scheme.primary;

    // 等宽数字：每秒变化时胶囊宽度不跟着抖。
    final own = FilledButton.styleFrom(
      textStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
    final button = ended
        ? FilledButton.icon(
            style: own,
            onPressed: () => unawaited(openTodoFocusPage(context)),
            icon: const FaIcon(FontAwesomeIcons.bell, size: 13),
            label: Text(_label),
          )
        : FilledButton.tonalIcon(
            style: AppGlassField.tonalButtonStyle(context)?.merge(own) ?? own,
            onPressed: visible
                ? () => unawaited(openTodoFocusPage(context))
                : null,
            icon: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                const FaIcon(FontAwesomeIcons.stopwatch, size: 13),
              ],
            ),
            label: Text(_label),
          );

    return ListItemPresence(
      visible: visible,
      appearing: visible,
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.s),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: button,
        ),
      ),
    );
  }
}
