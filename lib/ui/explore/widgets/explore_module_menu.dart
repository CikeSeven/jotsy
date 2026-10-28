import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../widgets/expressive_menu/expressive_menu.dart';
import '../controllers/explore_module_actions.dart';
import '../models/explore_module_id.dart';

/// 探索页卡片的快捷菜单：长按（桌面上为右键）在按下处打开，两项：“卡片
/// 设置”（打开自定义页并定位到这张卡）与“隐藏此卡片”（可撤销）。
///
/// 菜单是共用的 [ExpressiveMenuAnchor]（[ExpressiveMenuAnchorState.openAt]）。
/// 长按的震动：Android 经 [Feedback.forLongPress] 的系统反馈，iOS 补一次
/// mediumImpact（DESIGN §4.3）。预览里（动作不可用）原样返回卡片。
class ExploreModuleMenu extends StatelessWidget {
  const ExploreModuleMenu({super.key, required this.id, required this.child});

  final ExploreModuleId id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final actions = ExploreActionsScope.of(context);
    if (!actions.interactive) return child;
    final l10n = context.l10n;
    return ExpressiveMenuAnchor(
      menuChildren: <Widget>[
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.sliders),
          onPressed: () => actions.customize(focus: id),
          child: Text(l10n.exploreModuleMenuSettings),
        ),
        ExpressiveMenuItem(
          leadingIcon: const FaIcon(FontAwesomeIcons.eyeSlash),
          onPressed: () => actions.hideModule(id),
          child: Text(l10n.exploreModuleMenuHide),
        ),
      ],
      builder:
          (BuildContext context, ExpressiveMenuAnchorState menu, Widget? card) {
            return GestureDetector(
              onLongPressStart: (LongPressStartDetails details) {
                unawaited(Feedback.forLongPress(context));
                if (Theme.of(context).platform == TargetPlatform.iOS) {
                  unawaited(HapticFeedback.mediumImpact());
                }
                menu.openAt(details.globalPosition);
              },
              onSecondaryTapUp: (TapUpDetails details) =>
                  menu.openAt(details.globalPosition),
              child: card,
            );
          },
      child: child,
    );
  }
}
