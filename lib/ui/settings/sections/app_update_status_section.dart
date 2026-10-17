import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/expressive_motion.dart';
import '../../../core/services/app_update_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/expressive_image_frame.dart';
import '../../widgets/expressive_loading_indicator.dart';
import '../models/app_update_state.dart';
import '../widgets/app_update_badge.dart';
import '../widgets/app_update_labels.dart';
import '../widgets/settings_card_group.dart';

/// 更新页顶部的状态卡片：应用图标、当前版本，以及按阶段切换的状态区
/// （检查中 / 已是最新 / 新版本信息 / 检查失败）。阶段之间 `fast` 交叉淡入，
/// 高度变化经 `AnimatedSize` 平滑过渡，减少动画时直接切换。
class AppUpdateStatusSection extends StatelessWidget {
  const AppUpdateStatusSection({super.key, required this.state});

  static const String _appIconAssetPath = 'assets/app_icon/mingcute_icon.png';

  final AppUpdateState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final l10n = context.l10n;
    final installed = state.installed;
    return SettingsCardGroup(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        _appIconAssetPath,
                        width: 42,
                        height: 42,
                        fit: BoxFit.cover,
                        frameBuilder: expressiveImageFrameBuilder,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.l),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Jotsy',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.appUpdateCurrentVersion(
                            installed == null
                                ? '--'
                                : appVersionLabel(installed.version),
                          ),
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.l),
              AnimatedSize(
                duration: ExpressiveMotion.durationNonZero(
                  context,
                  ExpressiveMotion.medium,
                ),
                curve: ExpressiveMotion.effects,
                alignment: Alignment.topCenter,
                child: AnimatedSwitcher(
                  duration: ExpressiveMotion.duration(
                    context,
                    ExpressiveMotion.fast,
                  ),
                  switchInCurve: ExpressiveMotion.effects,
                  switchOutCurve: ExpressiveMotion.exit,
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.topLeft,
                    children: <Widget>[...previous, ?current],
                  ),
                  child: KeyedSubtree(
                    key: ValueKey<_StatusView>(_viewFor(state)),
                    child: _buildStatus(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static _StatusView _viewFor(AppUpdateState state) {
    if (state.hasUpdate) {
      return _StatusView.available;
    }
    return switch (state.phase) {
      AppUpdatePhase.idle || AppUpdatePhase.checking => _StatusView.checking,
      AppUpdatePhase.upToDate => _StatusView.upToDate,
      _ => _StatusView.failed,
    };
  }

  Widget _buildStatus(BuildContext context) {
    final l10n = context.l10n;
    switch (_viewFor(state)) {
      case _StatusView.checking:
        return _StatusRow(
          leading: const ExpressiveLoadingIndicator(size: 32),
          title: l10n.appUpdateChecking,
          subtitle: l10n.appUpdateCheckingHint,
        );
      case _StatusView.upToDate:
        final checkedAt = state.checkedAt ?? state.preferences.lastCheckedAt;
        return _StatusRow(
          leading: _StatusIcon(
            icon: FontAwesomeIcons.circleCheck,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: l10n.appUpdateUpToDate,
          subtitle: checkedAt == null
              ? null
              : l10n.appUpdateLastChecked(
                  l10n.formatPreciseDateTime(checkedAt, DateTime.now()),
                ),
        );
      case _StatusView.failed:
        final failure = state.failure;
        return _StatusRow(
          leading: _StatusIcon(
            icon: FontAwesomeIcons.triangleExclamation,
            color: Theme.of(context).colorScheme.error,
          ),
          title: failure == null
              ? l10n.appUpdateFailedCheckTitle
              : appUpdateFailureTitle(l10n, failure),
          subtitle: appUpdateFailureMessage(
            l10n,
            failure?.kind ?? AppUpdateFailureKind.network,
          ),
        );
      case _StatusView.available:
        return _AvailableRelease(state: state);
    }
  }
}

enum _StatusView { checking, upToDate, available, failed }

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.leading, required this.title, this.subtitle});

  final Widget leading;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(width: 40, height: 40, child: Center(child: leading)),
        const SizedBox(width: AppSpacing.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 2),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.icon, required this.color});

  final FaIconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: FaIcon(icon, size: 18, color: color),
    );
  }
}

/// 新版本信息：“新版本”胶囊 + 大号版本号 + 发布日期、大小与架构；跳过、
/// 找不到适配安装包或平台不支持应用内安装时再补一行说明。
class _AvailableRelease extends StatelessWidget {
  const _AvailableRelease({required this.state});

  final AppUpdateState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = context.l10n;
    final release = state.release!;
    final asset = state.asset;
    final published = release.publishedAt;
    final size = asset?.size;
    final meta = <String>[
      if (published != null)
        l10n.appUpdatePublishedOn(l10n.formatFullDate(published)),
      if (size != null) l10n.formatByteSize(size),
      ?asset?.abi,
    ];
    final note = !state.supportsInAppInstall
        ? l10n.appUpdateUnsupportedPlatform
        : asset == null
        ? l10n.appUpdateNoCompatibleApk
        : state.isSkipped
        ? l10n.appUpdateSkippedHint
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const AppUpdateBadge(),
        const SizedBox(height: AppSpacing.s),
        Text(
          l10n.appUpdateAvailableTitle('v${release.version.name}'),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        if (meta.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            meta.join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (note != null) ...<Widget>[
          const SizedBox(height: AppSpacing.s),
          Text(
            note,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}
