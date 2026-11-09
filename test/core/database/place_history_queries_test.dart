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

  test(
    'a newer use without coordinates keeps the older located coordinates',
    () async {
      await diary(
        '杭州 · 西湖区',
        daysLater: 0,
        precision: 'district',
        geo: (
          lat: 30.25,
          lng: 120.13,
          components: <String, Object?>{'city': '杭州市', 'district': '西湖区'},
        ),
      );
      // 之后又手打了同一个地名：这篇没有 geo，层级也不同。
      await diary('杭州 · 西湖区', daysLater: 3, precision: 'township');

      final places = await db.watchPlaceHistory().first;
      final place = places.single;
      expect(place.uses, 2);
      expect(place.lastUsedAt, day.add(const Duration(days: 3)));
      expect(place.hasCoordinates, isTrue);
      expect(place.latitude, 30.25);
      expect(place.longitude, 120.13);
      // 层级与坐标取自同一篇，仍能按地址组件重组文案。
      expect(place.precision, 'district');
      expect(place.addressComponent, <String, Object?>{
        'city': '杭州市',
        'district': '西湖区',
      });
    },
  );

  test('a broken newer geo does not hide older valid coordinates', () async {
    await diary(
      '公司',
      daysLater: 0,
      geo: (lat: 31.2, lng: 121.5, components: <String, Object?>{}),
    );
    await db.createDiary(
      title: 'broken geo',
      contentDocJson: '[]',
      contentText: '',
      metadataJson: jsonEncode(<String, Object?>{
        'context': <String, Object?>{
          'location': '公司',
          'geo': <String, Object?>{'latitude': 'x', 'longitude': null},
        },
      }),
      createdAtOverride: day.add(const Duration(days: 2)),
    );

    final place = (await db.watchPlaceHistory().first).single;
    expect(place.uses, 2);
    expect(place.latitude, 31.2);
    expect(place.longitude, 121.5);
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
