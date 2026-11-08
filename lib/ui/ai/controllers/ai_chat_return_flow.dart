// “回到对话”的打开与提示（登记见 `aiChatReturnProvider`）。
//
// 时序：
// 1. 对话页登记后打开目标，首页之上的页面全部关掉、首页切 Tab / 范围；
// 2. 首页监听到登记，每 200ms 看一次自己是不是当前页（上锁的日记本要先
//    验证，可能停留几秒），是了就弹一次提示条“按返回键即可回到对话”+“回到
//    对话”（桌面没有返回键也能回去）；最多等 12 秒，登记撤销即停；
// 3. 返回键（首页 / 日记页的 PopScope 让位）或提示条按钮经 [reopenAiChat]
//    重新打开这段对话：淡入 + 由 0.96 放大，读起来是“回到”而不是“前进”。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../l10n/app_localizations.dart';
import '../../home/widgets/home_hint_visibility_scope.dart';
import '../pages/ai_chat_page.dart';
import '../providers/ai_chat_return_provider.dart';

/// 重新打开挂起的那段对话（没有挂起时什么都不做）。
Future<void> reopenAiChat(BuildContext context, WidgetRef ref) async {
  final id = ref.read(aiChatReturnProvider);
  if (id == null) return;
  ref.read(aiChatReturnProvider.notifier).disarm();
  ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
  final duration = ExpressiveMotion.duration(context);
  await Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      pageBuilder: (_, _, _) => AiChatPage(conversationId: id),
      transitionsBuilder: (_, animation, _, child) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: ExpressiveMotion.effects,
          reverseCurve: ExpressiveMotion.exit,
        );
        return FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(fade),
            child: child,
          ),
        );
      },
    ),
  );
}

/// 首页持有：登记后等到自己是当前页时弹一次“回到对话”提示条。
class AiChatReturnHint {
  static const Duration _tick = Duration(milliseconds: 200);
  static const int _maxTicks = 60;

  Timer? _timer;

  /// 开始等待；[isCurrent] 为首页是否是当前页，[show] 弹提示条。
  void start({required bool Function() isCurrent, required VoidCallback show}) {
    cancel();
    var ticks = 0;
    _timer = Timer.periodic(_tick, (Timer timer) {
      ticks++;
      if (isCurrent()) {
        timer.cancel();
        show();
      } else if (ticks >= _maxTicks) {
        timer.cancel();
      }
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

/// 首页的“回到对话”提示条。
void showAiChatReturnSnackBar(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  unawaited(
    HomeHintVisibilityScope.showTrackedSnackBar(
      context: context,
      snackBar: SnackBar(
        content: Text(l10n.aiChatReturnHint),
        persist: false,
        action: SnackBarAction(
          label: l10n.aiChatReturnAction,
          onPressed: () => unawaited(reopenAiChat(context, ref)),
        ),
      ),
    ),
  );
}
