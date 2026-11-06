import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_passcode/app_passcode_store.dart';
import '../../widgets/expressive_loading_indicator.dart';
import 'app_lock_surface.dart';
import 'passcode_unlock_view.dart';

/// 应用锁遮罩（盖在应用之上，何时盖上见 `AppLockController`）。
///
/// 按验证方式显示两种内容，切换时淡入淡出：
/// - 应用密码（设了密码且不在判断中）：[PasscodeUnlockView]，开着
///   [autoPrompt] 时开场自动弹一次指纹（开着且可用时），通过后调用
///   [onPasscodeUnlocked]；
/// - 系统验证：锁图标、说明，验证进行中显示加载指示，取消、失败或没有自动
///   弹出验证时给出“立即解锁”（改版前的样子，逐像素不变）。
///
/// 应用启动时先进入“判断中”（[unlocking]）：读出验证方式之前显示加载指示，
/// 判断为应用密码后由调用方结束判断，换成密码输入。
class AppLockOverlay extends ConsumerWidget {
  const AppLockOverlay({
    super.key,
    required this.unlocking,
    this.autoPrompt = true,
    required this.onTapUnlock,
    required this.onPasscodeUnlocked,
  });

  /// 正在判断验证方式或正在进行系统验证。
  final bool unlocking;

  /// 应用密码方式下开场是否自动弹指纹（“自动弹出验证”）。
  final bool autoPrompt;
  final VoidCallback onTapUnlock;
  final VoidCallback onPasscodeUnlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passcode = ref.watch(
      appPasscodeConfigProvider.select((config) => config.hasPasscode),
    );
    final l10n = context.l10n;
    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.fast),
      switchInCurve: ExpressiveMotion.effects,
      switchOutCurve: ExpressiveMotion.exit,
      child: passcode && !unlocking
          ? AppLockSurface(
              key: const ValueKey<String>('app_lock_passcode'),
              builder: (BuildContext context, double viewportHeight) =>
                  PasscodeUnlockView(
                    title: l10n.appLockTitle,
                    message: l10n.appLockPasscodeSubtitle,
                    autoBiometric: autoPrompt,
                    persistBiometricAcrossBackgrounding: true,
                    onUnlocked: onPasscodeUnlocked,
                    viewportHeight: viewportHeight,
                  ),
            )
          : _SystemLockOverlay(
              key: const ValueKey<String>('app_lock_system'),
              unlocking: unlocking,
              onTapUnlock: onTapUnlock,
            ),
    );
  }
}

/// 系统验证方式的遮罩。
///
/// 设计目标：
/// - 在应用锁开启时阻断所有交互；
/// - 自动解锁中给出统一 loading 反馈；
/// - 解锁失败后提供明确的手动重试入口。
class _SystemLockOverlay extends StatelessWidget {
  const _SystemLockOverlay({
    super.key,
    required this.unlocking,
    required this.onTapUnlock,
  });

  final bool unlocking;
  final VoidCallback onTapUnlock;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return ColoredBox(
      color: colorScheme.surface.withValues(alpha: 0.98),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                FaIcon(
                  FontAwesomeIcons.lock,
                  size: 28,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.appLockTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.appLockSubtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                // 固定高度的槽位：取消生物识别后 64dp 指示器换回 48dp 按钮时
                // 整块不再跳动，两者之间淡入淡出。
                SizedBox(
                  height: 64,
                  child: AnimatedSwitcher(
                    duration: ExpressiveMotion.duration(
                      context,
                      ExpressiveMotion.fast,
                    ),
                    switchInCurve: ExpressiveMotion.effects,
                    switchOutCurve: ExpressiveMotion.exit,
                    child: unlocking
                        ? ExpressiveLoadingIndicator(
                            key: const ValueKey<String>('unlocking'),
                            size: 64,
                            semanticLabel: l10n.appLockUnlocking,
                          )
                        : Center(
                            key: const ValueKey<String>('unlock'),
                            child: FilledButton.icon(
                              onPressed: onTapUnlock,
                              icon: const FaIcon(
                                FontAwesomeIcons.key,
                                size: 14,
                              ),
                              label: Text(l10n.appLockUnlockNow),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
