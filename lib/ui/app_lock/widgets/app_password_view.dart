// 应用密码的解锁视图（DESIGN.md §5.31）：冷启动的应用锁遮罩、上锁日记本的
// 重锁遮罩与 `AppPasswordVerifyPage` 共用。
//
// - 输入：标题与说明、是否允许 / 自动弹出指纹、解锁回调、可选的次要操作；
// - 输出：验证通过时调用 [AppPasswordView.onUnlocked]；
// - 副作用：核对密码（写输错记录）、弹指纹验证、输错时触觉反馈。
//
// 开场顺序（经 RouteEntranceWaiter：在路由里等入场结束，遮罩里下一帧即开始）：
// 1. 读出是否仍在等待（上次输错太多次）；
// 2. 允许自动弹指纹且可用时先弹一次：通过即解锁，取消再聚焦输入框；
// 3. 否则直接聚焦输入框（键盘随之弹出）。
//
// 通过后徽章先换成开锁（fast），再交给调用方揭开遮罩或关闭页面，开锁的那一下
// 看得见；减少动画时立即回调。
//
// 不在这里弹对话框：遮罩在 Navigator 之上，`showAppDialog` 找不到 Navigator。
// “忘记密码？”因此在原地展开一段说明。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_password/app_password_store.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/expressive_loading_indicator.dart';
import '../../widgets/route_entrance_waiter.dart';
import '../controllers/app_password_unlock_controller.dart';
import '../controllers/identity_verifier.dart';
import 'app_lock_emblem.dart';
import 'app_password_field.dart';

class AppPasswordView extends ConsumerStatefulWidget {
  const AppPasswordView({
    super.key,
    required this.title,
    required this.message,
    required this.onUnlocked,
    this.allowBiometric = true,
    this.autoBiometric = false,
    this.persistBiometricAcrossBackgrounding = false,
    this.secondaryAction,
  });

  final String title;

  /// 标题下的说明（多为验证原因，如“请验证身份以打开「旅行」”）。
  final String message;

  final VoidCallback onUnlocked;

  /// 是否提供“使用指纹或面容”（敏感操作只认密码时为 false）。
  final bool allowBiometric;

  /// 开场时自动弹一次指纹（冷启动的应用锁）。
  final bool autoBiometric;

  /// 指纹验证中途切到后台再回来时是否继续（应用锁需要）。
  final bool persistBiometricAcrossBackgrounding;

  /// 放在最下面的次要操作（如“回到全部日记”）。
  final Widget? secondaryAction;

  @override
  ConsumerState<AppPasswordView> createState() => _AppPasswordViewState();
}

class _AppPasswordViewState extends ConsumerState<AppPasswordView> {
  late final IdentityVerifier _verifier = ref.read(identityVerifierProvider);
  late final AppPasswordUnlockController _controller =
      AppPasswordUnlockController(
        loadStore: _verifier.store,
        clock: ref.read(appPasswordClockProvider),
      );
  final FocusNode _focusNode = FocusNode(debugLabel: 'app password');
  final RouteEntranceWaiter _entrance = RouteEntranceWaiter();
  bool _biometricAvailable = false;
  bool _biometricRunning = false;
  bool _forgotExpanded = false;
  int _handledShakes = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    _entrance.schedule(this, () => unawaited(_start()));
  }

  @override
  void dispose() {
    _entrance.dispose();
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    await _controller.restoreLockout();
    final biometric =
        widget.allowBiometric && await _verifier.biometricShortcutAvailable();
    if (!mounted) return;
    setState(() => _biometricAvailable = biometric);
    if (biometric && widget.autoBiometric) {
      await _runBiometric();
      if (!mounted || _controller.unlocked) return;
    }
    if (_controller.inputEnabled) {
      _focusNode.requestFocus();
    }
  }

  Future<void> _runBiometric() async {
    if (_biometricRunning || _controller.unlocked) return;
    setState(() => _biometricRunning = true);
    final passed = await _verifier.authenticateBiometric(
      reason: widget.message,
      persistAcrossBackgrounding: widget.persistBiometricAcrossBackgrounding,
    );
    if (!mounted) return;
    setState(() => _biometricRunning = false);
    if (passed) {
      _controller.markUnlocked();
    }
  }

  Future<void> _submit() async {
    await _controller.submit();
  }

  void _handleControllerChanged() {
    if (_controller.shakeCount != _handledShakes) {
      _handledShakes = _controller.shakeCount;
      unawaited(HapticFeedback.errorNotification());
    }
    if (_controller.unlocked) {
      _controller.removeListener(_handleControllerChanged);
      _focusNode.unfocus();
      unawaited(_finishUnlock());
    }
    if (mounted) setState(() {});
  }

  Future<void> _finishUnlock() async {
    final delay = ExpressiveMotion.duration(context, ExpressiveMotion.fast);
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (mounted) widget.onUnlocked();
  }

  String? _statusText(AppLocalizations l10n) {
    switch (_controller.error) {
      case AppPasswordUnlockError.none:
        return null;
      case AppPasswordUnlockError.wrong:
        final left = _controller.attemptsLeft;
        return left <= 2
            ? l10n.appPasswordWrongAttemptsLeft(left)
            : l10n.appPasswordWrong;
      case AppPasswordUnlockError.lockedOut:
        final seconds = _controller.lockoutSeconds;
        return seconds < 60
            ? l10n.appPasswordLockedOutSeconds(seconds)
            : l10n.appPasswordLockedOutMinutes((seconds / 60).ceil());
      case AppPasswordUnlockError.unavailable:
        return l10n.appPasswordUnavailable;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final controller = _controller;
    final showsError =
        controller.error == AppPasswordUnlockError.wrong ||
        controller.error == AppPasswordUnlockError.lockedOut;
    final status = _statusText(l10n);
    final buttonTextStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );
    return CenteredContent(
      maxWidth: AppContentWidth.prompt,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: AppLockEmblem(
                icon: controller.unlocked
                    ? FontAwesomeIcons.lockOpen
                    : FontAwesomeIcons.lock,
                error: showsError,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.s),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            AppPasswordShake(
              trigger: controller.shakeCount,
              child: AppPasswordField(
                controller: controller.text,
                focusNode: _focusNode,
                enabled: !controller.lockedOut && !controller.unlocked,
                readOnly: controller.checking,
                error: showsError,
                hintText: l10n.appPasswordHint,
                onSubmitted: () => unawaited(_submit()),
              ),
            ),
            AppPasswordStatusLine(text: status, error: showsError),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: controller.canSubmit
                    ? () => unawaited(_submit())
                    : null,
                style: FilledButton.styleFrom(textStyle: buttonTextStyle),
                child: controller.checking
                    ? ExpressiveLoadingIndicator(
                        size: 28,
                        semanticLabel: l10n.appLockUnlocking,
                      )
                    : Text(l10n.appPasswordUnlock),
              ),
            ),
            if (_biometricAvailable) ...<Widget>[
              const SizedBox(height: AppSpacing.m),
              SizedBox(
                height: 52,
                child: FilledButton.tonalIcon(
                  style:
                      AppGlassField.tonalButtonStyle(context)?.merge(
                        FilledButton.styleFrom(textStyle: buttonTextStyle),
                      ) ??
                      FilledButton.styleFrom(textStyle: buttonTextStyle),
                  onPressed: _biometricRunning || controller.unlocked
                      ? null
                      : () => unawaited(_runBiometric()),
                  icon: const FaIcon(FontAwesomeIcons.fingerprint, size: 16),
                  label: Text(l10n.appPasswordUseBiometric),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s),
            _ForgotPassword(
              expanded: _forgotExpanded,
              onToggle: () =>
                  setState(() => _forgotExpanded = !_forgotExpanded),
            ),
            ?widget.secondaryAction,
          ],
        ),
      ),
    );
  }
}

/// “忘记密码？”：应用密码无法找回，点按在原地展开说明。
class _ForgotPassword extends StatelessWidget {
  const _ForgotPassword({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: TextButton(
            onPressed: onToggle,
            child: Text(l10n.appPasswordForgot),
          ),
        ),
        AnimatedSize(
          duration: ExpressiveMotion.durationNonZero(
            context,
            ExpressiveMotion.medium,
          ),
          curve: ExpressiveMotion.effects,
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s),
                  child: Text(
                    l10n.appPasswordForgotMessage,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
