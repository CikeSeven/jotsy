import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/models/diary_search_filters.dart';
import 'package:node_diary/ui/diaries/models/diary_search_preferences.dart';

void main() {
  group('DiarySearchFilters', () {
    test('no rules means no predicate, and archived alone is not a rule', () {
      expect(DiarySearchFilters.none.predicate(), isNull);
      expect(DiarySearchFilters.none.isActive, isFalse);
      final archived = DiarySearchFilters.none.withIncludeArchived(true);
      expect(archived.isActive, isTrue);
      expect(archived.rules, isEmpty);
      expect(archived.predicate(), isNull);
    });

    test('slots map to their own rule and clear with null', () {
      final mood = NotebookMoodRule(emojis: <String>['😊']);
      final rain = NotebookTextRule(
        field: NotebookTextField.weather,
        text: '雨',
      );
      final kyoto = NotebookTextRule(
        field: NotebookTextField.location,
        text: '京都',
      );
      var filters = DiarySearchFilters.none
          .withSlot(DiarySearchFilterSlot.mood, mood)
          .withSlot(DiarySearchFilterSlot.weather, rain)
          .withSlot(DiarySearchFilterSlot.location, kyoto);
      expect(filters.ruleOf(DiarySearchFilterSlot.mood), mood);
      expect(filters.ruleOf(DiarySearchFilterSlot.weather), rain);
      expect(filters.ruleOf(DiarySearchFilterSlot.location), kyoto);
      expect(filters.rules, <NotebookRule>[mood, rain, kyoto]);

      // 类型不符的规则按清除处理，不会串到别的槽位。
      filters = filters.withSlot(DiarySearchFilterSlot.weather, kyoto);
      expect(filters.weather, isNull);
      expect(filters.location, kyoto);

      filters = filters.withSlot(DiarySearchFilterSlot.mood, null);
      expect(filters.mood, isNull);
      expect(filters.rules, <NotebookRule>[kyoto]);
    });

    test('equal filters compile to equal predicates on the same day', () {
      DiarySearchFilters build() => DiarySearchFilters(
        date: NotebookDateRule.lastDays(30),
        media: const NotebookMediaRule(NotebookMediaKind.image),
      );
      final morning = DateTime(2026, 11, 7, 8);
      final evening = DateTime(2026, 11, 7, 22);
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build().predicate(now: morning), build().predicate(now: evening));
      expect(
        build().predicate(now: morning),
        isNot(build().predicate(now: DateTime(2026, 11, 8, 8))),
      );
    });
  });

  group('DiarySearchPreferences', () {
    test('remember moves an existing entry to the front, case-insensitive', () {
      final prefs = DiarySearchPreferences()
          .remember('京都')
          .remember('Rain')
          .remember('  rain  ');
      expect(prefs.recent, <String>['rain', '京都']);
      expect(prefs.remember('   '), prefs);
    });

    test('keeps at most maxRecent entries, newest first', () {
      var prefs = DiarySearchPreferences();
      for (var i = 0; i < DiarySearchPreferences.maxRecent + 3; i++) {
        prefs = prefs.remember('q$i');
      }
      expect(prefs.recent, hasLength(DiarySearchPreferences.maxRecent));
      expect(prefs.recent.first, 'q${DiarySearchPreferences.maxRecent + 2}');
    });

    test('forget, clear and sort round-trip through JSON', () {
      final prefs = DiarySearchPreferences()
          .remember('a')
          .remember('b')
          .forget('a')
          .withSort(DiarySearchSort.createdAsc);
      final decoded = DiarySearchPreferences.decode(prefs.encode());
      expect(decoded, prefs);
      expect(decoded.recent, <String>['b']);
      expect(decoded.sort, DiarySearchSort.createdAsc);
      expect(decoded.clearRecent().recent, isEmpty);
      expect(decoded.clearRecent().sort, DiarySearchSort.createdAsc);
    });

    test('decoding tolerates bad JSON and bad fields', () {
      expect(DiarySearchPreferences.decode(null), DiarySearchPreferences());
      expect(DiarySearchPreferences.decode('{oops'), DiarySearchPreferences());
      expect(DiarySearchPreferences.decode('[1,2]'), DiarySearchPreferences());
      final partial = DiarySearchPreferences.decode(
        '{"recent":["  x  ", 3, "", "X", "y"],"sort":"nope"}',
      );
      expect(partial.recent, <String>['x', 'y']);
      expect(partial.sort, DiarySearchSort.updatedDesc);
    });
  });
}
