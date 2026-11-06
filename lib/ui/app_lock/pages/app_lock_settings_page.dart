import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../core/services/app_passcode/app_passcode_store.dart';
import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../../core/services/settings_service.dart';
import '../../app_surface/models/app_surface_enums.dart';
import '../../app_surface/widgets/app_page_background.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_reveal.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/expressive_choice_tile.dart';
import '../../widgets/form_width.dart';
import '../controllers/app_lock_settings_flow.dart';
import '../controllers/identity_verifier.dart';

/// 设置 → 数据与隐私 → 应用锁与密码（DESIGN.md §5.31）。
///
/// 页面只装配：开关与选项的改动经 [AppLockSettingsFlow]（先验证再改）。
///
/// - 应用锁：开关；这台设备不能上锁（Linux 且没设应用密码）时停用并说明；
/// - 验证方式：系统验证 / 应用密码两个单选项，脚注说明三处共用；没有系统
///   验证的平台（Linux）“系统验证”不可选；
/// - 应用密码方式下，单选项下方多出“修改应用密码”与“指纹 / 面容解锁”
///   （设备有生物识别时），整块经 [SettingsReveal] 展开 / 收起，左侧缩进与
///   选项文字对齐，视觉上从属于“应用密码”这一项。
class AppLockSettingsPage extends ConsumerStatefulWidget {
  const AppLockSettingsPage({super.key});

  @override
  ConsumerState<AppLockSettingsPage> createState() =>
      _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends ConsumerState<AppLockSettingsPage> {
  late final AppLockSettingsFlow _flow = AppLockSettingsFlow(ref);
  bool _hasBiometrics = false;

  /// 一次只进行一个操作（验证、设置密码都要等用户），连点不会叠两层。
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBiometrics());
  }

  Future<void> _loadBiometrics() async {
    final has = await ref.read(identityVerifierProvider).deviceHasBiometrics();
    if (mounted && has != _hasBiometrics) {
      setState(() => _hasBiometrics = has);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    try {
      await action();
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    final config = ref.watch(appPasscodeConfigProvider);
    return AppPageBackground(
      area: AppBackgroundArea.settings,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            contentMaxWidth: FormWidth.maxWidth,
            title: Text(l10n.settingsAppLockAndPasscode),
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
          ),
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final side = FormWidth.extra(constraints.maxWidth);
              return ListView(
                padding: EdgeInsets.fromLTRB(side, 12, side, 24),
                children: <Widget>[
                  SettingsCardGroup(
                    children: <Widget>[
                      _AppLockSwitch(
                        settings: settings,
                        canLock: identityVerificationPossible(config),
                        onChanged: (bool value) => _run(
                          () => _flow.setAppLockEnabled(
                            context,
                            settings!,
                            value,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SettingsCardGroup(
                    title: l10n.appLockMethodTitle,
                    footer: l10n.appLockMethodFooter,
                    children: <Widget>[
                      _MethodChoices(
                        config: config,
                        hasBiometrics: _hasBiometrics,
                        onSystem: () =>
                            _run(() => _flow.switchToSystem(context)),
                        onPasscode: () =>
                            _run(() => _flow.switchToPasscode(context)),
                        onChangePasscode: () =>
                            _run(() => _flow.changePasscode(context)),
                        onBiometric: (bool value) =>
                            _run(() => _flow.setBiometric(context, value)),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 应用锁开关；设置服务未就绪时只显示标题。
class _AppLockSwitch extends StatelessWidget {
  const _AppLockSwitch({
    required this.settings,
    required this.canLock,
    required this.onChanged,
  });

  final SettingsService? settings;
  final bool canLock;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const padding = EdgeInsets.symmetric(horizontal: 16, vertical: 4);
    final settings = this.settings;
    if (settings == null) {
      return ListTile(
        contentPadding: padding,
        title: Text(l10n.settingsAppLock),
        subtitle: Text(l10n.settingsAppLockSubtitle),
      );
    }
    return ValueListenableBuilder<bool>(
      valueListenable: settings.appLockEnabledNotifier,
      builder: (BuildContext context, bool enabled, Widget? child) {
        // 不能上锁时开关停用并说明；已开启的锁由启动时的应用锁逻辑自动解除。
        return SwitchListTile(
          contentPadding: padding,
          value: canLock && enabled,
          title: Text(l10n.settingsAppLock),
          subtitle: Text(
            canLock ? l10n.settingsAppLockSubtitle : l10n.appLockNeedsPasscode,
          ),
          onChanged: canLock ? onChanged : null,
        );
      },
    );
  }
}

/// 验证方式的两个单选项，以及应用密码方式下的从属设置。
class _MethodChoices extends StatelessWidget {
  const _MethodChoices({
    required this.config,
    required this.hasBiometrics,
    required this.onSystem,
    required this.onPasscode,
    required this.onChangePasscode,
    required this.onBiometric,
  });

  final AppPasscodeConfig config;
  final bool hasBiometrics;
  final VoidCallback onSystem;
  final VoidCallback onPasscode;
  final VoidCallback onChangePasscode;
  final ValueChanged<bool> onBiometric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final passcode = config.hasPasscode;
    final systemAvailable = AppPlatform.supportsDeviceAuth;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ExpressiveChoiceTile(
            label: l10n.appLockMethodSystem,
            description: systemAvailable
                ? l10n.appLockMethodSystemDescription
                : l10n.appLockMethodSystemUnavailable,
            selected: !passcode,
            onTap: !systemAvailable ? null : (passcode ? onSystem : () {}),
          ),
          ExpressiveChoiceTile(
            label: l10n.appLockMethodPasscode,
            description: l10n.appLockMethodPasscodeDescription,
            selected: passcode,
            onTap: passcode ? () {} : onPasscode,
          ),
          SettingsReveal(
            visible: passcode,
            child: _PasscodeOptions(
              config: config,
              hasBiometrics: hasBiometrics,
              onChangePasscode: onChangePasscode,
              onBiometric: onBiometric,
            ),
          ),
        ],
      ),
    );
  }
}

/// 从属于“应用密码”的两项：左侧缩进与选项文字对齐，表明它们属于上面那一项。
class _PasscodeOptions extends StatelessWidget {
  const _PasscodeOptions({
    required this.config,
    required this.hasBiometrics,
    required this.onChangePasscode,
    required this.onBiometric,
  });

  final AppPasscodeConfig config;
  final bool hasBiometrics;
  final VoidCallback onChangePasscode;
  final ValueChanged<bool> onBiometric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const padding = EdgeInsetsDirectional.only(start: 56, end: 12);
    final form = config.kind == AppPasscodeKind.pattern
        ? l10n.passcodeFormPattern
        : l10n.passcodeFormPin(config.pinLength);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ListTile(
          contentPadding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(l10n.passcodeChangeTitle),
          subtitle: Text(l10n.passcodeCurrentForm(form)),
          trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
          onTap: onChangePasscode,
        ),
        // 设备有没有指纹是异步读出的：读到后展开，不在一帧里突然出现。
        SettingsReveal(
          visible: hasBiometrics,
          child: SwitchListTile(
            contentPadding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            value: config.biometric,
            title: Text(l10n.passcodeBiometric),
            subtitle: Text(l10n.passcodeBiometricSubtitle),
            onChanged: onBiometric,
          ),
        ),
      ],
    );
  }
}
