import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_breakpoints.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_passcode/app_passcode_store.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/expressive_button_group.dart';
import '../controllers/identity_verifier.dart';
import '../controllers/passcode_setup_controller.dart';
import '../models/passcode_form.dart';
import '../widgets/app_lock_surface.dart';
import '../widgets/passcode_feedback.dart';
import '../widgets/passcode_input.dart';

/// 设置 / 修改应用密码（DESIGN.md §5.31），两步见 [PasscodeSetupController]。
///
/// 页面只装配：顶部单选按钮组选形式（6 位数字 / 4 位数字 / 图案，只在第一步
/// 可改）→ 标题与说明（换步时滑入）→ 输入区 → 底部“无法找回”的说明块。
/// 第二步按返回（含系统返回）回到第一步而不是离开页面；保存中不能返回。
///
/// 首次设置时指纹快捷解锁默认打开（设备有生物识别时），修改密码保留原来的
/// 开关。返回 true 表示已保存。
class PasscodeSetupPage extends ConsumerStatefulWidget {
  const PasscodeSetupPage({super.key, this.change = false});

  /// 修改密码（标题不同，默认选中原来的形式，保留指纹开关）。
  final bool change;

  static Future<bool> open(BuildContext context, {bool change = false}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => PasscodeSetupPage(change: change),
      ),
    );
    return saved ?? false;
  }

  @override
  ConsumerState<PasscodeSetupPage> createState() => _PasscodeSetupPageState();
}

class _PasscodeSetupPageState extends ConsumerState<PasscodeSetupPage> {
  late final PasscodeSetupController _controller = PasscodeSetupController(
    initialForm: widget.change
        ? PasscodeForm.of(ref.read(appPasscodeConfigProvider))
        : PasscodeForm.pin6,
    save: _save,
  );
  int _handledShakes = 0;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(PasscodeForm form, String value) async {
    final store = await ref.read(appPasscodeStoreProvider.future);
    final biometric = widget.change
        ? null
        : await ref.read(identityVerifierProvider).deviceHasBiometrics();
    if (form.kind == AppPasscodeKind.pin) {
      await store.setPin(value, biometric: biometric);
    } else {
      await store.setPattern(
        value.split('-').map(int.parse).toList(),
        biometric: biometric,
      );
    }
  }

  void _handleChanged() {
    if (_controller.shakeCount != _handledShakes) {
      _handledShakes = _controller.shakeCount;
      unawaited(HapticFeedback.errorNotification());
    }
    if (_controller.done && !_popped) {
      _popped = true;
      unawaited(HapticFeedback.successNotification());
      Navigator.of(context).pop(true);
      return;
    }
    if (mounted) setState(() {});
  }

  String _formLabel(AppLocalizations l10n, PasscodeForm form) => switch (form) {
    PasscodeForm.pin6 => l10n.passcodeFormPin(6),
    PasscodeForm.pin4 => l10n.passcodeFormPin(4),
    PasscodeForm.pattern => l10n.passcodeFormPattern,
  };

  (String, String) _header(AppLocalizations l10n) {
    final form = _controller.form;
    final pin = form.kind == AppPasscodeKind.pin;
    if (_controller.confirming) {
      return (
        pin ? l10n.passcodeConfirmPinTitle : l10n.passcodeConfirmPatternTitle,
        l10n.passcodeConfirmMessage,
      );
    }
    return pin
        ? (
            l10n.passcodeSetupPinTitle,
            l10n.passcodeSetupPinMessage(form.pinLength),
          )
        : (
            l10n.passcodeSetupPatternTitle,
            l10n.passcodeSetupPatternMessage(AppPasscodeRules.patternMinNodes),
          );
  }

  String? _status(AppLocalizations l10n) => switch (_controller.error) {
    PasscodeSetupError.none => null,
    PasscodeSetupError.tooShort => l10n.passcodePatternTooShort(
      AppPasscodeRules.patternMinNodes,
    ),
    PasscodeSetupError.mismatch => l10n.passcodeMismatch,
    PasscodeSetupError.saveFailed => l10n.passcodeSaveFailed,
  };

  /// 输入区之外的大致高度：按钮组、标题说明、说明块与间距，文字部分随字号
  /// 缩放。
  double _reservedHeight(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return 40 + AppSpacing.xl + AppSpacing.xxl + AppSpacing.l + 150 * textScale;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = _controller;
    final (title, message) = _header(l10n);
    return PopScope<Object?>(
      canPop: !controller.confirming && !controller.saving,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) controller.back();
      },
      child: AppPageBackground(
        area: AppBackgroundArea.settings,
        child: Builder(
          builder: (BuildContext context) => Scaffold(
            backgroundColor: AppPageBackdrop.pageColorOf(context),
            appBar: AppTopBar(
              contentMaxWidth: AppContentWidth.prompt,
              title: Text(
                widget.change
                    ? l10n.passcodeChangeTitle
                    : l10n.passcodeSetupTitle,
              ),
              leading: IconButton(
                tooltip: l10n.commonBack,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
              ),
            ),
            body: AppLockScrollBody(
              alignment: Alignment.topCenter,
              builder: (BuildContext context, double viewportHeight) =>
                  CenteredContent(
                    maxWidth: AppContentWidth.prompt,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xxl,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          // 第二步与保存中不能换形式，但保持选中的样子（停用
                          // 会把选中段也画成灰色，看不出在确认哪种形式），
                          // 只是不接受点按。
                          IgnorePointer(
                            ignoring:
                                controller.confirming ||
                                !controller.inputEnabled,
                            child: ExpressiveButtonGroup<PasscodeForm>(
                              minSegmentWidth: 88,
                              segments: <ButtonSegment<PasscodeForm>>[
                                for (final form in PasscodeForm.values)
                                  ButtonSegment<PasscodeForm>(
                                    value: form,
                                    label: Text(_formLabel(l10n, form)),
                                  ),
                              ],
                              selected: <PasscodeForm>{controller.form},
                              onSelectionChanged:
                                  (Set<PasscodeForm> selection) =>
                                      controller.selectForm(selection.first),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          PasscodeHeader(
                            switchKey: (controller.form, controller.step),
                            title: title,
                            message: message,
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          PasscodeInput(
                            kind: controller.form.kind,
                            pinLength: controller.form.pinLength,
                            filled: controller.saving
                                ? controller.form.pinLength
                                : controller.filled,
                            rejected: controller.rejected,
                            enabled: controller.inputEnabled,
                            shakeCount: controller.shakeCount,
                            patternClears: controller.patternClears,
                            status: _status(l10n),
                            dotsKey: (controller.form, controller.step),
                            onDigit: controller.addDigit,
                            onBackspace: controller.backspace,
                            onClear: controller.clearDigits,
                            onPatternStarted: controller.startPattern,
                            onPatternCompleted: (List<int> nodes) =>
                                unawaited(controller.submitPattern(nodes)),
                            viewportHeight: viewportHeight,
                            reservedHeight: _reservedHeight(context),
                          ),
                          const SizedBox(height: AppSpacing.l),
                          const _NoRecoveryNote(),
                        ],
                      ),
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// “无法找回”的说明块：`secondaryContainer` 底、`circleInfo` 图标。
class _NoRecoveryNote extends StatelessWidget {
  const _NoRecoveryNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: FaIcon(
                FontAwesomeIcons.circleInfo,
                size: 14,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text(
                context.l10n.passcodeNoRecoveryNote,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
