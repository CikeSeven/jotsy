import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/app/app_bootstrap_home.dart';
import 'package:node_diary/app/app_lock_layer.dart';
import 'package:node_diary/app/synced_data_refresh.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/app/theme/app_fonts.dart';
import 'package:node_diary/app/theme/app_scroll_behavior.dart';
import 'package:node_diary/app/theme/derived_theme_cache.dart';
import 'package:node_diary/app/theme/expressive_controls.dart';
import 'package:node_diary/app/theme/expressive_motion.dart';
import 'package:node_diary/core/services/app_lock_platform.dart';
import 'package:node_diary/core/services/app_platform.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/app_passcode/app_passcode_store.dart';
import 'package:node_diary/core/services/display_corners.dart';
import 'package:node_diary/ui/app_lock/controllers/app_lock_controller.dart';
import 'package:node_diary/ui/app_lock/controllers/identity_verifier.dart';
import 'package:node_diary/ui/app_lock/models/app_lock_options.dart';
import 'package:node_diary/ui/app_lock/providers/app_lock_options_provider.dart';
import 'package:node_diary/ui/app_lock/widgets/app_lock_overlay.dart';
import 'package:node_diary/ui/app_surface/providers/app_surface_settings_provider.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_controls_theme.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_scope.dart';
import 'package:node_diary/ui/app_surface/widgets/app_glass_snack_bar_theme.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/diaries/providers/diary_typography_provider.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/lan_sync/providers/lan_sync_providers.dart';
import 'package:node_diary/ui/notebooks/providers/home_notebook_scope_provider.dart';
import 'package:node_diary/ui/notebooks/widgets/notebook_lock_layer.dart';
import 'package:node_diary/ui/todos/controllers/todo_reminder_scheduler.dart';
import 'package:node_diary/ui/widgets/keyboard_visibility.dart';

import '../core/services/settings_service.dart';
import '../l10n/app_localizations.dart';

/// 应用根组件。
///
/// 负责：
/// 1. 等待设置服务初始化；
/// 2. 监听主题模式变化；
/// 3. 处理启动加载页和最短展示时长，就绪后交给 [AppBootstrapHome] 揭幕；
/// 4. 提供 MaterialApp 壳与首页入口；
/// 5. 在启用应用锁时，统一处理解锁门禁（上锁时机与验证见
///    [AppLockController]，这里只画遮罩、转交指针操作）；
/// 6. 安排启动后的媒体文件回收；
/// 7. 常驻监听局域网同步的写入事件，失效一次性读取（[syncedDataRefreshProvider]）；
/// 8. 启动时建好局域网同步控制器（[lanSyncControllerProvider]），引擎随应用
///    启动、跟随前后台。
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
  AppFonts? _cachedThemeFonts;
  (ThemeData, ThemeData)? _cachedThemes;

  /// 减少动画时去掉动效的主题，按 MaterialApp 给的基础主题记住。
  final DerivedThemeCache<bool> _noMotionThemes = DerivedThemeCache<bool>();
  late final HomeHintVisibilityController _homeHintVisibilityController;
  Timer? _loaderShowTimer;
  Timer? _loaderMinVisibleTimer;
  bool _loaderShown = false;
  bool _loaderHolding = false;

  /// 启动时所选导入字体是否已就绪（见 [appFontsStartupReadyProvider]）。
  /// 一旦就绪即锁存：揭幕后再换字体（重新注册）不能让首页退回加载态。
  bool _startupFontsReady = false;

  /// 应用锁（随第一次就绪的设置服务创建，见 [_bindAppLock]）。
  AppLockController? _appLock;
  SettingsService? _appLockSettings;

  @override
  void initState() {
    super.initState();
    _homeHintVisibilityController = HomeHintVisibilityController();
    _loaderShowTimer = Timer(_loaderShowDelay, _handleLoaderShowDelayElapsed);
    // 编辑期不删除媒体文件，冷启动后延迟回收无人引用的文件与选择器缓存。
    ref.read(diaryMediaCleanupServiceProvider).scheduleStartupSweep();
    // 手机上把已存的 HEIC 图片转成 JPEG，同步 / 备份到桌面后才显示得了。
    ref.read(heifMediaRepairServiceProvider).scheduleStartupRepair();
    // 旧版本的单份新建草稿搬进草稿箱；新建入口与草稿箱读取前也会等它完成。
    unawaited(ref.read(diaryDraftLegacyMigrationProvider.future));
    // 已经建过纪念日的老用户升级后保留纪念日（新默认关闭）。
    unawaited(ref.read(appFeaturesLegacyMigrationProvider.future));
    // 常驻监听正文外观：设置就绪后即开始注册所选的导入字体，打开第一篇日记
    // 时通常已就绪，正文不会先按内置字体排一遍再换字体。
    ref.listenManual(diaryTextAppearanceProvider, (_, _) {});
    // 局域网同步写库后失效一次性读取的 provider（清单见该 provider）。
    ref.listenManual(syncedDataRefreshProvider, (_, _) {});
    // 局域网同步引擎随应用启动（而不是等用户打开同步页）：已配对设备的
    // 自动同步与对方发起的手动同步都要本机在前台时连得上。常驻监听让
    // provider 在整个应用生命周期里只建一份；引擎自己决定何时碰网络（没有
    // 已配对设备时只在同步页打开期间，docs/lan_sync.md §9），不支持的平台
    // 是不联网的空实现。
    ref.listenManual(lanSyncControllerProvider, (_, _) {});
    // 待办提醒的调度器同样常驻：按库里的待办排系统通知，接住通知上的
    // 点开与按钮（待办功能关闭时只取消已排的通知）。
    ref.listenManual(todoReminderSchedulerProvider, (_, _) {});
    // 应用密码存储与设置同时开始加载：应用锁判断验证方式时通常已就绪，
    // 遮罩不会先闪一下系统验证的加载指示再换成密码输入。
    ref.listenManual(appPasscodeConfigProvider, (_, _) {});
    // 设置页改了上锁时机 / 隐私选项后立即生效。
    ref.listenManual(appLockOptionsProvider, (_, AppLockOptions next) {
      _appLock?.options = next;
    });
    // 屏幕自带的圆角：从卡片展开日记时整页落在这个圆角上，点开前就要读好。
    DisplayCorners.start();
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
        (diaries.hasValue || diaries.hasError) &&
        (_startupFontsReady ||
            !ref.read(appFontsStartupReadyProvider).isLoading);
  }

  @override
  void dispose() {
    _loaderShowTimer?.cancel();
    _loaderMinVisibleTimer?.cancel();
    _disposeAppLock();
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
      _bindAppLock(settingsService);
    }
    final appLock = _appLock;
    final appLockCovering = appLock?.locked ?? false;
    // 设置就绪后才知道选了哪款字体，之前的就绪结果不算数。锁存后不再
    // 订阅就绪状态：之后换导入字体（重新注册）不影响启动门控。
    if (!_startupFontsReady) {
      final fontsLoading = ref.watch(appFontsStartupReadyProvider).isLoading;
      _startupFontsReady = settingsReady && !fontsLoading;
    }
    // 界面字体与日记卡片字体随主题下发（见 [AppFonts]）；导入字体注册完成前
    // 为内置字体，完成后主题换实例。
    final fonts = ref.watch(appFontsProvider);
    final bootstrapReady =
        settingsReady &&
        diariesSettled &&
        _startupFontsReady &&
        !_loaderHolding;
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
      holdReveal: appLockCovering,
      // 首页不为键盘让位（resizeToAvoidBottomInset: false），也没有自己的
      // 输入框：键盘只会为盖在上面的页面、面板与对话框弹出。始终屏蔽键盘，
      // 键盘升降时首页连同保活的各 Tab 一次都不重建（见 KeyboardShield）。
      homeBuilder: (BuildContext context) => KeyboardShield(
        shielded: true,
        child: HomePage(
          startupNotice: startupNotice,
          homeHintVisibleListenable:
              _homeHintVisibilityController.isHintVisibleNotifier,
        ),
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
                                fonts: fonts,
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

  /// 按种子色与字体缓存明暗 ThemeData。
  ///
  /// `ColorScheme.fromSeed` 需要做 HCT 色调板计算，ThemeData 组装也不便宜；
  /// 字号、语言、主题模式变化都会重建应用壳，但只有种子色或字体变化才需要
  /// 重算主题。
  (ThemeData, ThemeData) _themesFor(Color seedColor, AppFonts fonts) {
    final cached = _cachedThemes;
    if (cached != null &&
        _cachedThemeSeedColor == seedColor &&
        _cachedThemeFonts == fonts) {
      return cached;
    }
    final themes = (
      buildSeededAppTheme(seedColor, Brightness.light, fonts: fonts),
      buildSeededAppTheme(seedColor, Brightness.dark, fonts: fonts),
    );
    _cachedThemeSeedColor = seedColor;
    _cachedThemeFonts = fonts;
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
    AppFonts fonts = const AppFonts(),
  }) {
    // 字体无法插值：过渡里 TextStyle 的字族要到一半才换，旧字体多留半程、
    // 再整体重排一次（启动时正好落在首页揭幕的头几帧）。所以字体变化的这一次
    // 直接换主题，明暗、主题色的切换照旧过渡。按缓存比较而不是记在字段里：
    // 之后只换颜色的重建不受影响。
    final fontsChanged = _cachedThemes != null && _cachedThemeFonts != fonts;
    final (lightTheme, darkTheme) = _themesFor(themeSeedColor, fonts);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Android 拉伸越界时不让滚动内容里的玻璃失去背景模糊，见 AppScrollBehavior。
      scrollBehavior: const AppScrollBehavior(),
      // 切换明暗/主题色时 AnimatedTheme 会逐帧 lerp 整份 ThemeData；减少动画时
      // 直接切换，曲线与其余颜色过渡统一为 effects。换字体时直接切换（见上）。
      themeAnimationDuration: fontsChanged
          ? Duration.zero
          : ExpressiveMotion.duration(context, ExpressiveMotion.fast),
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
        AppFlowyEditorLocalizations.delegate,
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
        // 这一层随 MediaQuery 逐帧重建（键盘升降）：去掉动效的主题按基础主题
        // 记住，不让 Theme 逐帧通知全应用（见 DerivedThemeCache）。
        final themedChild = mediaQuery.disableAnimations
            ? Theme(
                data: _noMotionThemes.resolve(
                  theme,
                  true,
                  () => ExpressiveControls.withoutMotion(theme),
                ),
                child: child,
              )
            : child;
        final appLock = _appLock;
        // 应用锁与上锁日记本的遮罩也在字号缩放之内：密码页的文字与应用其余
        // 部分一样跟随“字体大小”设置。
        Widget scaledChild = MediaQuery(
          data: mediaQuery.copyWith(textScaler: effectiveTextScaler),
          // 键盘升降动画逐帧改变 viewInsets：这一层跟着逐帧重建，下面只关心
          // “键盘在不在”的页面经 KeyboardVisibility.of 只在切换时重建。
          child: KeyboardVisibility(
            child: AppLockLayer(
              locked: appLock?.locked ?? false,
              overlayBuilder: (_) => AppLockOverlay(
                unlocking: appLock?.unlocking ?? false,
                autoPrompt: appLock?.options.autoPrompt ?? true,
                onTapUnlock: () => unawaited(appLock?.manualUnlock()),
                onPasscodeUnlocked: () => appLock?.passcodeUnlocked(),
              ),
              // 上锁日记本的重新上锁层在应用锁之下：两者同时盖着时先解应用锁。
              child: NotebookLockLayer(
                // 桌面窗口（如 Linux GTK）背景是透明的：路由淡入淡出时最底层
                // 页面半透明，下面又没有不透明的东西，桌面壁纸会透出来。垫一层
                // 当前主题的 surface 色兜底；移动端窗口自带不透明背景，保持原样
                // 不加。
                child: AppPlatform.isDesktop
                    ? ColoredBox(
                        color: theme.colorScheme.surface,
                        child: themedChild,
                      )
                    : themedChild,
              ),
            ),
          ),
        );
        // 闲置时上锁（桌面）：任何指针操作都算在用。只旁听、不参与命中，
        // 下面的点按与拖动照常。
        if (AppPlatform.supportsIdleLock && appLock != null) {
          void note(PointerEvent _) => appLock.noteActivity();
          scaledChild = Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: note,
            onPointerMove: note,
            onPointerHover: note,
            onPointerSignal: note,
            child: scaledChild,
          );
        }
        final region = AnnotatedRegion<SystemUiOverlayStyle>(
          value: systemOverlayStyle,
          child: HomeHintVisibilityScope(
            controller: _homeHintVisibilityController,
            child: scaledChild,
          ),
        );
        // 组件材质（经典 / 玻璃）在 Theme 之下、Navigator 之上交给全应用：
        // 页面、底部面板与对话框都能经 AppGlass.of 读到。只在材质设置变化
        // 时重建这一层（appGlassStyleProvider 已按 == 去重），改背景不影响。
        // 提示条的玻璃配色在同一处以主题覆盖交给全应用（见
        // AppGlassSnackBarTheme），首页对 snackBarTheme 的 copyWith 会继承；
        // Chip、输入框与开关轨道的玻璃底色同样在这里覆盖（见
        // AppGlassControlsTheme）。
        return Consumer(
          child: AppGlassSnackBarTheme(
            child: AppGlassControlsTheme(child: region),
          ),
          builder: (BuildContext context, WidgetRef ref, Widget? child) =>
              AppGlassScope(
                style: ref.watch(appGlassStyleProvider),
                child: child!,
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

  /// 随设置服务创建应用锁控制器；首帧之后做一次冷启动检查。设置服务换了
  /// 实例（只在测试里出现）时重建控制器并重新检查：宁可多锁一次。
  void _bindAppLock(SettingsService settingsService) {
    final current = _appLock;
    if (current != null && identical(_appLockSettings, settingsService)) {
      return;
    }
    _disposeAppLock();
    _appLockSettings = settingsService;
    final controller = AppLockController(
      verifier: ref.read(identityVerifierProvider),
      settings: settingsService,
      platform: ref.read(appLockPlatformProvider),
      options: ref.read(appLockOptionsProvider),
      authReason: () => _bootstrapL10n(settingsService).appLockAuthReason,
      // 应用锁与上锁日记本是同一个人、同一种验证方式：解开应用锁时，一并
      // 解开同时盖着的日记本重锁遮罩，不连着验证两次。
      onUnlocked: () => ref.read(homeNotebookScopeProvider.notifier).unlock(),
    )..addListener(_handleAppLockChanged);
    _appLock = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_appLock, controller)) {
        controller.start();
      }
    });
  }

  void _handleAppLockChanged() {
    if (mounted) setState(() {});
  }

  void _disposeAppLock() {
    _appLock
      ?..removeListener(_handleAppLockChanged)
      ..dispose();
    _appLock = null;
    _appLockSettings = null;
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
