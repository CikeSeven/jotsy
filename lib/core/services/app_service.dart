import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import 'settings_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((Ref ref) {
  final database = AppDatabase();
  ref.onDispose(() {
    database.close();
  });
  return database;
});

final settingsServiceProvider = FutureProvider<SettingsService>((
  Ref ref,
) async {
  return SettingsService.create();
});

final tagListProvider = StreamProvider<List<Tag>>((Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchAllTags();
});
