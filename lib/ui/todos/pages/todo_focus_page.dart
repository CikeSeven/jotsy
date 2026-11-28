import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_card_surface.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/glass/glass_reveal.dart';
import '../controllers/todo_actions.dart';
import '../controllers/todo_focus_controller.dart';
import '../controllers/todo_navigation.dart';
import '../providers/todo_providers.dart';
import '../widgets/todo_focus_ended_panel.dart';
import '../widgets/todo_focus_panels.dart';
import '../widgets/todo_focus_sheets.dart';
import '../widgets/todo_focus_task_card.dart';

/// 专注计时页（Material 3 Expressive）：
///
/// - 计时中（[TodoFocusRunPanel]）：有机多瓣底盘 + 60 格刻度 + M3E 动态波形
///   进度弧 + 形变操控栏 + 关联待办上下文与就地步骤勾选；
/// - 准备态（[TodoFocusIdlePanel]）：静态有机表盘预览 + 快捷时长胶囊条 +
///   待办选择与节奏概览；
/// - 完成态（[TodoFocusEndedPanel]）：12 瓣饼干庆祝徽章 + 成就摘要卡 + 分层操作；
/// - 纯净模式：收起顶栏、任务卡与手机系统状态栏 / 导航栏（`immersiveSticky`），
///   点按空白区、右上角轻退出钮或返回键退出，离开页面或计时结束自动恢复
///   `edgeToEdge`；
/// - 宽窗口（`AppBreakpoints.expanded`）运行且带任务上下文时切换左右双栏工作台；
/// - 桌面端支持 Space 暂停/继续、`+` 加 5 分钟、Esc 先退纯净再返回；
/// - 状态全在 [todoFocusProvider]，页面关着计时照走。
class TodoFocusPage extends ConsumerStatefulWidget {
  const TodoFocusPage({super.key});

  @override
  ConsumerState<TodoFocusPage> createState() => _TodoFocusPageState();
}

class _TodoFocusPageState extends ConsumerState<TodoFocusPage> {
  static const double _topBarHeight = 64;

  bool _zenMode = false;
  bool _systemBarsHidden = false;
  String? _selectedTodoId;

  @override
  void dispose() {
    _syncSystemBars(hide: false);
    super.dispose();
  }

  /// 仅在手机端切换系统状态栏 / 导航栏显隐；离开页面或退出纯净模式时还原。
  void _syncSystemBars({required bool hide}) {
    if (!AppPlatform.isMobile || _systemBarsHidden == hide) return;
    _systemBarsHidden = hide;
    unawaited(
      SystemChrome.setEnabledSystemUIMode(
        hide ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      ),
    );
  }

  void _setZenMode(bool enabled) {
    if (_zenMode == enabled) return;
    setState(() => _zenMode = enabled);
    _syncSystemBars(hide: enabled);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(todoFocusProvider);
    final todoSettings = ref.watch(todoSettingsProvider);
    final settings = todoSettings.focus;
    final now = ref.watch(todoNowProvider);
    final today = ref.watch(todoTodayProvider);
    final todaySeconds = ref.watch(todoFocusSinceProvider(today)).value ?? 0;
    final controller = ref.read(todoFocusProvider.notifier);

    ref.listen<TodoFocusState>(todoFocusProvider, (
      TodoFocusState? before,
      TodoFocusState next,
    ) {
      if (before?.run != null && next.ended != null) {
        unawaited(HapticFeedback.mediumImpact());
      }
      if (next.run == null && _zenMode) {
        _setZenMode(false);
      }
    });

    final run = state.run;
    final ended = state.ended;
    final zenActive = run != null && _zenMode;
    _syncSystemBars(hide: zenActive);

    final activeTodoId = run?.todoId ?? ended?.todoId;
    final activeTodo = activeTodoId == null
        ? null
        : ref.watch(todoProvider(activeTodoId)).value;
    final activeTodoSeconds = activeTodoId == null
        ? 0
        : ref.watch(todoFocusSecondsProvider(activeTodoId)).value ?? 0;

    final openTodos = run == null && ended == null
        ? ref.watch(openTodosProvider).value ?? const <TodoRow>[]
        : const <TodoRow>[];
    final idleSelectedTodo = _resolveSelectedTodo(openTodos);

    Future<void> stop() async {
      final current = ref.read(todoFocusProvider).run;
      final kept = current == null || current.phase.isBreak
          ? 0
          : current.elapsed(now());
      _setZenMode(false);
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

    Future<void> pickTodo() async {
      final result = await showTodoFocusPickerSheet(
        context,
        openTodos: openTodos,
        selectedTodoId: idleSelectedTodo?.todoId,
      );
      if (result == null || !mounted) return;
      setState(() => _selectedTodoId = result.todo?.todoId);
    }

    void selectFocusMinutes(int minutes) {
      final service = ref.read(settingsServiceProvider).asData?.value;
      if (service == null || settings.focusMinutes == minutes) return;
      unawaited(
        saveTodoSettings(
          service,
          todoSettings.copyWith(
            focus: settings.copyWith(focusMinutes: minutes),
          ),
        ),
      );
    }

    void startIdle() {
      final todo = idleSelectedTodo;
      unawaited(
        controller.start(todoId: todo?.todoId, title: todo?.title ?? ''),
      );
    }

    void toggleStep(String stepId, bool done) {
      final id = activeTodo?.todoId;
      if (id == null) return;
      unawaited(
        ref.read(appDatabaseProvider).setTodoStepDone(id, stepId, done),
      );
    }

    final String kind;
    if (run != null) {
      kind = 'run';
    } else if (ended != null) {
      kind = 'ended-${ended.phase.name}';
    } else {
      kind = 'idle';
    }

    final hasTaskContext =
        run != null && (run.title.trim().isNotEmpty || activeTodo != null);

    Widget page = PopScope(
      canPop: !zenActive,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop && zenActive) _setZenMode(false);
      },
      child: AppPageBackground(
        area: AppBackgroundArea.other,
        child: Builder(
          builder: (BuildContext context) {
            final isGlassCard = AppCardSurface.isGlass(context);
            final viewPadding = MediaQuery.viewPaddingOf(context);
            final motion = ExpressiveMotion.duration(
              context,
              ExpressiveMotion.medium,
            );
            return Scaffold(
              backgroundColor: AppPageBackdrop.pageColorOf(context),
              body: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: zenActive ? () => _setZenMode(false) : null,
                    child: AnimatedPadding(
                      duration: motion,
                      curve: ExpressiveMotion.spatial,
                      padding: EdgeInsets.only(
                        top: zenActive
                            ? AppSpacing.l
                            : viewPadding.top + _topBarHeight,
                        bottom: zenActive ? AppSpacing.l : viewPadding.bottom,
                      ),
                      child: LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              final window = AppBreakpoints.classOf(
                                constraints.maxWidth,
                              );
                              final splitWide =
                                  kind == 'run' &&
                                  window == AppWindowClass.expanded &&
                                  hasTaskContext &&
                                  !zenActive;
                              final dialSize = _computeDialSize(
                                constraints,
                                splitWide: splitWide,
                                isIdle: kind == 'idle',
                                zenActive: zenActive,
                              );

                              Widget? buildTaskCard({
                                required bool alwaysExpand,
                              }) {
                                if (!hasTaskContext) return null;
                                return TodoFocusTaskCard(
                                  title: run.title,
                                  todo: activeTodo,
                                  focusSeconds: activeTodoSeconds,
                                  alwaysExpandSteps: alwaysExpand,
                                  onToggleStep: toggleStep,
                                  onOpenDetail: activeTodo == null
                                      ? null
                                      : () => unawaited(
                                          openTodoDetail(
                                            context,
                                            activeTodo.todoId,
                                          ),
                                        ),
                                );
                              }

                              final Widget content = switch (kind) {
                                'run' when splitWide => _WideFocusWorkbench(
                                  stage: TodoFocusRunPanel(
                                    run: run,
                                    settings: settings,
                                    now: now,
                                    dialSize: dialSize,
                                    onPause: () =>
                                        unawaited(controller.pause()),
                                    onResume: () =>
                                        unawaited(controller.resume()),
                                    onExtend: () =>
                                        unawaited(controller.extend()),
                                    onStop: () => unawaited(stop()),
                                    onSkipBreak: () =>
                                        unawaited(controller.stop()),
                                    zenMode: true,
                                  ),
                                  side: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      buildTaskCard(alwaysExpand: true)!,
                                      if (todaySeconds >= 60) ...<Widget>[
                                        const SizedBox(height: AppSpacing.m),
                                        Align(
                                          alignment:
                                              AlignmentDirectional.centerStart,
                                          child: TodoFocusTodayPill(
                                            todaySeconds: todaySeconds,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                'run' => TodoFocusRunPanel(
                                  run: run!,
                                  settings: settings,
                                  now: now,
                                  dialSize: dialSize,
                                  onPause: () => unawaited(controller.pause()),
                                  onResume: () =>
                                      unawaited(controller.resume()),
                                  onExtend: () =>
                                      unawaited(controller.extend()),
                                  onStop: () => unawaited(stop()),
                                  onSkipBreak: () =>
                                      unawaited(controller.stop()),
                                  taskCard: buildTaskCard(alwaysExpand: false),
                                  todaySeconds: todaySeconds,
                                  zenMode: zenActive,
                                ),
                                'idle' => TodoFocusIdlePanel(
                                  settings: settings,
                                  now: now,
                                  dialSize: dialSize,
                                  selectedTodo: idleSelectedTodo,
                                  todaySeconds: todaySeconds,
                                  onSelectMinutes: selectFocusMinutes,
                                  onPickTodo: () => unawaited(pickTodo()),
                                  onOpenRhythm: () => unawaited(
                                    showTodoFocusRhythmSheet(context),
                                  ),
                                  onStart: startIdle,
                                ),
                                _ => TodoFocusEndedPanel(
                                  ended: ended!,
                                  settings: settings,
                                  canComplete:
                                      activeTodo != null &&
                                      activeTodo.completedAt == null,
                                  todaySeconds: todaySeconds,
                                  onBreak: () =>
                                      unawaited(controller.startBreak()),
                                  onNext: () =>
                                      unawaited(controller.startNext()),
                                  onComplete: () {
                                    if (activeTodo != null) {
                                      unawaited(complete(activeTodo));
                                    }
                                  },
                                  onFinish: () => unawaited(finish()),
                                ),
                              };

                              final maxWidth = splitWide
                                  ? AppContentWidth.explore
                                  : 460.0;
                              return Center(
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.fromLTRB(
                                    AppContentWidth.gutter(
                                      constraints.maxWidth,
                                      maxWidth,
                                    ),
                                    AppSpacing.m,
                                    AppContentWidth.gutter(
                                      constraints.maxWidth,
                                      maxWidth,
                                    ),
                                    AppSpacing.xxl,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      AnimatedSwitcher(
                                        duration: motion,
                                        switchInCurve: ExpressiveMotion.effects,
                                        switchOutCurve: ExpressiveMotion.exit,
                                        transitionBuilder:
                                            (
                                              Widget child,
                                              Animation<double> animation,
                                            ) {
                                              if (isGlassCard) {
                                                return AnimatedBuilder(
                                                  animation: animation,
                                                  builder:
                                                      (
                                                        BuildContext _,
                                                        Widget? c,
                                                      ) => GlassReveal(
                                                        progress:
                                                            animation.value,
                                                        child: c!,
                                                      ),
                                                  child: child,
                                                );
                                              }
                                              return FadeTransition(
                                                opacity: animation,
                                                child: ScaleTransition(
                                                  scale: Tween<double>(
                                                    begin: 0.96,
                                                    end: 1.0,
                                                  ).animate(animation),
                                                  child: child,
                                                ),
                                              );
                                            },
                                        child: KeyedSubtree(
                                          key: ValueKey<String>(kind),
                                          child: content,
                                        ),
                                      ),
                                      if (AppPlatform.isDesktop &&
                                          !zenActive) ...<Widget>[
                                        const SizedBox(height: AppSpacing.xxl),
                                        Text(
                                          l10n.todoFocusKeyboardHint,
                                          textAlign: TextAlign.center,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant
                                                    .withValues(alpha: 0.72),
                                              ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                      ),
                    ),
                  ),
                  // 顶栏（纯净模式下整体平滑滑出屏幕，不包裹 Opacity 以兼容玻璃顶栏）。
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ClipRect(
                      child: AnimatedSlide(
                        offset: zenActive ? const Offset(0, -1) : Offset.zero,
                        duration: motion,
                        curve: ExpressiveMotion.spatial,
                        child: IgnorePointer(
                          ignoring: zenActive,
                          child: ExcludeSemantics(
                            excluding: zenActive,
                            child: AppTopBar(
                              leading: IconButton(
                                tooltip: l10n.commonBack,
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                                icon: const FaIcon(
                                  FontAwesomeIcons.angleLeft,
                                  size: 18,
                                ),
                              ),
                              title: Text(l10n.todoFocusTitle),
                              actions: <Widget>[
                                if (run != null)
                                  IconButton(
                                    tooltip: l10n.todoFocusZenEnter,
                                    onPressed: () => _setZenMode(true),
                                    icon: const FaIcon(
                                      FontAwesomeIcons.expand,
                                      size: 16,
                                    ),
                                  ),
                                IconButton(
                                  tooltip: l10n.todoFocusRhythm,
                                  onPressed: () => unawaited(
                                    showTodoFocusRhythmSheet(context),
                                  ),
                                  icon: const FaIcon(
                                    FontAwesomeIcons.sliders,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 纯净模式下的极克制角落退出按钮（同时支持点按空白处与返回键退出）。
                  if (zenActive)
                    PositionedDirectional(
                      top: math.max(viewPadding.top, AppSpacing.l),
                      end: AppSpacing.l,
                      child: IconButton(
                        tooltip: l10n.todoFocusZenExit,
                        onPressed: () => _setZenMode(false),
                        icon: FaIcon(
                          FontAwesomeIcons.compress,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.48),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );

    if (AppPlatform.isDesktop) {
      page = CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.space): () {
            final current = ref.read(todoFocusProvider).run;
            if (current != null) {
              unawaited(
                current.paused ? controller.resume() : controller.pause(),
              );
            } else if (ref.read(todoFocusProvider).idle) {
              startIdle();
            }
          },
          const SingleActivator(LogicalKeyboardKey.equal): () {
            final current = ref.read(todoFocusProvider).run;
            if (current != null && !current.phase.isBreak) {
              unawaited(controller.extend());
            }
          },
          const SingleActivator(LogicalKeyboardKey.add): () {
            final current = ref.read(todoFocusProvider).run;
            if (current != null && !current.phase.isBreak) {
              unawaited(controller.extend());
            }
          },
          const SingleActivator(LogicalKeyboardKey.numpadAdd): () {
            final current = ref.read(todoFocusProvider).run;
            if (current != null && !current.phase.isBreak) {
              unawaited(controller.extend());
            }
          },
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (zenActive) {
              _setZenMode(false);
            } else {
              unawaited(Navigator.of(context).maybePop());
            }
          },
        },
        child: Focus(autofocus: true, child: page),
      );
    }

    return page;
  }

  TodoRow? _resolveSelectedTodo(List<TodoRow> openTodos) {
    final id = _selectedTodoId;
    if (id == null) return null;
    for (final todo in openTodos) {
      if (todo.todoId == id) return todo;
    }
    return null;
  }

  static double _computeDialSize(
    BoxConstraints constraints, {
    required bool splitWide,
    required bool isIdle,
    required bool zenActive,
  }) {
    if (splitWide) {
      return math.min(constraints.maxHeight * 0.50, 324.0).clamp(240.0, 324.0);
    }
    final byWidth = constraints.maxWidth - 2 * AppSpacing.xxxl;
    final heightRatio = isIdle
        ? 0.34
        : zenActive
        ? 0.48
        : 0.40;
    final maxDial = zenActive ? 324.0 : 296.0;
    final byHeight = constraints.maxHeight * heightRatio;
    return math.min(byWidth, byHeight).clamp(210.0, maxDial);
  }
}

/// 宽窗口（≥ 1024）专注双栏工作台：左侧表盘舞台，右侧关联待办与就地步骤。
class _WideFocusWorkbench extends StatelessWidget {
  const _WideFocusWorkbench({required this.stage, required this.side});

  final Widget stage;
  final Widget side;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(flex: 6, child: Center(child: stage)),
        const SizedBox(width: AppSpacing.xxxl),
        Expanded(
          flex: 5,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: side,
          ),
        ),
      ],
    );
  }
}
