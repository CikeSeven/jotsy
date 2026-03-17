import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:local_auth/local_auth.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/app_loading_page.dart'
    show AppLoadingContent;

import '../core/services/settings_service.dart';
import '../l10n/app_localizations.dart';

/// 应用根组件。
///
/// 负责：
/// 1. 等待设置服务初始化；
/// 2. 监听主题模式变化；
/// 3. 处理启动加载页和最短展示时长；
/// 4. 提供 MaterialApp 壳与首页入口；
/// 5. 在启用应用锁时，统一处理前台解锁门禁。
class NodeDiaryApp extends ConsumerStatefulWidget {
  const NodeDiaryApp({super.key});

  @override
  ConsumerState<NodeDiaryApp> createState() => _NodeDiaryAppState();
}

class _NodeDiaryAppState extends ConsumerState<NodeDiaryApp> {
  // 启动加载页最短展示时长：即使数据提前加载完，也会等待这个时间再进入首页。
  static const Duration _minimumLoadingDuration = Duration(milliseconds: 1800);
  static const double _globalSnackBarSideInset = 16;
  static const double _globalSnackBarBottomInset = 16;

  late final MaterialTheme _lightMaterialTheme;
  late final MaterialTheme _darkMaterialTheme;
  late final HomeHintVisibilityController _homeHintVisibilityController;
  final LocalAuthentication _localAuthentication = LocalAuthentication();
  Timer? _minimumLoadingTimer;
  bool _minimumLoadingElapsed = false;

  SettingsService? _boundSettingsService;
  VoidCallback? _appLockToggleListener;
  bool _appLocked = false;
  bool _unlockingApp = false;
  bool _initialAppLockChecked = false;

  @override
  void initState() {
    super.initState();
    _lightMaterialTheme = MaterialTheme(Typography.material2021().black);
    _darkMaterialTheme = MaterialTheme(Typography.material2021().white);
    _homeHintVisibilityController = HomeHintVisibilityController();
    _minimumLoadingTimer = Timer(_minimumLoadingDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _minimumLoadingElapsed = true;
      });
    });
  }

  @override
  void dispose() {
    _minimumLoadingTimer?.cancel();
    _unbindAppLockListener();
    _homeHintVisibilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 启动门控：设置服务 + 首帧日记列表 + 最短展示时长。
    final settingsAsync = ref.watch(settingsServiceProvider);
    final diariesBootstrapAsync = ref.watch(filteredDiariesProvider);
    final settingsReady = settingsAsync.hasValue;
    final settingsError = settingsAsync.asError?.error;
    final settingsService = settingsAsync.asData?.value;
    if (settingsService != null) {
      _bindSettingsForAppLock(settingsService);
    }
    final diariesSettled =
        diariesBootstrapAsync.hasValue || diariesBootstrapAsync.hasError;
    final bootstrapReady =
        _minimumLoadingElapsed && settingsReady && diariesSettled;
    final startupNotice =
        bootstrapReady && diariesBootstrapAsync.hasError
            ? _pickBootstrapText(
              settingsService: settingsService,
              zh: '启动时预加载日记失败，已进入主页。',
              en: 'Startup preload failed. Entered home anyway.',
            )
            : null;

    if (settingsError != null && _minimumLoadingElapsed) {
      return _buildAppShell(
        home: Scaffold(
          body: Center(
            child: Text(
              _pickBootstrapText(
                settingsService: settingsService,
                zh: '初始化失败: $settingsError',
                en: 'Initialization failed: $settingsError',
              ),
            ),
          ),
        ),
      );
    }

    final home = _BootstrapHome(
      showLoadingOverlay: !bootstrapReady,
      startupNotice: startupNotice,
      homeHintVisibleListenable:
          _homeHintVisibilityController.isHintVisibleNotifier,
    );

    if (settingsService != null) {
      return ValueListenableBuilder<ThemeMode>(
        valueListenable: settingsService.themeModeNotifier,
        builder: (BuildContext context, ThemeMode themeMode, Widget? child) {
          return ValueListenableBuilder<Locale>(
            valueListenable: settingsService.localeNotifier,
            builder: (BuildContext context, Locale locale, Widget? child) {
              return ValueListenableBuilder<Color>(
                valueListenable: settingsService.themeSeedColorNotifier,
                builder: (
                  BuildContext context,
                  Color themeSeedColor,
                  Widget? child,
                ) {
                  return ValueListenableBuilder<double>(
                    valueListenable: settingsService.fontScaleNotifier,
                    builder: (
                      BuildContext context,
                      double fontScale,
                      Widget? child,
                    ) {
                      return _buildAppShell(
                        home: home,
                        themeMode: themeMode,
                        locale: locale,
                        themeSeedColor: themeSeedColor,
                        fontScale: fontScale,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
    }

    return _buildAppShell(home: home);
  }

  MaterialApp _buildAppShell({
    required Widget home,
    ThemeMode themeMode = ThemeMode.system,
    Locale locale = const Locale('en'),
    Color themeSeedColor = const Color(
      SettingsService.defaultThemeSeedColorValue,
    ),
    double fontScale = SettingsService.defaultFontScale,
  }) {
    final lightTheme = _withGlobalSnackBarTheme(
      _lightMaterialTheme.theme(
        ColorScheme.fromSeed(
          seedColor: themeSeedColor,
          brightness: Brightness.light,
        ),
      ),
    );
    final darkTheme = _withGlobalSnackBarTheme(
      _darkMaterialTheme.theme(
        ColorScheme.fromSeed(
          seedColor: themeSeedColor,
          brightness: Brightness.dark,
        ),
      ),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jotsy',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      builder: (BuildContext context, Widget? child) {
        if (child == null) {
          return const SizedBox.shrink();
        }
        final mediaQuery = MediaQuery.of(context);
        final effectiveTextScaler = _AppMultiplierTextScaler(
          baseScaler: mediaQuery.textScaler,
          factor: fontScale,
        );
        final scaledChild = MediaQuery(
          data: mediaQuery.copyWith(textScaler: effectiveTextScaler),
          child: child,
        );
        return HomeHintVisibilityScope(
          controller: _homeHintVisibilityController,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              scaledChild,
              if (_appLocked || _unlockingApp)
                _AppLockOverlay(
                  unlocking: _unlockingApp,
                  onTapUnlock: _handleManualUnlockTap,
                ),
            ],
          ),
        );
      },
      home: home,
    );
  }

  /// 为整个应用提供统一的提示样式（与 Home 视觉一致）。
  ///
  /// Home 页仍会在此基础上覆盖底部 inset，以避让底部导航栏。
  ThemeData _withGlobalSnackBarTheme(ThemeData baseTheme) {
    final colorScheme = baseTheme.colorScheme;
    return baseTheme.copyWith(
      snackBarTheme: baseTheme.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.surfaceContainerHigh.withValues(
          alpha: 0.96,
        ),
        contentTextStyle: baseTheme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
        ),
        actionTextColor: colorScheme.primary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.fromLTRB(
          _globalSnackBarSideInset,
          0,
          _globalSnackBarSideInset,
          _globalSnackBarBottomInset,
        ),
      ),
    );
  }

  String _pickBootstrapText({
    required SettingsService? settingsService,
    required String zh,
    required String en,
  }) {
    return settingsService?.appLocaleCode == 'zh' ? zh : en;
  }

  void _bindSettingsForAppLock(SettingsService settingsService) {
    if (identical(_boundSettingsService, settingsService)) {
      _ensureInitialAppLockCheck(settingsService);
      return;
    }

    _unbindAppLockListener();
    _boundSettingsService = settingsService;
    _appLockToggleListener = () {
      _handleAppLockSettingChanged(
        enabled: settingsService.isAppLockEnabled,
        settingsService: settingsService,
      );
    };
    settingsService.appLockEnabledNotifier.addListener(_appLockToggleListener!);
    _ensureInitialAppLockCheck(settingsService);
  }

  void _unbindAppLockListener() {
    final settingsService = _boundSettingsService;
    final listener = _appLockToggleListener;
    if (settingsService != null && listener != null) {
      settingsService.appLockEnabledNotifier.removeListener(listener);
    }
    _boundSettingsService = null;
    _appLockToggleListener = null;
  }

  void _ensureInitialAppLockCheck(SettingsService settingsService) {
    if (_initialAppLockChecked) {
      return;
    }
    _initialAppLockChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _handleAppLockSettingChanged(
        enabled: settingsService.isAppLockEnabled,
        settingsService: settingsService,
      );
    });
  }

  void _handleAppLockSettingChanged({
    required bool enabled,
    required SettingsService settingsService,
  }) {
    if (!enabled) {
      if (_appLocked || _unlockingApp) {
        setState(() {
          _appLocked = false;
          _unlockingApp = false;
        });
      }
      return;
    }
    _lockAndAuthenticate(settingsService: settingsService);
  }

  Future<void> _handleManualUnlockTap() async {
    final settingsService = _boundSettingsService;
    if (settingsService == null) {
      return;
    }
    await _lockAndAuthenticate(settingsService: settingsService);
  }

  Future<void> _lockAndAuthenticate({
    required SettingsService settingsService,
  }) async {
    if (_unlockingApp || !settingsService.isAppLockEnabled) {
      return;
    }
    if (mounted) {
      setState(() {
        _appLocked = true;
        _unlockingApp = true;
      });
    }

    final supportsAuth = await _supportsLocalAuth();
    if (!mounted) {
      return;
    }
    if (!supportsAuth) {
      await settingsService.setAppLockEnabled(false);
      if (!mounted) {
        return;
      }
      setState(() {
        _appLocked = false;
        _unlockingApp = false;
      });
      return;
    }

    bool authenticated = false;
    try {
      authenticated = await _localAuthentication.authenticate(
        localizedReason: _localizedAuthReason(settingsService),
        biometricOnly: false,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      authenticated = false;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _unlockingApp = false;
      _appLocked = !authenticated;
    });
  }

  Future<bool> _supportsLocalAuth() async {
    try {
      final deviceSupported = await _localAuthentication.isDeviceSupported();
      if (deviceSupported) {
        return true;
      }
      return await _localAuthentication.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  String _localizedAuthReason(SettingsService settingsService) {
    if (settingsService.appLocaleCode == 'zh') {
      return '请验证身份以解锁应用';
    }
    return 'Please authenticate to unlock the app';
  }
}

class _AppMultiplierTextScaler implements TextScaler {
  const _AppMultiplierTextScaler({
    required this.baseScaler,
    required this.factor,
  });

  final TextScaler baseScaler;
  final double factor;

  @override
  double scale(double fontSize) {
    return baseScaler.scale(fontSize) * factor;
  }

  @override
  double get textScaleFactor => scale(1.0);

  @override
  TextScaler clamp({
    double minScaleFactor = 0,
    double maxScaleFactor = double.infinity,
  }) {
    return TextScaler.linear(
      scale(1.0),
    ).clamp(minScaleFactor: minScaleFactor, maxScaleFactor: maxScaleFactor);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _AppMultiplierTextScaler &&
        other.baseScaler == baseScaler &&
        other.factor == factor;
  }

  @override
  int get hashCode => Object.hash(baseScaler, factor);
}

class _BootstrapHome extends StatelessWidget {
  const _BootstrapHome({
    required this.showLoadingOverlay,
    required this.startupNotice,
    required this.homeHintVisibleListenable,
  });

  final bool showLoadingOverlay;
  final String? startupNotice;
  final ValueListenable<bool> homeHintVisibleListenable;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        HomePage(
          startupNotice: startupNotice,
          homeHintVisibleListenable: homeHintVisibleListenable,
        ),
        IgnorePointer(
          ignoring: !showLoadingOverlay,
          child: AnimatedOpacity(
            opacity: showLoadingOverlay ? 1 : 0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: const AppLoadingContent(),
            ),
          ),
        ),
      ],
    );
  }
}

/// 应用锁遮罩层。
///
/// 设计目标：
/// - 在应用锁开启时阻断所有交互；
/// - 自动解锁中给出统一 loading 反馈；
/// - 解锁失败后提供明确的手动重试入口。
class _AppLockOverlay extends StatelessWidget {
  const _AppLockOverlay({required this.unlocking, required this.onTapUnlock});

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
                if (unlocking)
                  LoadingIndicatorM3E(
                    variant: LoadingIndicatorM3EVariant.contained,
                    constraints: const BoxConstraints.tightFor(
                      width: 64,
                      height: 64,
                    ),
                    semanticLabel: l10n.appLockUnlocking,
                  )
                else
                  FilledButton.icon(
                    onPressed: onTapUnlock,
                    icon: const FaIcon(FontAwesomeIcons.key, size: 14),
                    label: Text(l10n.appLockUnlockNow),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
