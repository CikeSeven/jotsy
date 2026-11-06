import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';

void main() {
  late AppDatabase db;
  final day = DateTime(2026, 11, 1, 9);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// 一篇日记；[geo] 给出时按自动定位的格式写进 metadata。
  Future<String> diary(
    String? location, {
    required int daysLater,
    String precision = 'township',
    ({double lat, double lng, Map<String, Object?> components})? geo,
    List<String>? notebookIds,
  }) {
    final context = <String, Object?>{
      'location': ?location,
      'locationPrecision': precision,
      if (geo != null)
        'geo': <String, Object?>{
          'source': 'amap_auto',
          'latitude': geo.lat,
          'longitude': geo.lng,
          'addressComponent': geo.components,
        },
    };
    return db.createDiary(
      title: location ?? 'none',
      contentDocJson: '[]',
      contentText: '',
      metadataJson: jsonEncode(<String, Object?>{'context': context}),
      notebookIds: notebookIds,
      createdAtOverride: day.add(Duration(days: daysLater)),
    );
  }

  test('places are grouped by label, newest first, with use counts', () async {
    await diary('杭州 · 西湖区', daysLater: 0);
    await diary('家', daysLater: 1);
    await diary('杭州 · 西湖区', daysLater: 2);
    await diary(null, daysLater: 3);
    await diary('   ', daysLater: 4);

    final places = await db.watchPlaceHistory().first;

    expect(places.map((place) => place.label), <String>['杭州 · 西湖区', '家']);
    expect(places.map((place) => place.uses), <int>[2, 1]);
    expect(places.first.lastUsedAt, day.add(const Duration(days: 2)));
  });

  test('coordinates and precision come from the newest diary', () async {
    await diary(
      '北京 · 朝阳区',
      daysLater: 0,
      precision: 'district',
      geo: (lat: 1, lng: 2, components: <String, Object?>{'city': 'old'}),
    );
    await diary(
      '北京 · 朝阳区',
      daysLater: 5,
      precision: 'district',
      geo: (
        lat: 39.98,
        lng: 116.48,
        components: <String, Object?>{'city': '北京市', 'district': '朝阳区'},
      ),
    );
    await diary('咖啡馆', daysLater: 1);

    final places = await db.watchPlaceHistory().first;
    final located = places.firstWhere((p) => p.label == '北京 · 朝阳区');
    expect(located.hasCoordinates, isTrue);
    expect(located.latitude, 39.98);
    expect(located.longitude, 116.48);
    expect(located.precision, 'district');
    expect(located.addressComponent, <String, Object?>{
      'city': '北京市',
      'district': '朝阳区',
    });

    final typed = places.firstWhere((p) => p.label == '咖啡馆');
    expect(typed.hasCoordinates, isFalse);
    expect(typed.addressComponent, isNull);
  });

  test('deleted and private diaries do not leak their places', () async {
    final locked = await db.createNotebook(
      name: 'secret',
      visibility: NotebookVisibility.locked,
    );
    await diary('公园', daysLater: 0);
    final deleted = await diary('医院', daysLater: 1);
    await db.softDeleteDiary(deleted);
    await diary('秘密基地', daysLater: 2, notebookIds: <String>[locked]);

    final places = await db.watchPlaceHistory().first;
    expect(places.map((place) => place.label), <String>['公园']);
  });

  test('a row with broken metadata does not break the list', () async {
    await diary('图书馆', daysLater: 0);
    await db.customStatement(
      "UPDATE diaries SET metadata = '{oops' WHERE title = 'none'",
    );
    await diary(null, daysLater: 1);
    await db.customStatement(
      "UPDATE diaries SET metadata = '{oops' WHERE title = 'none'",
    );

    final places = await db.watchPlaceHistory().first;
    expect(places.map((place) => place.label), <String>['图书馆']);
  });

  test('the list follows new diaries', () async {
    await diary('公司', daysLater: 0);
    final stream = db.watchPlaceHistory();
    final emissions = <List<String>>[];
    final subscription = stream.listen(
      (places) => emissions.add(<String>[for (final p in places) p.label]),
    );
    await pumpEventQueue();
    await diary('机场', daysLater: 1);
    await pumpEventQueue();
    await subscription.cancel();

    expect(emissions.last, <String>['机场', '公司']);
  });
}
