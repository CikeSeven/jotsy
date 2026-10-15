import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_location.dart';
import 'package:node_diary/ui/diaries/models/new_diary_draft.dart';
import 'package:node_diary/ui/diaries/models/publish_metadata_composer.dart';

void main() {
  const components = <String, Object?>{
    'province': '北京市',
    'city': <Object?>[],
    'district': '朝阳区',
    'township': '望京街道',
    'streetNumber': {'street': '阜通东大街', 'number': '6号'},
  };

  test('address detail stops at the selected level for a municipality', () {
    const labels = {
      DiaryLocationPrecision.city: '北京市',
      DiaryLocationPrecision.district: '北京市 · 朝阳区',
      DiaryLocationPrecision.township: '北京市 · 望京街道',
      DiaryLocationPrecision.street: '北京市 · 朝阳区 · 阜通东大街',
      DiaryLocationPrecision.address: '北京市 · 朝阳区 · 阜通东大街6号',
    };
    for (final entry in labels.entries) {
      expect(DiaryLocationLabel.format(components, entry.key), entry.value);
    }
  });

  test('missing road or house number falls back without array text', () {
    expect(
      DiaryLocationLabel.format({
        ...components,
        'city': ['北京市'],
        'streetNumber': {'street': '阜通东大街', 'number': <Object?>[]},
      }, DiaryLocationPrecision.address),
      '北京市 · 朝阳区 · 阜通东大街',
    );
    expect(
      DiaryLocationLabel.format({
        ...components,
        'township': <Object?>[],
        'streetNumber': <Object?>[],
      }, DiaryLocationPrecision.address),
      '北京市 · 朝阳区',
    );
    expect(DiaryLocationLabel.format({}, DiaryLocationPrecision.city), isNull);
    expect(
      DiaryLocationLabel.format(null, DiaryLocationPrecision.address),
      isNull,
    );
  });

  test('city selection never falls back to more detailed address fields', () {
    expect(
      DiaryLocationLabel.format({
        'district': '朝阳区',
        'township': '望京街道',
      }, DiaryLocationPrecision.city),
      isNull,
    );
  });

  test('only labels generated for the current level follow a new level', () {
    const township = DiaryLocationPrecision.township;
    expect(
      DiaryLocationLabel.isAutoLabel(' 北京市 · 望京街道 ', components, township),
      isTrue,
    );
    // 旧版本自动定位后手改的地点，以及当前层级不同的文案都视为手动。
    expect(
      DiaryLocationLabel.isAutoLabel('望京 SOHO', components, township),
      isFalse,
    );
    expect(
      DiaryLocationLabel.isAutoLabel(
        '北京市',
        components,
        DiaryLocationPrecision.street,
      ),
      isFalse,
    );
    expect(DiaryLocationLabel.isAutoLabel('', components, township), isFalse);
    expect(DiaryLocationLabel.isAutoLabel('北京市', null, township), isFalse);
    // 所选层级本就没有可用字段时，空文案仍算自动文案，可继续切换层级。
    expect(
      DiaryLocationLabel.isAutoLabel('', {
        'district': '朝阳区',
      }, DiaryLocationPrecision.city),
      isTrue,
    );
  });

  test('draft round trip and copy preserve the selected address detail', () {
    const draft = NewDiaryDraft(
      title: 'Walk',
      contentDocJson: '[{"insert":"Walk\n"}]',
      contentText: 'Walk',
      locationPrecision: DiaryLocationPrecision.address,
      locationAddressComponent: components,
    );
    final restored = NewDiaryDraft.fromJson(
      (jsonDecode(jsonEncode(draft.toJson())) as Map).cast<String, Object?>(),
    );
    expect(restored.locationPrecision, DiaryLocationPrecision.address);
    expect(
      restored.copyWith(title: 'New title').locationPrecision,
      DiaryLocationPrecision.address,
    );
    expect(
      restored
          .copyWith(locationPrecision: DiaryLocationPrecision.city)
          .locationPrecision,
      DiaryLocationPrecision.city,
    );
    expect(restored.locationAddressComponent, components);
  });

  test(
    'legacy drafts and unknown address detail retain the township default',
    () {
      for (final value in [null, 'future_level', 3]) {
        expect(
          NewDiaryDraft.fromJson({
            'locationPrecision': value,
          }).locationPrecision,
          DiaryLocationPrecision.township,
        );
      }
    },
  );

  test('metadata remembers a selection even before a location is fetched', () {
    final metadata =
        jsonDecode(
              PublishMetadataComposer.compose(
                contentText: 'Walk',
                selectedTagIds: {},
                hasCover: false,
                deviceInfo: {},
                generatedAt: DateTime(2026),
                locationPrecision: DiaryLocationPrecision.city,
              ),
            )
            as Map;
    expect(metadata['context'], {'locationPrecision': 'city'});
  });
}
