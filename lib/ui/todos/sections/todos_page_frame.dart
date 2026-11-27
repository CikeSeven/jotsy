import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';

/// 待办页的外框：页面底色、内容 [body]、叠在上面的页头 [header]（多选时由
/// 页面换成“已选 N”的页头）与多选操作栏 [actionBar]（底部居中、最宽 480）。
///
/// 多选时（[selecting]）返回键与 Esc 先退出多选（[onExitSelection]），不离开
/// 首页。内容不避让上下安全区：页头与底栏悬浮在内容之上，列表自己留白。
///
/// 操作栏的进出（[_ActionBarDock]）：出现时以真弹簧从屏幕底边外升起，退出
/// 多选时沉回去、沉到看不见才移出树（途中不可点）。只平移、不淡入淡出：
/// 操作栏可能是玻璃表面。
class TodosPageFrame extends StatelessWidget {
  const TodosPageFrame({
    super.key,
    required this.body,
    required this.header,
    required this.selecting,
    required this.onExitSelection,
    required this.bottomInset,
    this.actionBar,
  });

  final Widget body;

  /// 叠在内容之上的页头（自带 Positioned，见 `PageHeader`）。
  final Widget header;
  final bool selecting;
  final VoidCallback onExitSelection;

  /// 底部安全区（手势条）的高度：操作栏停在它上方。
  final double bottomInset;
  final Widget? actionBar;

  @override
  Widget build(BuildContext context) {
    final bar = actionBar;
    return PopScope(
      canPop: !selecting,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop && selecting) onExitSelection();
      },
      child: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          if (selecting)
            const SingleActivator(LogicalKeyboardKey.escape): onExitSelection,
        },
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: ColoredBox(color: AppPageBackdrop.pageColorOf(context)),
            ),
            SafeArea(top: false, bottom: false, child: body),
            header,
            Positioned(
              left: AppSpacing.l,
              right: AppSpacing.l,
              bottom: bottomInset + AppSpacing.l,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _ActionBarDock(
                    bar: bar,
                    sink: bottomInset + AppSpacing.l,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 操作栏的升起与沉下（见 [TodosPageFrame]）。[bar] 变成 null 后留着上一份
/// 沉下去；[sink] 是操作栏底边到屏幕底边的距离，沉到它再加一个自身高度的
/// 一半处就完全看不见了。
class _ActionBarDock extends StatefulWidget {
  const _ActionBarDock({required this.bar, required this.sink});

  final Widget? bar;
  final double sink;

  @override
  State<_ActionBarDock> createState() => _ActionBarDockState();
}

class _ActionBarDockState extends State<_ActionBarDock>
    with SingleTickerProviderStateMixin {
  /// 0 沉在屏幕外，1 停在原位。无界：升起时略过 1 再落回。
  late final AnimationController _shown = AnimationController.unbounded(
    vsync: this,
  )..addStatusListener(_onStatus);

  static final Tolerance _tolerance = Tolerance(distance: 1e-3, velocity: 1e-2);

  /// 正在显示或正在沉下的那一份。
  Widget? _last;

  @override
  void initState() {
    super.initState();
    _last = widget.bar;
    if (_last != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _animate(1));
    }
  }

  @override
  void didUpdateWidget(_ActionBarDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bar = widget.bar;
    if (bar != null) {
      _last = bar;
      if (oldWidget.bar == null) _animate(1);
    } else if (oldWidget.bar != null) {
      _animate(0);
    }
  }

  void _animate(double target) {
    if (!mounted) return;
    ExpressiveMotion.springTo(
      context,
      _shown,
      target,
      spring: ExpressiveMotion.springSpatial,
      tolerance: _tolerance,
    );
    _onStatus(_shown.status);
  }

  void _onStatus(AnimationStatus _) {
    if (_shown.isAnimating || widget.bar != null || _last == null) return;
    if (_shown.value <= 0) setState(() => _last = null);
  }

  @override
  void dispose() {
    _shown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _last;
    if (last == null) return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: widget.bar == null,
      child: AnimatedBuilder(
        animation: _shown,
        builder: (BuildContext context, Widget? child) {
          final hidden = 1 - _shown.value;
          return Transform.translate(
            offset: Offset(0, hidden * widget.sink),
            child: FractionalTranslation(
              translation: Offset(0, hidden * 1.5),
              child: child,
            ),
          );
        },
        child: last,
      ),
    );
  }
}
