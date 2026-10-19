import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/app_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/ui/diaries/models/tag_picker_sort.dart';
import 'package:node_diary/ui/diaries/providers/tag_picker_sort_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 标签子页的排序方式：从设置读出，选择后写回，认不出的值回到默认。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, SettingsService)> containerWith(
    Map<String, Object> stored,
  ) async {
    SharedPreferences.setMockInitialValues(stored);
    final settings = await SettingsService.create();
    final container = ProviderContainer(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsServiceProvider.future);
    return (container, settings);
  }

  test('defaults to the custom order and remembers a choice', () async {
    final (container, settings) = await containerWith(const {});
    final subscription = container.listen(tagPickerSortProvider, (_, _) {});
    addTearDown(subscription.close);

    expect(container.read(tagPickerSortProvider), TagPickerSort.custom);
    container
        .read(tagPickerSortProvider.notifier)
        .select(TagPickerSort.alphabetical);
    expect(container.read(tagPickerSortProvider), TagPickerSort.alphabetical);
    await pumpEventQueue();
    expect(settings.tagPickerSortRaw, 'alphabetical');
  });

  test('reads the stored sort and falls back on unknown values', () async {
    final (stored, _) = await containerWith(const {
      'app.settings.tag_picker_sort': 'alphabetical',
    });
    expect(stored.read(tagPickerSortProvider), TagPickerSort.alphabetical);

    final (unknown, _) = await containerWith(const {
      'app.settings.tag_picker_sort': 'byColor',
    });
    expect(unknown.read(tagPickerSortProvider), TagPickerSort.custom);
  });
}
