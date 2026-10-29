// 前台自动同步的提示条（DESIGN.md §5.27 自动同步提示）。
//
// - 输入：同步控制器的事件流，以及取当前可用 context 的回调（宿主已销毁时
//   返回 null）；
// - 输出：无；
// - 副作用：收到 [LanSyncAutoSyncAppliedEvent] / [LanSyncAutoSyncNeedsAttentionEvent]
//   时经 showTrackedSnackBar 显示提示，按钮“查看”打开同步页。其余事件交给
//   同步页与各面板，这里不处理。
//
// 挂在首页（与自动检查更新同一处）：首页在整个应用生命周期里都在路由栈
// 底部，它的 context 能找到根 ScaffoldMessenger，提示条在任何页面上都看得见；
// 应用级的 MaterialApp.builder 位于 Navigator 之上，拿不到能 push 页面的
// context。由宿主在 dispose 时调用 [dispose] 取消订阅。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../home/widgets/home_hint_visibility_scope.dart';
import '../models/lan_sync_ui_events.dart';
import '../pages/lan_sync_page.dart';

/// 见文件头注释。
class LanSyncAutoSyncNotices {
  /// [_contextOf] 取当前可用的 context，宿主已销毁时返回 null。
  LanSyncAutoSyncNotices(Stream<LanSyncUiEvent> events, this._contextOf) {
    _subscription = events.listen(_handle);
  }

  final BuildContext? Function() _contextOf;
  late final StreamSubscription<LanSyncUiEvent> _subscription;

  void _handle(LanSyncUiEvent event) {
    final context = _contextOf();
    if (context == null || !context.mounted) return;
    final l10n = context.l10n;
    final String message;
    switch (event) {
      case LanSyncAutoSyncAppliedEvent(:final peerName, :final diaries):
        // 没有变化时控制器本就不发事件；这里再兜一次，0 篇不提示。
        if (diaries <= 0) return;
        message = l10n.lanSyncAutoSyncApplied(peerName, diaries);
      case LanSyncAutoSyncNeedsAttentionEvent(:final peerName):
        message = l10n.lanSyncAutoSyncNeedsAttention(peerName);
      default:
        return;
    }
    final navigator = Navigator.of(context);
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(
          persist: false,
          content: Row(
            children: <Widget>[
              // 图标取提示条正文的颜色：经典为反色、玻璃为玻璃上的可读色
              // （见 AppGlassSnackBarTheme），两种材质下都看得清。
              Builder(
                builder: (BuildContext context) => FaIcon(
                  FontAwesomeIcons.arrowsRotate,
                  size: 16,
                  color: DefaultTextStyle.of(context).style.color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          action: SnackBarAction(
            label: l10n.lanSyncReview,
            onPressed: () => navigator.push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const LanSyncPage(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 取消订阅。
  void dispose() {
    unawaited(_subscription.cancel());
  }
}
