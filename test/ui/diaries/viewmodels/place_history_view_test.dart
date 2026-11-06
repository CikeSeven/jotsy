import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/viewmodels/place_history_view.dart';

DiaryPlaceUsage _place(String label) =>
    DiaryPlaceUsage(label: label, uses: 1, lastUsedAt: DateTime(2026));

void main() {
  test('a located label splits into its most specific level and region', () {
    final parts = PlaceLabelParts.of('杭州 · 西湖区 · 文三路');
    expect(parts.name, '文三路');
    expect(parts.region, '杭州 · 西湖区');

    final typed = PlaceLabelParts.of('外婆家');
    expect(typed.name, '外婆家');
    expect(typed.region, isNull);
  });

  test('chips use the short name unless two places would read the same', () {
    final labels = placeChipLabels(<DiaryPlaceUsage>[
      _place('北京 · 朝阳区'),
      _place('长春 · 朝阳区'),
      _place('杭州 · 西湖区'),
      _place('家'),
    ]);
    expect(labels, <String>['北京 · 朝阳区', '长春 · 朝阳区', '西湖区', '家']);
  });

  test('search matches names and pinyin, keeping the recent-first order', () {
    final places = <DiaryPlaceUsage>[
      _place('杭州 · 西湖区'),
      _place('Coffee House'),
      _place('上海 · 徐汇区'),
    ];
    expect(filterPlaces(places, ''), same(places));
    expect(filterPlaces(places, 'xihu').map((p) => p.label), <String>[
      '杭州 · 西湖区',
    ]);
    expect(filterPlaces(places, 'sh').map((p) => p.label), <String>[
      '上海 · 徐汇区',
    ]);
    expect(filterPlaces(places, 'coffee').map((p) => p.label), <String>[
      'Coffee House',
    ]);
    expect(filterPlaces(places, '东京'), isEmpty);
  });
}
