// 设置 / 修改应用密码（DESIGN.md §5.31）。
//
// - 输入：是首次设置还是修改（[AppPasswordSetupPage.change]）；
// - 输出：写入成功返回 true，中途返回为 false；
// - 副作用：两次输入一致后经 `AppPasswordStore.setPassword` 写入（摘要在后台
//   isolate 计算，期间按钮转圈）。
//
// 两步：输入新密码 → 再输入一次。只换标题与说明（横向滑入 + 淡入），输入框
// 始终是同一个、焦点不丢，键盘不会收起再弹出。第二步与第一步不一致时退回
// 第一步并提示；第二步按返回也是回到第一步。
//
// 调用方负责“改之前先验证身份”（见 `AppLockSettingsFlow`）：这一页只管输入。

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
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/expressive_loading_indicator.dart';
import '../../widgets/route_entrance_waiter.dart';
import '../controllers/identity_verifier.dart';
import '../widgets/app_lock_emblem.dart';
import '../widgets/app_lock_surface.dart';
import '../widgets/app_password_field.dart';

class AppPasswordSetupPage extends ConsumerStatefulWidget {
  const AppPasswordSetupPage({super.key, this.change = false});

  /// 修改已有的密码（标题不同，保留指纹开关）。
  final bool change;

  static Future<bool> open(BuildContext context, {bool change = false}) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => AppPasswordSetupPage(change: change),
      ),
    );
    return done ?? false;
  }

  @override
  ConsumerState<AppPasswordSetupPage> createState() =>
      _AppPasswordSetupPageState();
}

enum _SetupError { none, tooShort, tooLong, whitespace, mismatch }

class _AppPasswordSetupPageState extends ConsumerState<AppPasswordSetupPage> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'new app password');
  final RouteEntranceWaiter _entrance = RouteEntranceWaiter();

  /// 第一步输入的密码；null 表示还在第一步。
  String? _first;
  _SetupError _error = _SetupError.none;
  int _shakeCount = 0;
  bool _saving = false;

  bool get _confirming => _first != null;

  @override
  void initState() {
    super.initState();
    _text.addListener(_handleTextChanged);
    _entrance.schedule(this, _focusNode.requestFocus);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _text.removeListener(_handleTextChanged);
    _text.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    // 重新输入时收起上一次的提示（第一步的规则提示、不一致提示）。
    if (_text.text.isNotEmpty && _error != _SetupError.none) {
      setState(() => _error = _SetupError.none);
    } else {
      setState(() {});
    }
  }

  void _fail(_SetupError error) {
    unawaited(HapticFeedback.errorNotification());
    setState(() {
      _error = error;
      _shakeCount++;
    });
  }

  Future<void> _next() async {
    if (_saving || _text.text.isEmpty) return;
    final value = _text.text;
    final first = _first;
    if (first == null) {
      final problem = AppPasswordRules.check(value);
      if (problem != null) {
        _fail(switch (problem) {
          AppPasswordProblem.tooShort => _SetupError.tooShort,
          AppPasswordProblem.tooLong => _SetupError.tooLong,
          AppPasswordProblem.whitespace => _SetupError.whitespace,
        });
        return;
      }
      setState(() => _first = value);
      _text.clear();
      _focusNode.requestFocus();
      return;
    }
    if (value != first) {
      _text.clear();
      setState(() => _first = null);
      _fail(_SetupError.mismatch);
      _focusNode.requestFocus();
      return;
    }
    setState(() => _saving = true);
    final verifier = ref.read(identityVerifierProvider);
    final store = await verifier.store();
    final biometric = widget.change
        ? null
        : await verifier.deviceHasBiometrics();
    var saved = false;
    try {
      if (store != null) {
        await store.setPassword(value, biometric: biometric);
        saved = true;
      }
    } catch (_) {
      saved = false;
    }
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _saving = false);
  }

  /// 第二步按返回：回到第一步而不是离开页面。
  void _handlePop(bool didPop, Object? result) {
    if (didPop || !_confirming) return;
    _text.clear();
    setState(() {
      _first = null;
      _error = _SetupError.none;
    });
  }

  String? _errorText(AppLocalizations l10n) => switch (_error) {
    _SetupError.none => null,
    _SetupError.tooShort => l10n.appPasswordTooShort(
      AppPasswordRules.minLength,
    ),
    _SetupError.tooLong => l10n.appPasswordTooLong(AppPasswordRules.maxLength),
    _SetupError.whitespace => l10n.appPasswordWhitespace,
    _SetupError.mismatch => l10n.appPasswordMismatch,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = context.l10n;
    final error = _errorText(l10n);
    final title = _confirming
        ? l10n.appPasswordConfirmTitle
        : l10n.appPasswordNewTitle;
    final subtitle = _confirming
        ? l10n.appPasswordConfirmSubtitle
        : l10n.appPasswordRulesHint(
            AppPasswordRules.minLength,
            AppPasswordRules.maxLength,
          );
    return PopScope<Object?>(
      canPop: !_confirming && !_saving,
      onPopInvokedWithResult: _handlePop,
      child: AppPageBackground(
        area: AppBackgroundArea.settings,
        child: Builder(
          builder: (BuildContext context) => Scaffold(
            backgroundColor: AppPageBackdrop.pageColorOf(context),
            appBar: AppTopBar(
              contentMaxWidth: AppContentWidth.prompt,
              title: Text(
                widget.change
                    ? l10n.appPasswordChangeTitle
                    : l10n.appPasswordSetupTitle,
              ),
              leading: IconButton(
                tooltip: l10n.commonBack,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
              ),
            ),
            body: AppLockScrollBody(
              child: CenteredContent(
                maxWidth: AppContentWidth.prompt,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Center(
                        child: AppLockEmblem(
                          icon: _confirming
                              ? FontAwesomeIcons.shieldHalved
                              : FontAwesomeIcons.key,
                          error: _error == _SetupError.mismatch,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      _StepHeader(
                        step: _confirming ? 1 : 0,
                        title: title,
                        subtitle: subtitle,
                      ),
                      const SizedBox(height: 28),
                      AppPasswordShake(
                        trigger: _shakeCount,
                        child: AppPasswordField(
                          controller: _text,
                          focusNode: _focusNode,
                          readOnly: _saving,
                          error: error != null,
                          hintText: l10n.appPasswordHint,
                          onSubmitted: () => unawaited(_next()),
                        ),
                      ),
                      AppPasswordStatusLine(text: error),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _saving || _text.text.isEmpty
                              ? null
                              : () => unawaited(_next()),
                          style: FilledButton.styleFrom(
                            textStyle: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: _saving
                              ? const ExpressiveLoadingIndicator(size: 28)
                              : Text(
                                  _confirming
                                      ? l10n.appPasswordDone
                                      : l10n.appPasswordNext,
                                ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.l),
                      _NoRecoveryNote(scheme: scheme),
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

/// 步骤标题与说明：换步时新的一行从右侧滑入并淡入，旧的一行向左滑出淡出。
class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.title,
    required this.subtitle,
  });

  final int step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      switchInCurve: ExpressiveMotion.effects,
      switchOutCurve: ExpressiveMotion.exit,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final entering = child.key == ValueKey<int>(step);
        final from = Offset(entering ? 0.12 : -0.12, 0);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(
              Tween<Offset>(
                begin: from,
                end: Offset.zero,
              ).chain(CurveTween(curve: ExpressiveMotion.spatial)),
            ),
            child: child,
          ),
        );
      },
      child: Column(
        key: ValueKey<int>(step),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.s),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// “无法找回”的说明块：secondaryContainer 底、circleInfo 图标。
class _NoRecoveryNote extends StatelessWidget {
  const _NoRecoveryNote({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: FaIcon(
                FontAwesomeIcons.circleInfo,
                size: 16,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: AppSpacing.m),
            Expanded(
              child: Text(
                context.l10n.appPasswordNoRecoveryNote,
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
