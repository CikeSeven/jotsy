import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../core/services/app_data_directory.dart';
import '../core/services/app_data_location_bootstrapper.dart';
import '../core/services/app_data_location_migrator.dart';
import '../core/services/app_platform.dart';
import '../core/services/settings_service.dart';
import '../core/services/storage/managed_media_content_index.dart';
import '../core/services/storage/managed_media_dedup.dart';
import '../l10n/app_localizations.dart';
import '../ui/calendar/providers/calendar_diary_providers.dart';
import '../ui/diaries/viewmodels/diary_card_view_data.dart';
import '../ui/widgets/expressive_loading_indicator.dart';
import '../ui/widgets/form_width.dart';
import 'node_diary_app.dart';
import 'theme/app_radii.dart';
import 'theme/app_spacing.dart';
import 'theme/theme.dart';

/// 供存储管理触发“重建应用容器并迁移/切换数据根目录”的宿主接口。
abstract interface class AppDataRelocationHost {
  Future<void> relocate({
    required ThemeMode themeMode,
    required Locale locale,
    required Color seedColor,
    required Future<AppDataMigrationResult> Function(
      void Function(AppDataMigrationProgress progress) onProgress,
    )
    task,
    required String Function(
      AppLocalizations l10n,
      AppDataMigrationResult result,
    )
    successNotice,
    required String Function(AppLocalizations l10n, Object error) failureNotice,
  });
}

/// 由 [AppRootShell] 在根 `ProviderScope` 内覆盖；测试未包外壳时为 null。
final appDataRelocationHostProvider = Provider<AppDataRelocationHost?>(
  (Ref ref) => null,
);

/// 应用最外层宿主：在 `ProviderScope` 之外处理桌面端启动数据位置迁移与运行期
/// 切换位置时的容器重启。
///
/// 为什么放在 `ProviderScope` 之上：切换数据位置时必须先彻底释放 `AppDatabase`、
/// `LanSyncService` 与全部状态 provider，等 SQLite 文件锁释放后再跨卷复制与重绑，
/// 最后再挂载全新的 `ProviderScope` 从新目录重新读取。
class AppRootShell extends StatefulWidget {
  const AppRootShell({super.key, this.launchBrandMark = false});

  final bool launchBrandMark;

  @override
  State<AppRootShell> createState() => _AppRootShellState();
}

class _AppRootShellState extends State<AppRootShell>
    with WidgetsBindingObserver
    implements AppDataRelocationHost {
  final AppDataLocationBootstrapper _bootstrapper =
      AppDataLocationBootstrapper();

  int _epoch = 0;
  bool _ready = !AppPlatform.supportsCustomDataDirectory;
  bool _migrating = false;
  AppDataMigrationProgress? _progress;
  String? _startupFailure;
  String Function(AppLocalizations l10n)? _pendingNoticeBuilder;

  ThemeMode _migrationThemeMode = ThemeMode.system;
  Locale? _migrationLocale;
  Color _migrationSeedColor = const Color(
    SettingsService.defaultThemeSeedColorValue,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_ready) {
      unawaited(_runStartupBootstrap());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Future<AppExitResponse> didRequestAppExit() async {
    // 迁移过程中拦截关闭窗口，避免中断复制或写库。
    if (_migrating) return AppExitResponse.cancel;
    return AppExitResponse.exit;
  }

  Future<void> _runStartupBootstrap() async {
    final hasPending = await _bootstrapper.hasPendingStartupWork();
    if (!mounted) return;
    if (hasPending) {
      setState(() {
        _migrating = true;
        _startupFailure = null;
        _progress = const AppDataMigrationProgress(
          phase: AppDataMigrationPhase.preparing,
        );
      });
    }

    final result = await _bootstrapper.prepareOnStartup(
      onProgress: (AppDataMigrationProgress progress) {
        if (!mounted || !_migrating) return;
        setState(() => _progress = progress);
      },
    );
    if (!mounted) return;
    if (result.pendingMigrationFailed) {
      setState(() {
        _migrating = false;
        _ready = false;
        _startupFailure = result.errorMessage ?? '';
      });
      return;
    }

    _clearProcessCaches();
    setState(() {
      _migrating = false;
      _ready = true;
      _startupFailure = null;
      if (result.migratedToPath != null) {
        final targetPath = result.migratedToPath!;
        _pendingNoticeBuilder = (l10n) =>
            l10n.storageLocationMigratedNotice(targetPath);
      }
    });
  }

  Future<void> _continueWithoutPendingMigration() async {
    await _bootstrapper.clearPendingMigration();
    _clearProcessCaches();
    if (!mounted) return;
    setState(() {
      _startupFailure = null;
      _migrating = false;
      _ready = true;
    });
  }

  @override
  Future<void> relocate({
    required ThemeMode themeMode,
    required Locale locale,
    required Color seedColor,
    required Future<AppDataMigrationResult> Function(
      void Function(AppDataMigrationProgress progress) onProgress,
    )
    task,
    required String Function(
      AppLocalizations l10n,
      AppDataMigrationResult result,
    )
    successNotice,
    required String Function(AppLocalizations l10n, Object error) failureNotice,
  }) async {
    if (_migrating) return;
    setState(() {
      _migrationThemeMode = themeMode;
      _migrationLocale = locale;
      _migrationSeedColor = seedColor;
      _migrating = true;
      _progress = const AppDataMigrationProgress(
        phase: AppDataMigrationPhase.preparing,
      );
      _pendingNoticeBuilder = null;
    });

    // 等一帧让旧 ProviderScope 卸载、dispose 清理完毕后再触碰数据库文件。
    await WidgetsBinding.instance.endOfFrame;

    String Function(AppLocalizations l10n)? nextNotice;
    try {
      final result = await task((AppDataMigrationProgress progress) {
        if (!mounted) return;
        setState(() => _progress = progress);
      });
      nextNotice = (l10n) => successNotice(l10n, result);
    } catch (error) {
      nextNotice = (l10n) => failureNotice(l10n, error);
    }

    _clearProcessCaches();
    if (!mounted) return;
    setState(() {
      _migrating = false;
      _ready = true;
      _progress = null;
      _pendingNoticeBuilder = nextNotice;
      _epoch++;
    });
  }

  void _clearProcessCaches() {
    invalidateAppDataRootCache();
    DiaryCardViewData.clearCache();
    clearCalendarInlineImageCache();
    ManagedMediaContentIndex.clearCache();
    ManagedMediaDedup.clearCache();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  @override
  Widget build(BuildContext context) {
    if (_migrating || _startupFailure != null) {
      return _MigrationShell(
        themeMode: _migrationThemeMode,
        locale: _migrationLocale,
        seedColor: _migrationSeedColor,
        progress: _progress,
        failureMessage: _startupFailure,
        onRetry: _runStartupBootstrap,
        onContinueWithOldLocation: _continueWithoutPendingMigration,
      );
    }

    if (!_ready) {
      return _MigrationShell(
        themeMode: _migrationThemeMode,
        locale: _migrationLocale,
        seedColor: _migrationSeedColor,
        blankOnly: true,
      );
    }

    final noticeBuilder = _pendingNoticeBuilder;
    return ProviderScope(
      key: ValueKey<int>(_epoch),
      overrides: [appDataRelocationHostProvider.overrideWithValue(this)],
      child: NodeDiaryApp(
        launchBrandMark: _epoch == 0 && widget.launchBrandMark,
        initialStartupNoticeBuilder: noticeBuilder,
      ),
    );
  }
}

class _MigrationShell extends StatelessWidget {
  const _MigrationShell({
    required this.themeMode,
    required this.locale,
    required this.seedColor,
    this.progress,
    this.failureMessage,
    this.blankOnly = false,
    this.onRetry,
    this.onContinueWithOldLocation,
  });

  final ThemeMode themeMode;
  final Locale? locale;
  final Color seedColor;
  final AppDataMigrationProgress? progress;
  final String? failureMessage;
  final bool blankOnly;
  final VoidCallback? onRetry;
  final VoidCallback? onContinueWithOldLocation;

  @override
  Widget build(BuildContext context) {
    final lightTheme = buildSeededAppTheme(seedColor, Brightness.light);
    final darkTheme = buildSeededAppTheme(seedColor, Brightness.dark);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jotsy',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: Builder(
        builder: (BuildContext context) {
          final theme = Theme.of(context);
          final colors = theme.colorScheme;
          if (blankOnly) {
            return Scaffold(backgroundColor: colors.surface);
          }
          final l10n = context.l10n;
          final error = failureMessage;
          return Scaffold(
            backgroundColor: colors.surface,
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: FormWidth.maxWidth - 160,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Card(
                    elevation: 0,
                    color: colors.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.card),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: error != null
                          ? _buildFailure(context, l10n, error)
                          : _buildProgress(context, l10n),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProgress(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final current =
        progress ??
        const AppDataMigrationProgress(phase: AppDataMigrationPhase.preparing);
    final stageText = switch (current.phase) {
      AppDataMigrationPhase.preparing => l10n.storageLocationPhasePreparing,
      AppDataMigrationPhase.copying => l10n.storageLocationPhaseCopying,
      AppDataMigrationPhase.rebinding => l10n.storageLocationPhaseRebinding,
      AppDataMigrationPhase.finalizing => l10n.storageLocationPhaseFinalizing,
      AppDataMigrationPhase.cleaningUp => l10n.storageLocationPhaseCleaningUp,
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const ExpressiveLoadingIndicator(size: 56),
        const SizedBox(height: AppSpacing.xl),
        Text(
          l10n.storageLocationMigratingTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          l10n.storageLocationMigratingHint,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        LinearProgressIndicator(value: current.fraction),
        const SizedBox(height: AppSpacing.m),
        Text(
          stageText,
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        if (current.phase == AppDataMigrationPhase.copying &&
            current.totalFiles > 0) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.storageLocationMigrationCounts(
              current.copiedFiles,
              current.totalFiles,
              l10n.formatByteSize(current.copiedBytes),
              l10n.formatByteSize(current.totalBytes),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Widget _buildFailure(
    BuildContext context,
    AppLocalizations l10n,
    String error,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FaIcon(
          FontAwesomeIcons.triangleExclamation,
          size: 36,
          color: colors.error,
        ),
        const SizedBox(height: AppSpacing.l),
        Text(
          l10n.storageLocationStartupFailedTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.s),
        Text(
          l10n.storageLocationStartupFailedBody(error),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: AppSpacing.m,
          runSpacing: AppSpacing.s,
          alignment: WrapAlignment.center,
          children: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: colors.onSurfaceVariant,
              ),
              onPressed: onContinueWithOldLocation,
              child: Text(l10n.storageLocationUseOldLocation),
            ),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(l10n.storageLocationRetryMigration),
            ),
          ],
        ),
      ],
    );
  }
}
