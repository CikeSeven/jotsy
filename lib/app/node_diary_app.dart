import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/app_loading_page.dart' show AppLoadingContent;

import '../l10n/app_localizations.dart';

/// 应用根组件。
///
/// 负责：
/// 1. 等待设置服务初始化；
/// 2. 监听主题模式变化；
/// 3. 处理启动加载页和最短展示时长；
/// 4. 提供 MaterialApp 壳与首页入口。
class NodeDiaryApp extends ConsumerStatefulWidget {
  const NodeDiaryApp({super.key});

  @override
  ConsumerState<NodeDiaryApp> createState() => _NodeDiaryAppState();
}

class _NodeDiaryAppState extends ConsumerState<NodeDiaryApp> {
  // 启动加载页最短展示时长：即使数据提前加载完，也会等待这个时间再进入首页。
  static const Duration _minimumLoadingDuration = Duration(milliseconds: 1800);

  late final MaterialTheme _lightMaterialTheme;
  late final MaterialTheme _darkMaterialTheme;
  late final HomeHintVisibilityController _homeHintVisibilityController;
  Timer? _minimumLoadingTimer;
  bool _minimumLoadingElapsed = false;

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
    final diariesSettled =
        diariesBootstrapAsync.hasValue || diariesBootstrapAsync.hasError;
    final bootstrapReady =
        _minimumLoadingElapsed && settingsReady && diariesSettled;
    final startupNotice =
        bootstrapReady && diariesBootstrapAsync.hasError
            ? '启动时预加载日记失败，已进入主页。'
            : null;

    if (settingsError != null && _minimumLoadingElapsed) {
      return _buildAppShell(
        home: Scaffold(body: Center(child: Text('初始化失败: $settingsError'))),
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
          return _buildAppShell(home: home, themeMode: themeMode);
        },
      );
    }

    return _buildAppShell(home: home);
  }

  MaterialApp _buildAppShell({
    required Widget home,
    ThemeMode themeMode = ThemeMode.system,
  }) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jotsy',
      theme: _lightMaterialTheme.light(),
      darkTheme: _darkMaterialTheme.dark(),
      themeMode: themeMode,
      supportedLocales: const [Locale('en'), Locale('zh'), Locale('zh', 'CN')],
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
        return HomeHintVisibilityScope(
          controller: _homeHintVisibilityController,
          child: child,
        );
      },
      home: home,
    );
  }
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
