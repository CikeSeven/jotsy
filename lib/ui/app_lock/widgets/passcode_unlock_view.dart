// 应用密码的解锁视图（DESIGN.md §5.31）：冷启动的应用锁遮罩、上锁日记本的
// 重锁遮罩与 `PasscodeVerifyPage` 共用。
//
// - 输入：标题与说明、是否允许 / 自动弹出指纹、解锁回调、可选的次要操作、
//   可见高度（给键盘挑尺寸）；
// - 输出：验证通过时调用 [PasscodeUnlockView.onUnlocked]；
// - 副作用：核对密码（写输错记录）、弹指纹验证、输错时触觉反馈。
//
// 布局（居中竖列，最大宽度 `AppContentWidth.prompt`）：徽章 → 标题与说明 →
// 输入区（数字：圆点 + 提示行 + 键盘；图案：提示行 + 图案板）→ “忘记密码？”
// → 次要操作。
//
// 开场顺序（经 RouteEntranceWaiter：在路由里等入场结束，遮罩里下一帧即开始）：
// 1. 读出形式、位数与是否仍在等待（上次输错太多次）；
// 2. 允许自动弹指纹且可用时先弹一次：通过即解锁，取消就停在键盘 / 图案上。
//
// 通过后徽章先换成开锁，`fast` 之后再交给调用方揭开遮罩或关闭页面，开锁的
// 那一下看得见；减少动画时立即回调。
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
import '../../../core/services/app_passcode/app_passcode_store.dart';
import '../../widgets/route_entrance_waiter.dart';
import '../controllers/identity_verifier.dart';
import '../controllers/passcode_entry_controller.dart';
import 'app_lock_emblem.dart';
import 'passcode_feedback.dart';
import 'passcode_input.dart';

class PasscodeUnlockView extends ConsumerStatefulWidget {
  const PasscodeUnlockView({
    super.key,
    required this.message,
    required this.onUnlocked,
    this.title,
    this.allowBiometric = true,
    this.autoBiometric = false,
    this.persistBiometricAcrossBackgrounding = false,
    this.secondaryAction,
    this.viewportHeight = double.infinity,
  });

  /// 标题；null 时按形式取“输入应用密码 / 绘制解锁图案”。
  final String? title;

  /// 标题下的说明（多为验证原因，如“请验证身份以打开「旅行」”）。
  final String message;

  final VoidCallback onUnlocked;

  /// 是否提供“使用指纹或面容”（敏感操作只认密码时为 false）。
  final bool allowBiometric;

  /// 开场时自动弹一次指纹（冷启动的应用锁、验证页）。
  final bool autoBiometric;

  /// 指纹验证中途切到后台再回来时是否继续（应用锁需要）。
  final bool persistBiometricAcrossBackgrounding;

  /// 放在最下面的次要操作（如“回到全部日记”）。
  final Widget? secondaryAction;

  final double viewportHeight;

  @override
  ConsumerState<PasscodeUnlockView> createState() => _PasscodeUnlockViewState();
}

class _PasscodeUnlockViewState extends ConsumerState<PasscodeUnlockView> {
  late final IdentityVerifier _verifier = ref.read(identityVerifierProvider);
  late final PasscodeEntryController _controller = () {
    final config = ref.read(appPasscodeConfigProvider);
    return PasscodeEntryController(
      loadStore: _verifier.store,
      clock: ref.read(appPasscodeClockProvider),
      initialKind: config.kind,
      initialPinLength: config.pinLength,
    );
  }();
  final RouteEntranceWaiter _entrance = RouteEntranceWaiter();
  bool _biometricAvailable = false;
  bool _biometricRunning = false;
  bool _forgotExpanded = false;
  bool _finishing = false;
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
    super.dispose();
  }

  Future<void> _start() async {
    await _controller.start();
    final biometric =
        widget.allowBiometric && await _verifier.biometricShortcutAvailable();
    if (!mounted) return;
    setState(() => _biometricAvailable = biometric);
    if (biometric && widget.autoBiometric) {
      await _runBiometric();
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

  void _handleControllerChanged() {
    if (_controller.shakeCount != _handledShakes) {
      _handledShakes = _controller.shakeCount;
      unawaited(HapticFeedback.errorNotification());
    }
    if (_controller.unlocked && !_finishing) {
      _finishing = true;
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
    final controller = _controller;
    switch (controller.error) {
      case PasscodeEntryError.none:
        return null;
      case PasscodeEntryError.wrong:
        final left = controller.attemptsLeft;
        if (left <= 2) return l10n.passcodeWrongAttemptsLeft(left);
        return controller.kind == AppPasscodeKind.pin
            ? l10n.passcodeWrongPin
            : l10n.passcodeWrongPattern;
      case PasscodeEntryError.tooShort:
        return l10n.passcodePatternTooShort(AppPasscodeRules.patternMinNodes);
      case PasscodeEntryError.lockedOut:
        final seconds = controller.lockoutSeconds;
        return seconds < 60
            ? l10n.passcodeLockedOutSeconds(seconds)
            : l10n.passcodeLockedOutMinutes((seconds / 60).ceil());
      case PasscodeEntryError.unavailable:
        return l10n.passcodeUnavailable;
    }
  }

  /// 输入区之外各部分的大致高度（徽章、标题说明、“忘记密码？”、次要操作与
  /// 间距），文字部分随字号缩放。
  double _reservedHeight(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final text = 112 + (widget.secondaryAction == null ? 0 : 40);
    return 64 + AppSpacing.xl + 8 + AppSpacing.xxl + 12 + text * textScale;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = _controller;
    final pin = controller.kind == AppPasscodeKind.pin;
    final showsError =
        controller.rejected || controller.error == PasscodeEntryError.lockedOut;
    final title =
        widget.title ??
        (pin ? l10n.passcodeEnterPinTitle : l10n.passcodeDrawPatternTitle);
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
            PasscodeHeader(title: title, message: widget.message),
            const SizedBox(height: AppSpacing.xxl),
            PasscodeInput(
              kind: controller.kind,
              pinLength: controller.pinLength,
              filled: controller.unlocked || controller.checking
                  ? controller.pinLength
                  : controller.filled,
              rejected: controller.rejected,
              enabled: controller.inputEnabled,
              shakeCount: controller.shakeCount,
              patternClears: controller.patternClears,
              status: _statusText(l10n),
              onDigit: controller.addDigit,
              onBackspace: controller.backspace,
              onClear: controller.clearDigits,
              onPatternStarted: controller.startPattern,
              onPatternCompleted: (List<int> nodes) =>
                  unawaited(controller.submitPattern(nodes)),
              onBiometric: _biometricAvailable
                  ? (_biometricRunning || controller.unlocked
                        ? () {}
                        : () => unawaited(_runBiometric()))
                  : null,
              viewportHeight: widget.viewportHeight,
              reservedHeight: _reservedHeight(context),
            ),
            const SizedBox(height: 12),
            _ForgotPasscode(
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
class _ForgotPasscode extends StatelessWidget {
  const _ForgotPasscode({required this.expanded, required this.onToggle});

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
            child: Text(l10n.passcodeForgot),
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
                    l10n.passcodeForgotMessage,
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
