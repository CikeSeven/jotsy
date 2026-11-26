import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_spacing.dart';
import '../../app_surface/widgets/app_page_backdrop.dart';

/// 待办页的外框：页面底色、内容 [body]、叠在上面的页头 [header]（多选时由
/// 页面换成“已选 N”的页头）与多选操作栏 [actionBar]（底部居中、最宽 480）。
///
/// 多选时（[selecting]）返回键与 Esc 先退出多选（[onExitSelection]），不离开
/// 首页。内容不避让上下安全区：页头与底栏悬浮在内容之上，列表自己留白。
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
            if (bar != null)
              Positioned(
                left: AppSpacing.l,
                right: AppSpacing.l,
                bottom: bottomInset + AppSpacing.l,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: bar,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
