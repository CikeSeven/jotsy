import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/app/app_bootstrap_home.dart';
import 'package:node_diary/app/app_lock_layer.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/app/theme/expressive_controls.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/device_auth_service.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/providers/diary_typography_provider.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_lock_layer.dart';

import '../core/services/settings_service.dart';
import '../l10n/app_localizations.dart';

/// 应用根组件。
///
/// 负责：
/// 1. 等待设置服务初始化；
/// 2. 监听主题模式变化；
/// 3. 处理启动加载页和最短展示时长，就绪后交给 [AppBootstrapHome] 揭幕；
/// 4. 提供 MaterialApp 壳与首页入口；
/// 5. 在启用应用锁时，统一处理前台解锁门禁；
/// 6. 安排启动后的媒体文件回收。
class NodeDiaryApp extends ConsumerStatefulWidget {
  const NodeDiaryApp({super.key, this.launchBrandMark = false});

  /// 原生启动页是否在屏幕中央画了品牌图形（见 `launchBrandMarkEntrypointArg`）；
  /// 是则启动层首帧在同一位置接着画，否则只铺底色。
  final bool launchBrandMark;

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

  Color? _cachedThemeSeedColor;
  (ThemeData, ThemeData)? _cachedThemes;
  late final HomeHintVisibilityController _homeHintVisibilityController;
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
    _homeHintVisibilityController = HomeHintVisibilityController();
    _loaderShowTimer = Timer(_loaderShowDelay, _handleLoaderShowDelayElapsed);
    // 编辑期不删除媒体文件，冷启动后延迟回收无人引用的文件与选择器缓存。
    ref.read(diaryMediaCleanupServiceProvider).scheduleStartupSweep();
    // 旧版本的单份新建草稿搬进草稿箱；新建入口与草稿箱读取前也会等它完成。
    unawaited(ref.read(diaryDraftLegacyMigrationProvider.future));
    // 常驻监听正文外观：设置就绪后即开始注册所选的导入字体，打开第一篇日记
    // 时通常已就绪，正文不会先按内置字体排一遍再换字体。
    ref.listenManual(diaryTextAppearanceProvider, (_, _) {});
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
    final diaries = ref.read(startupDiariesProvider);
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
      startupDiariesProvider.select(
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
        ? _bootstrapL10n(settingsService).startupPreloadFailedNotice
        : null;

    if (settingsError != null && !_loaderHolding) {
      return _buildAppShell(
        home: Scaffold(
          body: Center(
            child: Text(
              _bootstrapL10n(
                settingsService,
              ).startupInitFailed(settingsError.toString()),
            ),
          ),
        ),
      );
    }

    final home = AppBootstrapHome(
      phase: bootstrapReady
          ? AppBootstrapPhase.home
          : (_loaderShown
                ? AppBootstrapPhase.loading
                : AppBootstrapPhase.blank),
      showBrandMark: widget.launchBrandMark,
      // 应用锁遮罩盖着时首页入场无人可见，留到解锁时与遮罩淡出一起上演。
      holdReveal: _appLocked || _unlockingApp,
      homeBuilder: (BuildContext context) => HomePage(
        startupNotice: startupNotice,
        homeHintVisibleListenable:
            _homeHintVisibilityController.isHintVisibleNotifier,
      ),
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
    final themes = (
      buildSeededAppTheme(seedColor, Brightness.light),
      buildSeededAppTheme(seedColor, Brightness.dark),
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
              // 上锁日记本的重新上锁层在应用锁之下：两者同时盖着时先解应用锁。
              child: NotebookLockLayer(child: scaledChild),
            ),
          ),
        );
      },
      home: home,
    );
  }

  /// 启动阶段文案：此处位于 MaterialApp 之上，没有 Localizations 可用，
  /// 直接按设置语言查找生成的本地化实例；设置不可用（如初始化失败）时按
  /// 系统语言，系统语言不受支持再回退英文。
  AppLocalizations _bootstrapL10n(SettingsService? settingsService) {
    final languageCode =
        settingsService?.appLocaleCode ??
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final locale = Locale(languageCode);
    return lookupAppLocalizations(
      AppLocalizations.delegate.isSupported(locale)
          ? locale
          : const Locale('en'),
    );
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

    final deviceAuth = ref.read(deviceAuthServiceProvider);
    final supportsAuth = await deviceAuth.isSupported();
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

    final authenticated = await deviceAuth.authenticate(
      reason: _bootstrapL10n(settingsService).appLockAuthReason,
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _unlockingApp = false;
      _appLocked = !authenticated;
    });
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
