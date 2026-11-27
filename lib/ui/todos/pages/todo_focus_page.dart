import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_service.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/app_top_bar.dart';
import '../controllers/todo_actions.dart';
import '../controllers/todo_focus_controller.dart';
import '../providers/todo_providers.dart';
import '../widgets/todo_focus_panels.dart';

/// 专注计时页：安静的大圆环、等宽倒计时与待办标题（[TodoFocusRunPanel]），
/// 走完时换成下一步（[TodoFocusEndedPanel]）；状态全在 [todoFocusProvider]，
/// 页面关着计时照走。
///
/// - 计时中 / 走完 / 没在计时三种画面之间顺序式淡入淡出（`medium`）；
/// - 走完的那一刻一次中等触觉；
/// - 提前结束：满 60 秒的记下并提示“已记下 N 分钟专注”，然后离开本页；
///   走完后点“结束”同样离开。
class TodoFocusPage extends ConsumerWidget {
  const TodoFocusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(todoFocusProvider);
    final settings = ref.watch(todoSettingsProvider.select((s) => s.focus));
    final now = ref.watch(todoNowProvider);
    final controller = ref.read(todoFocusProvider.notifier);
    ref.listen<TodoFocusState>(todoFocusProvider, (
      TodoFocusState? before,
      TodoFocusState next,
    ) {
      if (before?.run != null && next.ended != null) {
        unawaited(HapticFeedback.mediumImpact());
      }
    });
    final run = state.run;
    final ended = state.ended;
    final todoId = ended?.todoId;
    final todo = todoId == null ? null : ref.watch(todoProvider(todoId)).value;

    Future<void> stop() async {
      final current = ref.read(todoFocusProvider).run;
      final kept = current == null || current.phase.isBreak
          ? 0
          : current.elapsed(now());
      await controller.stop();
      if (!context.mounted) return;
      if (kept >= TodoFocusRules.minRecordedSeconds) {
        unawaited(
          HomeHintVisibilityScope.showTrackedSnackBar(
            context: context,
            snackBar: SnackBar(
              content: Text(l10n.todoFocusStoppedNotice(kept ~/ 60)),
            ),
          ),
        );
      }
      unawaited(Navigator.of(context).maybePop());
    }

    Future<void> finish() async {
      await controller.dismiss();
      if (context.mounted) unawaited(Navigator.of(context).maybePop());
    }

    Future<void> complete(TodoRow row) async {
      await toggleTodoDone(context, ref.read(appDatabaseProvider), row);
    }

    final String kind;
    if (run != null) {
      kind = 'run';
    } else if (ended != null) {
      kind = 'ended-${ended.phase.name}';
    } else {
      kind = 'idle';
    }

    return AppPageBackground(
      area: AppBackgroundArea.other,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
            title: Text(l10n.todoFocusTitle),
          ),
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final dial = (constraints.maxWidth - 2 * AppSpacing.xxxl).clamp(
                200.0,
                300.0,
              );
              final Widget content = switch (kind) {
                'run' => TodoFocusRunPanel(
                  run: run!,
                  settings: settings,
                  now: now,
                  dialSize: dial,
                  onPause: () => unawaited(controller.pause()),
                  onResume: () => unawaited(controller.resume()),
                  onExtend: () => unawaited(controller.extend()),
                  onStop: () => unawaited(stop()),
                  onSkipBreak: () => unawaited(controller.stop()),
                ),
                'idle' => _IdlePanel(
                  minutes: settings.focusMinutes,
                  onStart: () =>
                      unawaited(controller.start(todoId: null, title: '')),
                ),
                _ => TodoFocusEndedPanel(
                  ended: ended!,
                  settings: settings,
                  canComplete: todo != null && todo.completedAt == null,
                  onBreak: () => unawaited(controller.startBreak()),
                  onNext: () => unawaited(controller.startNext()),
                  onComplete: () {
                    if (todo != null) unawaited(complete(todo));
                  },
                  onFinish: () => unawaited(finish()),
                ),
              };
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.l,
                    AppSpacing.l,
                    AppSpacing.l,
                    AppSpacing.xxxl,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AnimatedSwitcher(
                      duration: ExpressiveMotion.duration(
                        context,
                        ExpressiveMotion.medium,
                      ),
                      switchInCurve: ExpressiveMotion.effects,
                      switchOutCurve: ExpressiveMotion.exit,
                      child: KeyedSubtree(
                        key: ValueKey<String>(kind),
                        child: content,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 没在计时（结束后又回到本页、或功能被关后又打开）：一个开始按钮。
class _IdlePanel extends StatelessWidget {
  const _IdlePanel({required this.minutes, required this.onStart});

  final int minutes;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton.icon(
        onPressed: onStart,
        icon: const FaIcon(FontAwesomeIcons.play, size: 16),
        label: Text(context.l10n.todoFocusStart(minutes)),
      ),
    );
  }
}
