import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';
import 'package:node_diary/ui/widgets/app_loading_page.dart';

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
  static const Duration _minimumLoadingDuration = Duration(milliseconds: 2000);

  late final MaterialTheme _lightMaterialTheme;
  late final MaterialTheme _darkMaterialTheme;
  Timer? _minimumLoadingTimer;
  bool _minimumLoadingElapsed = false;

  @override
  void initState() {
    super.initState();
    _lightMaterialTheme = MaterialTheme(Typography.material2021().black);
    _darkMaterialTheme = MaterialTheme(Typography.material2021().white);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 设置服务是异步初始化的，这里统一处理加载态和错误态。
    final settingsAsync = ref.watch(settingsServiceProvider);

    // 最短加载时长和数据加载状态都满足后，才进入应用首页。
    if (!_minimumLoadingElapsed || settingsAsync.isLoading) {
      return _buildAppShell(home: const AppLoadingPage());
    }

    return settingsAsync.when(
      loading: () => _buildAppShell(home: const AppLoadingPage()),
      error:
          (Object error, StackTrace stackTrace) => _buildAppShell(
            home: Scaffold(body: Center(child: Text('初始化失败: $error'))),
          ),
      data: (settingsService) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: settingsService.themeModeNotifier,
          builder: (BuildContext context, ThemeMode themeMode, Widget? child) {
            return _buildAppShell(home: const HomePage(), themeMode: themeMode);
          },
        );
      },
    );
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
      home: home,
    );
  }
}
