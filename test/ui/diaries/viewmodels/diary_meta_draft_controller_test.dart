import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/location_resolver_service.dart';
import 'package:node_diary/core/services/qweather_weather_service.dart';
import 'package:node_diary/ui/diaries/models/diary_location.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';

void main() {
  const resolved = ResolvedLocation(
    latitude: 39.98941,
    longitude: 116.480881,
    addressComponent: <String, Object?>{
      'province': '北京市',
      'city': <Object?>[],
      'district': '朝阳区',
      'township': '望京街道',
    },
  );

  late DiaryMetaDraftController meta;
  late int notifications;

  setUp(() {
    meta = DiaryMetaDraftController();
    notifications = 0;
    meta.addListener(() => notifications++);
  });
  tearDown(() => meta.dispose());

  test('only real changes notify listeners', () {
    meta.setMood('🙂');
    meta.setMood('🙂');
    meta.setTagSelected(2, true);
    meta.setTagSelected(2, true);
    expect(notifications, 2);

    meta.locationText.text = 'Park';
    expect(notifications, 3);
    // 只移动光标/选区不算修改，否则点进输入框就会触发自动保存。
    meta.locationText.selection = const TextSelection.collapsed(offset: 2);
    meta.locationText.text = 'Park ';
    expect(notifications, 3);
    expect(meta.value.location, 'Park');
  });

  test('editing a located place keeps coordinates, clearing it drops geo', () {
    meta.applyResolvedLocation(resolved);
    expect(meta.locationText.text, '北京市 · 望京街道');
    expect(meta.value.locationFromAuto, isTrue);

    meta.locationText.text = '北京市 · 望京街道 · 咖啡馆';
    expect(meta.value.locationFromAuto, isTrue);
    expect(meta.value.locationLatitude, resolved.latitude);

    meta.locationText.text = '';
    expect(meta.value.location, isNull);
    expect(meta.value.locationFromAuto, isFalse);
    // 内存坐标留给天气查询。
    expect(meta.value.hasCoordinates, isTrue);
  });

  test('typing weather clears the icon, fetched weather keeps it', () {
    meta.applyWeather(
      const QWeatherNow(
        weatherText: 'Sunny',
        temperatureCelsius: '24',
        iconCode: '100',
      ),
    );
    expect(meta.weatherText.text, 'Sunny 24℃');
    expect(meta.value.weatherIconCode, '100');

    meta.weatherText.text = 'Sunny, windy';
    expect(meta.value.weather, 'Sunny, windy');
    expect(meta.value.weatherIconCode, isNull);
  });

  test('a precision change rewrites only an automatic place label', () {
    meta.applyResolvedLocation(resolved);
    meta.setPrecision(DiaryLocationPrecision.district);
    expect(meta.locationText.text, '北京市 · 朝阳区');
    expect(meta.value.location, '北京市 · 朝阳区');

    meta.locationText.text = 'My cafe';
    meta.setPrecision(DiaryLocationPrecision.city);
    expect(meta.locationText.text, 'My cafe');
    expect(meta.value.locationPrecision, DiaryLocationPrecision.city);
  });

  test('restore fills the fields without counting as user edits', () {
    meta.restore(const DiaryMetaDraft(weather: 'Rain', weatherIconCode: '305'));
    expect(meta.weatherText.text, 'Rain');
    expect(meta.value.weatherIconCode, '305');
    expect(notifications, 1);
  });

  test('energy is clamped and a capsule is stored normalised', () {
    meta.setEnergy(7);
    expect(meta.value.energyLevel, 5);
    meta.setEnergy(null);
    expect(meta.value.energyLevel, isNull);

    meta.setCapsule(
      TimeCapsuleSchedule(
        unlockAt: DateTime(2027, 5, 20, 18, 45),
        precision: TimeCapsulePrecision.date,
      ),
    );
    expect(meta.value.capsule?.unlockAt, DateTime(2027, 5, 20));
  });
}
