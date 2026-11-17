import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_view_preferences.dart';

DiarySortMode _parseSort(String raw) =>
    DiaryViewPreferences.fromRaw(sortRaw: raw, layoutRaw: 'list').sortMode;

void main() {
  test('sort values saved by earlier versions keep their meaning', () {
    expect(_parseSort('updatedDesc'), DiarySortMode.updatedDesc);
    expect(_parseSort('updatedAsc'), DiarySortMode.updatedAsc);
    expect(_parseSort('titleAsc'), DiarySortMode.titleAsc);
  });

  test('every sort mode round-trips through its stored name', () {
    for (final mode in DiarySortMode.values) {
      expect(_parseSort(mode.name), mode);
    }
  });

  test('unknown sort values fall back to most recently updated first', () {
    expect(_parseSort(''), DiarySortMode.updatedDesc);
    expect(_parseSort('relevanceDesc'), DiarySortMode.updatedDesc);
  });

  DiaryLayoutMode parseLayout(String raw) =>
      DiaryViewPreferences.fromRaw(sortRaw: '', layoutRaw: raw).layoutMode;

  test('saved layout choices keep their meaning', () {
    expect(parseLayout('waterfall'), DiaryLayoutMode.waterfall);
    expect(parseLayout('list'), DiaryLayoutMode.list);
  });

  test('empty or unknown layout values fall back to the waterfall default', () {
    expect(parseLayout(''), DiaryLayoutMode.waterfall);
    expect(parseLayout('grid'), DiaryLayoutMode.waterfall);
  });
}
