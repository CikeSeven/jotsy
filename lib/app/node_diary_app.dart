import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:node_diary/app/app_lock_layer.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/app/theme/expressive_controls.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
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
  // 启动等待反馈采用“延迟出现 + 最短展示”：
  // - 设置与首屏日记在 [_loaderShowDelay] 内就绪：直接淡入首页，不出现加载页，
  //   避免此前固定 1.2s 最短展示把快速冷启动人为拉长；
  // - 超过该时长仍未就绪：显示加载页，且至少保留 [_loaderMinVisible]，避免
  //   加载动画刚出现就消失的闪烁。
  static const Duration _loaderShowDelay = Duration(milliseconds: 250);
  static const Duration _loaderMinVisible = Duration(milliseconds: 500);

  late final MaterialTheme _lightMaterialTheme;
  late final MaterialTheme _darkMaterialTheme;
  Color? _cachedThemeSeedColor;
  (ThemeData, ThemeData)? _cachedThemes;
  late final HomeHintVisibilityController _homeHintVisibilityController;
  final LocalAuthentication _localAuthentication = LocalAuthentication();
  Timer? _loaderShowTimer;
  Timer? _loaderMinVisibleTimer;
  bool _loaderShown = false;
  bool _loaderHolding = false;

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
    _loaderShowTimer = Timer(_loaderShowDelay, _handleLoaderShowDelayElapsed);
  }

  /// 延迟到点仍未就绪时才显示加载页，并开始计算最短展示时长。
  void _handleLoaderShowDelayElapsed() {
    _loaderShowTimer = null;
    if (!mounted || _isBootstrapDataReady()) {
      return;
    }
    setState(() {
      _loaderShown = true;
      _loaderHolding = true;
    });
    _loaderMinVisibleTimer = Timer(_loaderMinVisible, () {
      _loaderMinVisibleTimer = null;
      if (mounted) {
        setState(() => _loaderHolding = false);
      }
    });
  }

  bool _isBootstrapDataReady() {
    final diaries = ref.read(filteredDiariesProvider);
    return ref.read(settingsServiceProvider).hasValue &&
        (diaries.hasValue || diaries.hasError);
  }

  @override
  void dispose() {
    _loaderShowTimer?.cancel();
    _loaderMinVisibleTimer?.cancel();
    _unbindAppLockListener();
    _homeHintVisibilityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 启动门控：设置服务 + 首帧日记列表 + 最短展示时长。
    final settingsAsync = ref.watch(settingsServiceProvider);
    // 只订阅启动门控需要的两个布尔量：直接 watch 整个 AsyncValue 会让每次
    // 日记列表变化（编辑、筛选、排序）都重建整个 MaterialApp。record 按值比较，
    // 列表内容变化但状态不变时 select 不会通知。
    final (diariesSettled, diariesBootstrapFailed) = ref.watch(
      filteredDiariesProvider.select(
        (async) => (async.hasValue || async.hasError, async.hasError),
      ),
    );
    final settingsReady = settingsAsync.hasValue;
    final settingsError = settingsAsync.asError?.error;
    final settingsService = settingsAsync.asData?.value;
    if (settingsService != null) {
      _bindSettingsForAppLock(settingsService);
    }
    final bootstrapReady = settingsReady && diariesSettled && !_loaderHolding;
    final startupNotice = bootstrapReady && diariesBootstrapFailed
        ? _pickBootstrapText(
            settingsService: settingsService,
            zh: '启动时预加载日记失败，已进入主页。',
            en: 'Startup preload failed. Entered home anyway.',
          )
        : null;

    if (settingsError != null && !_loaderHolding) {
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
      phase: bootstrapReady
          ? _BootstrapPhase.home
          : (_loaderShown ? _BootstrapPhase.loading : _BootstrapPhase.blank),
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
                builder:
                    (
                      BuildContext context,
                      Color themeSeedColor,
                      Widget? child,
                    ) {
                      return ValueListenableBuilder<double>(
                        valueListenable: settingsService.fontScaleNotifier,
                        builder:
                            (
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

  /// 按种子色缓存明暗 ThemeData。
  ///
  /// `ColorScheme.fromSeed` 需要做 HCT 色调板计算，ThemeData 组装也不便宜；
  /// 字号、语言、主题模式变化都会重建应用壳，但只有种子色变化才需要重算主题。
  (ThemeData, ThemeData) _themesForSeed(Color seedColor) {
    final cached = _cachedThemes;
    if (cached != null && _cachedThemeSeedColor == seedColor) {
      return cached;
    }
    ThemeData build(MaterialTheme materialTheme, Brightness brightness) {
      return materialTheme.theme(
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
        ),
      );
    }

    final themes = (
      build(_lightMaterialTheme, Brightness.light),
      build(_darkMaterialTheme, Brightness.dark),
    );
    _cachedThemeSeedColor = seedColor;
    _cachedThemes = themes;
    return themes;
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
    final (lightTheme, darkTheme) = _themesForSeed(themeSeedColor);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // 切换明暗/主题色时 AnimatedTheme 会逐帧 lerp 整份 ThemeData；减少动画时
      // 直接切换，曲线与其余颜色过渡统一为 effects。
      themeAnimationDuration: ExpressiveMotion.duration(
        context,
        ExpressiveMotion.fast,
      ),
      themeAnimationCurve: ExpressiveMotion.effects,
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
        final theme = Theme.of(context);
        final isLight = theme.brightness == Brightness.light;
        final systemOverlayStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
          statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: isLight
              ? Brightness.dark
              : Brightness.light,
        );
        final mediaQuery = MediaQuery.of(context);
        final effectiveTextScaler = _AppMultiplierTextScaler(
          baseScaler: mediaQuery.textScaler,
          factor: fontScale,
        );
        final scaledChild = MediaQuery(
          data: mediaQuery.copyWith(textScaler: effectiveTextScaler),
          child: mediaQuery.disableAnimations
              ? Theme(
                  data: ExpressiveControls.withoutMotion(Theme.of(context)),
                  child: child,
                )
              : child,
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: systemOverlayStyle,
          child: HomeHintVisibilityScope(
            controller: _homeHintVisibilityController,
            child: AppLockLayer(
              locked: _appLocked || _unlockingApp,
              overlayBuilder: (_) => _AppLockOverlay(
                unlocking: _unlockingApp,
                onTapUnlock: _handleManualUnlockTap,
              ),
              child: scaledChild,
            ),
          ),
        );
      },
      home: home,
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

/// 启动阶段：空白底（等待中但尚未到加载页延迟）→ 加载页 → 首页。
enum _BootstrapPhase { blank, loading, home }

class _BootstrapHome extends StatelessWidget {
  const _BootstrapHome({
    required this.phase,
    required this.startupNotice,
    required this.homeHintVisibleListenable,
  });

  final _BootstrapPhase phase;
  final String? startupNotice;
  final ValueListenable<bool> homeHintVisibleListenable;

  @override
  Widget build(BuildContext context) {
    final background = Theme.of(context).scaffoldBackgroundColor;
    final child = switch (phase) {
      // 与页面同色的空白底：快速启动时直接从这里淡入首页，不闪加载动画。
      _BootstrapPhase.blank => ColoredBox(
        key: const ValueKey<String>('bootstrap_blank'),
        color: background,
      ),
      _BootstrapPhase.loading => ColoredBox(
        key: const ValueKey<String>('bootstrap_loading'),
        color: background,
        child: const AppLoadingContent(),
      ),
      _BootstrapPhase.home => HomePage(
        key: const ValueKey<String>('bootstrap_home'),
        startupNotice: startupNotice,
        homeHintVisibleListenable: homeHintVisibleListenable,
      ),
    };

    // 启动等待期间只绘制空白底或加载页，不提前构建 HomePage。
    // 这样可以减少 Flutter 首帧前后的数据库监听与页面装配工作，避免
    // Android 原生启动背景结束后又等待一段时间才看到加载动画。
    return AnimatedSwitcher(
      duration: ExpressiveMotion.duration(context, ExpressiveMotion.medium),
      switchInCurve: ExpressiveMotion.effects,
      switchOutCurve: ExpressiveMotion.effects,
      child: child,
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
                  ExpressiveLoadingIndicator(
                    size: 64,
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
