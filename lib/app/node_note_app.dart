import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:node_note/app/theme/theme.dart';
import 'package:node_note/core/services/app_service.dart';
import 'package:node_note/ui/home/pages/home_page.dart';

class NodeNoteApp extends ConsumerWidget {
  const NodeNoteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsServiceProvider);

    return settingsAsync.when(
      loading:
          () => const MaterialApp(
            home: Scaffold(body: Center(child: CircularProgressIndicator())),
          ),
      error:
          (Object error, StackTrace stackTrace) => MaterialApp(
            home: Scaffold(body: Center(child: Text('初始化失败: $error'))),
          ),
      data: (settingsService) {
        final materialTheme = MaterialTheme(Typography.material2021().black);
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: settingsService.themeModeNotifier,
          builder: (BuildContext context, ThemeMode themeMode, Widget? child) {
            return MaterialApp(
              title: 'Node Note',
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
