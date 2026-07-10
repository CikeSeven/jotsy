# Configurable Diary Card Tag Limit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persisted `0–20` diary-card tag display limit, defaulting to `2`, that updates every diary list surface immediately and survives backup/restore.

**Architecture:** `SettingsService` owns normalization, persistence, and a `ValueNotifier<int>`. A Riverpod stream provider bridges notifier changes to the three diary pages, which pass the value through `DiariesListSection` into the pure `DiaryItemTagRow`. A focused settings section edits the value with a discrete Slider, while `DataArchiveService` includes it in backup payloads.

**Tech Stack:** Flutter, Dart, Riverpod, SharedPreferences, Flutter gen-l10n, flutter_test

---

### Task 1: Persist and publish the tag limit

**Files:**
- Modify: `test/core/services/settings_service_test.dart`
- Modify: `lib/core/services/settings_service.dart`
- Modify: `lib/core/services/app_service.dart`

- [ ] **Step 1: Write failing SettingsService tests**

Add a `SettingsService diary card tag limit` group covering the default, persisted values, notifier updates, and invalid stored bounds:

```dart
group('SettingsService diary card tag limit', () {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('defaults to two visible diary card tags', () async {
    final settings = await SettingsService.create();
    expect(settings.diaryCardTagLimit, 2);
  });

  test('persists normalized diary card tag limits and notifies', () async {
    final settings = await SettingsService.create();
    final values = <int>[];
    settings.diaryCardTagLimitNotifier.addListener(() {
      values.add(settings.diaryCardTagLimitNotifier.value);
    });

    await settings.setDiaryCardTagLimit(0);
    await settings.setDiaryCardTagLimit(99);

    expect(values, <int>[0, 20]);
    expect((await SettingsService.create()).diaryCardTagLimit, 20);
  });

  test('normalizes out-of-range stored diary card tag limits', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.diary_card_tag_limit': -4,
    });
    expect((await SettingsService.create()).diaryCardTagLimit, 0);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.diary_card_tag_limit': 40,
    });
    expect((await SettingsService.create()).diaryCardTagLimit, 20);
  });

  test('falls back when the stored diary card tag limit is invalid', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.settings.diary_card_tag_limit': 'invalid',
    });

    expect((await SettingsService.create()).diaryCardTagLimit, 2);
  });
});
```

- [ ] **Step 2: Run the service tests and verify RED**

Run: `flutter test test/core/services/settings_service_test.dart`

Expected: compilation fails because `diaryCardTagLimit`, its notifier, and setter do not exist.

- [ ] **Step 3: Implement normalized persistence**

Add constants, constructor input, notifier, key, startup normalization, getter, setter, and helper:

```dart
static const int defaultDiaryCardTagLimit = 2;
static const int minDiaryCardTagLimit = 0;
static const int maxDiaryCardTagLimit = 20;

final ValueNotifier<int> diaryCardTagLimitNotifier;
static const _keyDiaryCardTagLimit = 'app.settings.diary_card_tag_limit';

int get diaryCardTagLimit => diaryCardTagLimitNotifier.value;

Future<void> setDiaryCardTagLimit(int value) async {
  final normalized = _normalizeDiaryCardTagLimit(value);
  diaryCardTagLimitNotifier.value = normalized;
  await _prefs.setInt(_keyDiaryCardTagLimit, normalized);
}

static int _normalizeDiaryCardTagLimit(int value) {
  return value.clamp(minDiaryCardTagLimit, maxDiaryCardTagLimit).toInt();
}
```

During `create()`, read the key with `prefs.get(...)`, accept only an `int`, normalize it, and rewrite absent, wrong-type, or out-of-range values so disk state matches runtime state. Initialize the notifier from the normalized constructor argument.

- [ ] **Step 4: Add the responsive provider**

In `app_service.dart`, mirror the existing `moodOptionsProvider` bridge:

```dart
final diaryCardTagLimitProvider = StreamProvider<int>((Ref ref) async* {
  final settings = await ref.watch(settingsServiceProvider.future);
  yield settings.diaryCardTagLimit;

  final controller = StreamController<int>();
  void listener() => controller.add(settings.diaryCardTagLimit);
  settings.diaryCardTagLimitNotifier.addListener(listener);
  ref.onDispose(() {
    settings.diaryCardTagLimitNotifier.removeListener(listener);
    unawaited(controller.close());
  });
  yield* controller.stream;
});
```

- [ ] **Step 5: Run the service tests and verify GREEN**

Run: `flutter test test/core/services/settings_service_test.dart`

Expected: all SettingsService tests pass.

- [ ] **Step 6: Commit the settings core**

```bash
git add lib/core/services/settings_service.dart lib/core/services/app_service.dart test/core/services/settings_service_test.dart
git commit -m "feat: persist diary card tag limit"
```

### Task 2: Make tag rendering configurable and overflow-safe

**Files:**
- Create: `test/ui/diaries/widgets/diary_item_tag_row_test.dart`
- Modify: `lib/ui/diaries/widgets/diary_item_tag_row.dart`

- [ ] **Step 1: Write failing widget tests**

Pump `DiaryItemTagRow` in a narrow `SizedBox` with generated `Tag` records. Assert that limit `2` displays the first two labels plus `+2`, limit `0` renders no labels or summary, and limit `20` produces no Flutter exception at narrow width:

```dart
final tags = List<Tag>.generate(
  4,
  (index) => Tag(
    id: index + 1,
    name: 'Tag ${index + 1}',
    color: 0xFF1565C0,
  ),
);

expect(find.textContaining('Tag 1'), findsOneWidget);
expect(find.textContaining('Tag 2'), findsOneWidget);
expect(find.textContaining('Tag 3'), findsNothing);
expect(find.text('+2'), findsOneWidget);
```

Use a separate test with 20 long labels in a 150-pixel container and assert `tester.takeException()` is null.

- [ ] **Step 2: Run the widget test and verify RED**

Run: `flutter test test/ui/diaries/widgets/diary_item_tag_row_test.dart`

Expected: compilation fails because `maxVisibleTags` is not accepted.

- [ ] **Step 3: Implement the parameter and wrapping layout**

Replace the private hard-coded limit with a required `maxVisibleTags` parameter. Clamp negative direct-call values to zero, return `SizedBox.shrink()` for zero or empty tags, and render the visible labels plus optional `+N` with `Wrap(spacing: 8, runSpacing: 4)`. Keep each label at `maxLines: 1` with ellipsis so a single long label cannot overflow its card.

```dart
final visibleLimit = maxVisibleTags.clamp(0, tags.length).toInt();
if (visibleLimit == 0 || tags.isEmpty) {
  return const SizedBox.shrink();
}
final visibleTags = tags.take(visibleLimit).toList(growable: false);
final hiddenCount = tags.length - visibleTags.length;
```

- [ ] **Step 4: Run the widget test and verify GREEN**

Run: `flutter test test/ui/diaries/widgets/diary_item_tag_row_test.dart`

Expected: all tag-row tests pass with no overflow exception.

- [ ] **Step 5: Commit the rendering unit**

```bash
git add lib/ui/diaries/widgets/diary_item_tag_row.dart test/ui/diaries/widgets/diary_item_tag_row_test.dart
git commit -m "feat: render configurable diary card tags"
```

### Task 3: Wire all diary list surfaces

**Files:**
- Modify: `test/ui/diaries/sections/diaries_list_section_test.dart`
- Modify: `lib/ui/diaries/sections/diaries_list_section.dart`
- Modify: `lib/ui/diaries/pages/diaries_page.dart`
- Modify: `lib/ui/diaries/pages/diary_search_page.dart`
- Modify: `lib/ui/diaries/pages/archived_diaries_page.dart`

- [ ] **Step 1: Add failing section tests**

Create an unlocked diary with three tags. Pump `DiariesListSection(maxVisibleTags: 1, ...)` and assert one tag plus `+2`; pump with `maxVisibleTags: 0` and assert no tag text and no `+3`. Retain the existing locked-capsule assertion to ensure tags stay hidden there.

- [ ] **Step 2: Run the section test and verify RED**

Run: `flutter test test/ui/diaries/sections/diaries_list_section_test.dart`

Expected: compilation fails because `maxVisibleTags` is not defined on `DiariesListSection`.

- [ ] **Step 3: Pass the value through the shared section**

Add `required this.maxVisibleTags` and `final int maxVisibleTags` to `DiariesListSection`. Change both tag-row calls to:

```dart
DiaryItemTagRow(tags: diary.tags, maxVisibleTags: maxVisibleTags)
```

Use `final hasVisibleTags = diary.tags.isNotEmpty && maxVisibleTags > 0;` for spacing conditions, so zero leaves no empty gap.

- [ ] **Step 4: Watch the provider in every page**

In each Consumer page build method, resolve:

```dart
final diaryCardTagLimit =
    ref.watch(diaryCardTagLimitProvider).asData?.value ??
    SettingsService.defaultDiaryCardTagLimit;
```

Pass `maxVisibleTags: diaryCardTagLimit` at the homepage, search page, and archived page `DiariesListSection` call sites. Add a `settings_service.dart` import where the default constant is not already imported.

- [ ] **Step 5: Run section and tag-row tests**

Run: `flutter test test/ui/diaries/sections/diaries_list_section_test.dart test/ui/diaries/widgets/diary_item_tag_row_test.dart`

Expected: all tests pass; locked cards still hide labels.

- [ ] **Step 6: Commit cross-page wiring**

```bash
git add lib/ui/diaries/sections/diaries_list_section.dart lib/ui/diaries/pages/diaries_page.dart lib/ui/diaries/pages/diary_search_page.dart lib/ui/diaries/pages/archived_diaries_page.dart test/ui/diaries/sections/diaries_list_section_test.dart
git commit -m "feat: apply tag limit across diary lists"
```

### Task 4: Add the localized settings control

**Files:**
- Create: `lib/ui/settings/sections/settings_diary_card_section.dart`
- Create: `test/ui/settings/settings_diary_card_section_test.dart`
- Modify: `lib/ui/settings/pages/appearance_language_page.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`
- Regenerate: `lib/l10n/app_localizations_gen.dart`
- Regenerate: `lib/l10n/app_localizations_gen_en.dart`
- Regenerate: `lib/l10n/app_localizations_gen_zh.dart`

- [ ] **Step 1: Add ARB messages with metadata**

Add keys for the title, hidden state, and visible count. The count message must declare an `int` placeholder:

```json
"settingsDiaryCardTagLimit": "Diary card tags",
"@settingsDiaryCardTagLimit": {"description": "Title for the maximum visible tag count on diary cards."},
"settingsDiaryCardTagLimitHidden": "Do not show tags",
"@settingsDiaryCardTagLimitHidden": {"description": "Current-value label when diary card tags are hidden."},
"settingsDiaryCardTagLimitValue": "Show up to {count} tags",
"@settingsDiaryCardTagLimitValue": {
  "description": "Current maximum visible tag count on diary cards.",
  "placeholders": {"count": {"type": "int"}}
}
```

Use equivalent Chinese strings: `日记卡片标签`, `不显示标签`, `最多显示 {count} 个标签`.

- [ ] **Step 2: Run localization generation**

Run: `flutter gen-l10n`

Expected: exit 0 and all three generated localization files expose the new getters/method.

- [ ] **Step 3: Write the failing settings widget test**

Use mocked SharedPreferences and a real `SettingsService`. Pump `SettingsDiaryCardSection`, tap the tile, move the Slider to `5`, tap `commonConfirm`, and assert the service value and tile subtitle update to `5`. Add a cancellation test that leaves the original value unchanged.

- [ ] **Step 4: Run the settings widget test and verify RED**

Run: `flutter test test/ui/settings/settings_diary_card_section_test.dart`

Expected: compilation fails because `SettingsDiaryCardSection` does not exist.

- [ ] **Step 5: Implement the focused section**

Create a stateless section that listens to `settings.diaryCardTagLimitNotifier`. Its ListTile opens a `StatefulBuilder` AlertDialog containing a discrete Slider:

```dart
Slider(
  value: currentValue.toDouble(),
  min: SettingsService.minDiaryCardTagLimit.toDouble(),
  max: SettingsService.maxDiaryCardTagLimit.toDouble(),
  divisions: SettingsService.maxDiaryCardTagLimit,
  label: valueLabel(currentValue),
  onChanged: (value) {
    setDialogState(() => currentValue = value.round());
  },
)
```

Use gray semantic foreground for Cancel and primary foreground for Confirm. Persist only after confirmation. In `AppearanceLanguagePage`, insert the new section between the theme section and language tile with dividers.

- [ ] **Step 6: Run the settings widget test and verify GREEN**

Run: `flutter test test/ui/settings/settings_diary_card_section_test.dart`

Expected: save and cancellation tests pass.

- [ ] **Step 7: Commit the UI and localizations**

```bash
git add lib/ui/settings/sections/settings_diary_card_section.dart lib/ui/settings/pages/appearance_language_page.dart lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/app_localizations_gen.dart lib/l10n/app_localizations_gen_en.dart lib/l10n/app_localizations_gen_zh.dart test/ui/settings/settings_diary_card_section_test.dart
git commit -m "feat: configure diary card tag display"
```

### Task 5: Preserve the preference in backups and verify the feature

**Files:**
- Modify: `test/core/services/data_archive_service_source_test.dart`
- Modify: `lib/core/services/data_archive_service.dart`

- [ ] **Step 1: Write a failing backup source test**

Add an assertion that export and restore both mention the exact payload key and SettingsService setter:

```dart
test('backup preserves the diary card tag limit', () async {
  final source = await File(
    'lib/core/services/data_archive_service.dart',
  ).readAsString();

  expect(source, contains("'diaryCardTagLimit': settingsService.diaryCardTagLimit"));
  expect(source, contains("settingsNode['diaryCardTagLimit']"));
  expect(source, contains('settingsService.setDiaryCardTagLimit'));
});
```

- [ ] **Step 2: Run the backup source test and verify RED**

Run: `flutter test test/core/services/data_archive_service_source_test.dart`

Expected: the new backup-preservation test fails.

- [ ] **Step 3: Implement compatible export and restore**

Add `'diaryCardTagLimit': settingsService.diaryCardTagLimit` to the settings payload. During restore, accept `int`, `num`, or parseable String and call `setDiaryCardTagLimit`; omit the call when an old backup has no valid field so the default remains intact.

- [ ] **Step 4: Run focused tests**

Run: `flutter test test/core/services/settings_service_test.dart test/core/services/data_archive_service_source_test.dart test/ui/diaries/widgets/diary_item_tag_row_test.dart test/ui/diaries/sections/diaries_list_section_test.dart test/ui/settings/settings_diary_card_section_test.dart`

Expected: all focused tests pass.

- [ ] **Step 5: Format and analyze**

Run: `dart format lib/core/services/settings_service.dart lib/core/services/app_service.dart lib/core/services/data_archive_service.dart lib/ui/diaries/widgets/diary_item_tag_row.dart lib/ui/diaries/sections/diaries_list_section.dart lib/ui/diaries/pages/diaries_page.dart lib/ui/diaries/pages/diary_search_page.dart lib/ui/diaries/pages/archived_diaries_page.dart lib/ui/settings/sections/settings_diary_card_section.dart lib/ui/settings/pages/appearance_language_page.dart test/core/services/settings_service_test.dart test/core/services/data_archive_service_source_test.dart test/ui/diaries/widgets/diary_item_tag_row_test.dart test/ui/diaries/sections/diaries_list_section_test.dart test/ui/settings/settings_diary_card_section_test.dart`

Run: `flutter analyze`

Expected: formatter exits 0; analyzer reports no issues.

- [ ] **Step 6: Run the full test suite**

Run: `flutter test`

Expected: all tests pass.

- [ ] **Step 7: Commit backup support and verification changes**

```bash
git add lib/core/services/data_archive_service.dart test/core/services/data_archive_service_source_test.dart
git commit -m "feat: back up diary card tag limit"
```
