import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/app_lock_layer.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/device_auth_service.dart';
import '../controllers/notebook_lock_flow.dart';
import '../providers/home_notebook_scope_provider.dart';

/// 上锁日记本的重新上锁层：首页正在看上锁的日记本时应用切到后台（hidden /
/// paused），验证会话随即失效，整个应用被遮罩盖住，回来后须重新验证。
///
/// 输入：[child] 应用内容（MaterialApp 的 Navigator）。副作用：改写
/// `homeNotebookScopeProvider`（relock / unlock / showAll）、弹出系统身份
/// 验证。“回到全部日记”只重置范围：日记页发现范围被外部改回全部日记时
/// 自己退回首页路由（这一层在 Navigator 之上，拿不到它；给 MaterialApp
/// 挂 navigatorKey 会在启动换壳时把旧首页路由一起带走）。
///
/// - 遮罩与内容隔离复用 [AppLockLayer]（排除下层语义与焦点、立即出现、淡出）；
/// - 切到后台的那一刻就上锁：最近任务的截图里也只有遮罩；
/// - “解锁”验证通过后揭开；连续两次未通过、或点“回到全部日记”时退回首页
///   并回到全部日记（再进入需要重新验证）；
/// - 验证进行中系统界面可能让应用暂时进入后台，期间不重复上锁；
/// - 应用锁只在冷启动与开关时验证，回到前台不会再弹，因此不会与这里连着
///   出现两次验证。
class NotebookLockLayer extends ConsumerStatefulWidget {
  const NotebookLockLayer({super.key, required this.child});

  final Widget child;

  /// 连续几次验证未通过后放弃这本、回到全部日记。
  static const int maxFailedAttempts = 2;

  @override
  ConsumerState<NotebookLockLayer> createState() => _NotebookLockLayerState();
}

class _NotebookLockLayerState extends ConsumerState<NotebookLockLayer> {
  late final AppLifecycleListener _lifecycle;
  bool _authenticating = false;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onHide: _relock, onPause: _relock);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// 正在看上锁的日记本时让会话失效。
  void _relock() {
    if (_authenticating) {
      return;
    }
    final resolution = ref.read(homeNotebookScopeResolutionProvider);
    final notebook = resolution.notebook;
    if (notebook == null || !notebookRequiresAuth(notebook)) {
      return;
    }
    _failedAttempts = 0;
    ref.read(homeNotebookScopeProvider.notifier).relock();
  }

  Future<void> _unlock() async {
    if (_authenticating) {
      return;
    }
    final notebook = ref.read(homeNotebookScopeResolutionProvider).notebook;
    if (notebook == null) {
      _backToAll();
      return;
    }
    final auth = ref.read(deviceAuthServiceProvider);
    final reason = context.l10n.notebookUnlockReason(notebook.name);
    setState(() => _authenticating = true);
    final supported = await auth.isSupported();
    final passed = supported && await auth.authenticate(reason: reason);
    if (!mounted) {
      return;
    }
    setState(() => _authenticating = false);
    if (passed) {
      _failedAttempts = 0;
      ref.read(homeNotebookScopeProvider.notifier).unlock();
      return;
    }
    _failedAttempts++;
    if (!supported || _failedAttempts >= NotebookLockLayer.maxFailedAttempts) {
      _backToAll();
    }
  }

  /// 回到全部日记并揭开遮罩（日记页随之退回首页路由）。
  void _backToAll() {
    _failedAttempts = 0;
    ref.read(homeNotebookScopeProvider.notifier).showAll();
  }

  @override
  Widget build(BuildContext context) {
    final (inNotebook, relocked) = ref.watch(
      homeNotebookScopeProvider.select(
        (scope) => (!scope.isAll, scope.relocked),
      ),
    );
    // 在日记本里时保持订阅范围解析：切到后台的那一刻要同步读出这本是否上锁
    // （书架此时必须已加载）；全部日记时不订阅书架。
    final name = inNotebook
        ? ref.watch(
                homeNotebookScopeResolutionProvider.select(
                  (resolution) => resolution.notebook?.name,
                ),
              ) ??
              ''
        : '';
    return AppLockLayer(
      locked: relocked,
      overlayBuilder: (_) => _NotebookLockOverlay(
        name: name,
        authenticating: _authenticating,
        onUnlock: () => unawaited(_unlock()),
        onBackToAll: _backToAll,
      ),
      child: widget.child,
    );
  }
}

/// 遮罩内容：锁图标、“「旅行」已上锁”、解锁与回到全部日记。
class _NotebookLockOverlay extends StatelessWidget {
  const _NotebookLockOverlay({
    required this.name,
    required this.authenticating,
    required this.onUnlock,
    required this.onBackToAll,
  });

  final String name;
  final bool authenticating;
  final VoidCallback onUnlock;
  final VoidCallback onBackToAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    return ColoredBox(
      color: scheme.surface.withValues(alpha: 0.98),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FaIcon(FontAwesomeIcons.lock, size: 28, color: scheme.primary),
                const SizedBox(height: 14),
                Text(
                  l10n.notebookLockedTitle(name),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.s),
                Text(
                  l10n.notebookLockedSubtitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: authenticating ? null : onUnlock,
                  icon: const FaIcon(FontAwesomeIcons.key, size: 14),
                  label: Text(l10n.notebookLockUnlock),
                ),
                const SizedBox(height: AppSpacing.s),
                TextButton(
                  onPressed: authenticating ? null : onBackToAll,
                  child: Text(l10n.notebookLockBackToAll),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
