// 应用锁设置页的上锁时机与隐私选项（DESIGN.md §5.31）。
//
// - 输入：当前 [AppLockOptions]、改动回调（由页面经 `AppLockSettingsFlow`
//   在放宽保护时先验证再保存）；
// - 输出：开关与选择面板的结果；
// - 副作用：无（只打开选择面板）。
//
// 平台差异只经 `AppPlatform`：“锁屏时上锁”与“防截屏”只在 Android，
// “闲置时上锁”只在桌面。

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_platform.dart';
import '../../settings/widgets/settings_card_group.dart';
import '../../settings/widgets/settings_option_tiles.dart';
import '../../settings/widgets/settings_reveal.dart';
import '../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../widgets/expressive_choice_tile.dart';
import '../models/app_lock_options.dart';

/// “离开应用后上锁”的选项文字。
String appLockAfterLeavingLabel(
  AppLocalizations l10n,
  AppLockAfterLeaving value,
) {
  final after = value.after;
  if (after == null) return l10n.appLockAfterLeavingNever;
  if (after == Duration.zero) return l10n.appLockDelayImmediately;
  if (after.inMinutes >= 60) return l10n.appLockDelayHours(after.inHours);
  return l10n.appLockDelayMinutes(after.inMinutes);
}

/// “闲置时上锁”的选项文字。
String appLockWhenIdleLabel(AppLocalizations l10n, AppLockWhenIdle value) {
  final after = value.after;
  if (after == null) return l10n.appLockWhenIdleOff;
  return l10n.appLockDelayMinutes(after.inMinutes);
}

/// 挂在“应用锁”开关下面的从属行：开关打开时经 [SettingsReveal] 展开。
/// 与开关合成分组里的同一项（见 [SettingsReveal] 的说明）。
class AppLockTriggerOptions extends StatelessWidget {
  const AppLockTriggerOptions({
    super.key,
    required this.visible,
    required this.options,
    required this.onChanged,
  });

  final bool visible;
  final AppLockOptions options;
  final ValueChanged<AppLockOptions> onChanged;

  Future<void> _pickAfterLeaving(BuildContext context) async {
    final l10n = context.l10n;
    final picked = await _showAppLockChoiceSheet<AppLockAfterLeaving>(
      context,
      title: l10n.appLockAfterLeaving,
      hint: l10n.appLockAfterLeavingHint,
      values: AppLockAfterLeaving.values,
      selected: options.afterLeaving,
      labelOf: (AppLockAfterLeaving value) =>
          appLockAfterLeavingLabel(l10n, value),
    );
    if (picked != null && picked != options.afterLeaving) {
      onChanged(options.copyWith(afterLeaving: picked));
    }
  }

  Future<void> _pickWhenIdle(BuildContext context) async {
    final l10n = context.l10n;
    final picked = await _showAppLockChoiceSheet<AppLockWhenIdle>(
      context,
      title: l10n.appLockWhenIdle,
      hint: l10n.appLockWhenIdleHint,
      values: AppLockWhenIdle.values,
      selected: options.whenIdle,
      labelOf: (AppLockWhenIdle value) => appLockWhenIdleLabel(l10n, value),
    );
    if (picked != null && picked != options.whenIdle) {
      onChanged(options.copyWith(whenIdle: picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = <Widget>[
      _NestedValueTile(
        title: l10n.appLockAfterLeaving,
        value: appLockAfterLeavingLabel(l10n, options.afterLeaving),
        onTap: () => _pickAfterLeaving(context),
      ),
      if (AppPlatform.supportsScreenOffLock)
        SettingsSwitchTile(
          nested: true,
          title: l10n.appLockOnScreenOff,
          subtitle: l10n.appLockOnScreenOffSubtitle,
          value: options.onScreenOff,
          onChanged: (bool value) =>
              onChanged(options.copyWith(onScreenOff: value)),
        ),
      if (AppPlatform.supportsIdleLock)
        _NestedValueTile(
          title: l10n.appLockWhenIdle,
          value: appLockWhenIdleLabel(l10n, options.whenIdle),
          onTap: () => _pickWhenIdle(context),
        ),
      SettingsSwitchTile(
        nested: true,
        title: l10n.appLockAutoPrompt,
        subtitle: l10n.appLockAutoPromptSubtitle,
        value: options.autoPrompt,
        onChanged: (bool value) =>
            onChanged(options.copyWith(autoPrompt: value)),
      ),
    ];
    return SettingsReveal(
      visible: visible,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final row in rows) ...<Widget>[settingsNestedDivider, row],
        ],
      ),
    );
  }
}

/// “隐私”分组：防截屏（只在 Android，其他平台不显示整组）。与应用锁开关
/// 无关，没开应用锁也能单独打开。
class AppLockPrivacyGroup extends StatelessWidget {
  const AppLockPrivacyGroup({
    super.key,
    required this.options,
    required this.onChanged,
  });

  final AppLockOptions options;
  final ValueChanged<AppLockOptions> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!AppPlatform.supportsSecureScreen) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SettingsCardGroup(
        title: l10n.appLockPrivacyTitle,
        children: <Widget>[
          SettingsSwitchTile(
            title: l10n.appLockSecureScreen,
            subtitle: l10n.appLockSecureScreenSubtitle,
            value: options.secureScreen,
            onChanged: (bool value) =>
                onChanged(options.copyWith(secureScreen: value)),
          ),
        ],
      ),
    );
  }
}

/// 从属的“标题 + 当前值 + 箭头”行，点按打开选择面板。缩进与字阶同
/// [SettingsSwitchTile] 的从属行。
class _NestedValueTile extends StatelessWidget {
  const _NestedValueTile({
    required this.title,
    required this.value,
    required this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(
        start: SettingsSwitchTile.nestedIndent,
        end: 16,
        top: 2,
        bottom: 2,
      ),
      title: Text(title, style: SettingsSwitchTile.nestedTitleStyle),
      subtitle: Text(value),
      trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
      onTap: onTap,
    );
  }
}

/// 单选面板：标题、说明与各选项（[ExpressiveChoiceTile]），点一项即返回它，
/// 关闭返回 null。
Future<T?> _showAppLockChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required String hint,
  required List<T> values,
  required T selected,
  required String Function(T value) labelOf,
}) {
  return showAppModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 640),
    sheetAnimationStyle: ExpressiveMotion.reduceMotion(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (BuildContext sheetContext) {
      final theme = Theme.of(sheetContext);
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.l,
          0,
          AppSpacing.l,
          AppSpacing.l + MediaQuery.paddingOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.xs,
                end: AppSpacing.xs,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.xs,
                AppSpacing.s,
                AppSpacing.xs,
                AppSpacing.m,
              ),
              child: Text(
                hint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
            for (final value in values)
              ExpressiveChoiceTile(
                label: labelOf(value),
                selected: value == selected,
                onTap: () => Navigator.of(sheetContext).pop(value),
              ),
          ],
        ),
      );
    },
  );
}
