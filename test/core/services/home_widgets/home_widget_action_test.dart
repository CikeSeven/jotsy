import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/core/services/home_widgets/home_widget_action.dart';

void main() {
  group('HomeWidgetAction.parse', () {
    test('reads a mood for a day', () {
      final action =
          HomeWidgetAction.parse(
                Uri.parse(
                  'jotsy://widget-action/mood?day=2026-11-15&mood=good',
                ),
              )!
              as HomeWidgetSetMoodAction;
      expect(action.day, DateTime(2026, 11, 15));
      expect(action.mood, DayMood.good);
    });

    test('an empty mood clears the day', () {
      final action =
          HomeWidgetAction.parse(
                Uri.parse('jotsy://widget-action/mood?day=2026-11-15&mood='),
              )!
              as HomeWidgetSetMoodAction;
      expect(action.mood, isNull);
    });

    test('rejects broken or foreign links', () {
      for (final raw in <String>[
        'jotsy://widget-action/mood?day=2026-13-40&mood=good',
        'jotsy://widget-action/mood?day=2026-11-15&mood=ecstatic',
        'jotsy://widget-action/mood?mood=good',
        'jotsy://widget/mood?day=2026-11-15&mood=good',
        'https://widget-action/mood?day=2026-11-15&mood=good',
        'jotsy://widget-action/teleport',
      ]) {
        expect(HomeWidgetAction.parse(Uri.parse(raw)), isNull, reason: raw);
      }
      expect(HomeWidgetAction.parse(null), isNull);
    });
  });

  group('applyHomeWidgetAction', () {
    late AppDatabase database;

    setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => database.close());

    Future<Map<String, String>> moods() async => <String, String>{
      for (final row in await database.watchDayMoods().first) row.day: row.mood,
    };

    test('sets and then clears the mood of a day', () async {
      final day = DateTime(2026, 11, 15);
      expect(
        await applyHomeWidgetAction(
          database,
          HomeWidgetSetMoodAction(day: day, mood: DayMood.great),
        ),
        isTrue,
      );
      expect(await moods(), <String, String>{'2026-11-15': 'great'});
      expect(
        await applyHomeWidgetAction(
          database,
          HomeWidgetSetMoodAction(day: day, mood: null),
        ),
        isTrue,
      );
      expect(await moods(), isEmpty);
    });

    test('clearing a day without a mood writes nothing', () async {
      expect(
        await applyHomeWidgetAction(
          database,
          HomeWidgetSetMoodAction(day: DateTime(2026, 11, 15), mood: null),
        ),
        isFalse,
      );
    });
  });
}
