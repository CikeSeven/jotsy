import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_diary/app/theme/theme.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/ui/home/pages/home_page.dart';

/// 应用根组件。
///
/// 负责：
/// 1. 等待设置服务初始化；
/// 2. 监听主题模式变化；
/// 3. 提供 MaterialApp 壳与首页入口。
class NodeDiaryApp extends ConsumerWidget {
  const NodeDiaryApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 设置服务是异步初始化的，这里统一处理加载态和错误态。
    final settingsAsync = ref.watch(settingsServiceProvider);

    return settingsAsync.when(
      loading:
          () => const MaterialApp(
            debugShowCheckedModeBanner: true,
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          ),
      error:
          (Object error, StackTrace stackTrace) => MaterialApp(
            home: Scaffold(body: Center(child: Text('初始化失败: $error'))),
          ),
      data: (settingsService) {
        // 主题对象只构建一次，通过 ValueListenableBuilder 动态切换模式。
        final materialTheme = MaterialTheme(Typography.material2021().black);
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: settingsService.themeModeNotifier,
          builder: (BuildContext context, ThemeMode themeMode, Widget? child) {
            return MaterialApp(
              debugShowCheckedModeBanner: true,
              title: 'Jotsy',
              theme: materialTheme.light(),
              darkTheme: materialTheme.dark(),
              themeMode: themeMode,
              home: const HomePage(),
            );
          },
        );
      },
    );
  }
}

