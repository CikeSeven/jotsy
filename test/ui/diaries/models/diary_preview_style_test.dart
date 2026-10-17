import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_code.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_behavior.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_presets.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_settings.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style.dart';
import 'package:node_diary/ui/diaries/models/diary_preview_style/diary_preview_style_code.dart';

/// 每个字段都不是默认值的样式，用于往返测试。
const _everything = DiaryPreviewStyle(
  page: DiaryPreviewPageStyle(
    colorSeed: DiaryPreviewColorSeed.custom,
    seedColor: 0xFF336699,
    paper: DiaryPreviewPaper.custom,
    paperLight: 0xFFF4ECD8,
    paperDark: 0xFF2B261E,
    textLight: 0xFF333333,
    textDark: 0xFFDDDDDD,
    horizontalPadding: 30,
    limitWidth: true,
    contentWidth: 720,
    topBar: DiaryPreviewTopBarMode.pinned,
    topBarTitle: DiaryPreviewTopBarTitle.position,
    showTypographyButton: false,
    showEditButton: false,
    showShareButton: true,
    progress: DiaryPreviewProgress.line,
    backToTop: true,
  ),
  cover: DiaryPreviewCoverStyle(
    mode: DiaryPreviewCoverMode.inset,
    height: 300,
    fit: DiaryPreviewCoverFit.cover,
    radius: 24,
    fadeOnScroll: false,
    useFirstImage: false,
  ),
  title: DiaryPreviewTitleStyle(
    visible: false,
    showUntitled: false,
    scale: 1.4,
    weight: DiaryPreviewTitleWeight.medium,
    align: DiaryPreviewAlign.center,
    colorLight: 0xFF112233,
    colorDark: 0xFFCCDDEE,
  ),
  meta: DiaryPreviewMetaStyle(
    position: DiaryPreviewMetaPosition.end,
    layout: DiaryPreviewMetaLayout.card,
    showDate: false,
    showLocation: false,
    showWeather: false,
    showMood: false,
    showEnergy: false,
    showTags: false,
    showWordCount: false,
    showReadingTime: false,
    dateFormat: DiaryCardDateFormat.numeric,
    showWeekday: true,
    showTime: true,
    dateSource: DiaryCardDateSource.updated,
    datePrefix: false,
    tagStyle: DiaryCardTagStyle.dot,
    chipStyle: DiaryPreviewChipStyle.plain,
  ),
  body: DiaryPreviewBodyStyle(
    showEmptyHint: false,
    showLastEdited: false,
    editedFormat: DiaryPreviewEditedFormat.full,
    showCapsuleInsight: false,
  ),
  navigation: DiaryPreviewNavigationStyle(
    transition: DiaryPreviewPageTransition.stack,
    neighborCards: true,
    edgeHint: false,
  ),
);

void main() {
  test('the default style encodes as an empty object', () {
    expect(DiaryPreviewStyle.defaults.toJson(), isEmpty);
    expect(DiaryPreviewSettings.defaults.encode(), isNull);
    expect(DiaryPreviewSettings.decode(null), DiaryPreviewSettings.defaults);
    expect(
      DiaryPreviewSettings.decode('not json'),
      DiaryPreviewSettings.defaults,
    );
    expect(DiaryPreviewSettings.decode('[1]'), DiaryPreviewSettings.defaults);
  });

  test('every field survives a round trip', () {
    final json = _everything.toJson();
    expect(
      DiaryPreviewStyle.fromJson(jsonDecode(jsonEncode(json))),
      _everything,
    );
    // 每个分组都有写入。
    expect(
      json.keys,
      containsAll(<String>[
        'page',
        'cover',
        'title',
        'meta',
        'body',
        'navigation',
      ]),
    );
  });

  test('paging defaults keep swiping on with the plain slide', () {
    const behavior = DiaryPreviewBehavior.defaults;
    expect(behavior.swipeBetweenDiaries, isTrue);
    expect(behavior.swipeSensitivity, DiaryPreviewSwipeSensitivity.standard);
    expect(behavior.hapticOnPage, isFalse);
    const navigation = DiaryPreviewNavigationStyle();
    expect(navigation.transition, DiaryPreviewPageTransition.slide);
    expect(navigation.neighborCards, isFalse);
    expect(navigation.edgeHint, isTrue);
    expect(behavior.toJson(), isEmpty);
  });

  test('paging behavior round trips and tolerates broken fields', () {
    const behavior = DiaryPreviewBehavior(
      swipeBetweenDiaries: false,
      swipeSensitivity: DiaryPreviewSwipeSensitivity.strict,
      hapticOnPage: true,
    );
    expect(
      DiaryPreviewBehavior.fromJson(jsonDecode(jsonEncode(behavior.toJson()))),
      behavior,
    );
    final broken = DiaryPreviewBehavior.fromJson(<String, Object?>{
      'swipeBetweenDiaries': 'no',
      'swipeSensitivity': 'turbo',
      'hapticOnPage': true,
    });
    expect(broken.swipeBetweenDiaries, isTrue);
    expect(broken.swipeSensitivity, DiaryPreviewSwipeSensitivity.standard);
    expect(broken.hapticOnPage, isTrue);
    final navigation = DiaryPreviewStyle.fromJson(<String, Object?>{
      'navigation': <String, Object?>{'transition': 'warp', 'edgeHint': false},
    }).navigation;
    expect(navigation.transition, DiaryPreviewPageTransition.slide);
    expect(navigation.edgeHint, isFalse);
  });

  test('presets and style codes leave the paging behavior alone', () {
    const behavior = DiaryPreviewBehavior(swipeBetweenDiaries: false);
    const settings = DiaryPreviewSettings(behavior: behavior);
    final applied = settings.withCurrent(
      DiaryPreviewPresets.styleOf(DiaryPreviewPresetId.immersive),
    );
    expect(applied.behavior, behavior);
  });

  test('the long image mode is reading behavior that survives presets', () {
    const behavior = DiaryPreviewBehavior(
      longImageMode: DiaryPreviewLongImageMode.full,
    );
    const settings = DiaryPreviewSettings(behavior: behavior);
    expect(DiaryPreviewSettings.decode(settings.encode()), settings);
    expect(
      settings
          .withCurrent(DiaryPreviewPresets.styleOf(DiaryPreviewPresetId.night))
          .behavior
          .longImageMode,
      DiaryPreviewLongImageMode.full,
    );
    // 默认值不写入；读不懂的值回到折叠。
    expect(DiaryPreviewBehavior.defaults.toJson(), isEmpty);
    expect(
      DiaryPreviewBehavior.fromJson(<String, Object?>{
        'longImageMode': 'zoom',
      }).longImageMode,
      DiaryPreviewLongImageMode.fold,
    );
  });

  test('settings keep the current style, saved styles and behavior', () {
    final settings = const DiaryPreviewSettings(
      current: _everything,
      behavior: DiaryPreviewBehavior(todoToggle: false, textSelection: false),
    ).addSaved('夜读', DiaryPreviewPresets.styleOf(DiaryPreviewPresetId.night));
    final decoded = DiaryPreviewSettings.decode(settings.encode());
    expect(decoded, settings);
    expect(decoded.saved.single.name, '夜读');

    // 保存项的增删改不动阅读行为。
    final renamed = decoded.renameSaved(decoded.saved.single.id, '深夜');
    expect(renamed.behavior, settings.behavior);
    expect(renamed.saved.single.name, '深夜');

    // 只改了阅读行为也要写入。
    const onlyBehavior = DiaryPreviewSettings(
      behavior: DiaryPreviewBehavior(todoToggle: false),
    );
    expect(DiaryPreviewSettings.decode(onlyBehavior.encode()), onlyBehavior);
  });

  test('a broken field only resets itself', () {
    final style = DiaryPreviewStyle.fromJson(<String, Object?>{
      'page': <String, Object?>{
        'horizontalPadding': 'wide',
        'paper': 'sepia',
        'seedColor': '#12',
      },
      'cover': <String, Object?>{'height': 9999, 'mode': 'inset'},
      'title': <String, Object?>{'scale': double.nan, 'align': 'center'},
      'meta': <String, Object?>{'dateFormat': 'bogus', 'showTags': false},
      'body': 'nope',
    });
    expect(style.page.horizontalPadding, 16);
    expect(style.page.paper, DiaryPreviewPaper.sepia);
    expect(style.page.seedColor, isNull);
    // 越界夹到边界。
    expect(style.cover.height, DiaryPreviewStyleLimits.coverHeight.max);
    expect(style.cover.mode, DiaryPreviewCoverMode.inset);
    expect(style.title.scale, 1);
    expect(style.title.align, DiaryPreviewAlign.center);
    expect(style.meta.dateFormat, DiaryCardDateFormat.relative);
    expect(style.meta.showTags, isFalse);
    expect(style.body, const DiaryPreviewBodyStyle());
  });

  test('custom colors accept hex strings and are stored opaque', () {
    final style = DiaryPreviewStyle.fromJson(<String, Object?>{
      'page': <String, Object?>{
        'paperLight': '#80F4ECD8',
        'textLight': 0x12345678,
      },
    });
    expect(style.page.paperLight, 0xFFF4ECD8);
    expect(style.page.textLight, 0xFF345678);
    expect(style.toJson()['page'], <String, Object>{
      'paperLight': '#F4ECD8',
      'textLight': '#345678',
    });
  });

  test('presets are distinct and classic is the default look', () {
    expect(
      DiaryPreviewPresets.styleOf(DiaryPreviewPresetId.classic),
      DiaryPreviewStyle.defaults,
    );
    final styles = DiaryPreviewPresets.styles.values.toSet();
    expect(styles, hasLength(DiaryPreviewPresetId.values.length));
    for (final id in DiaryPreviewPresetId.values) {
      expect(DiaryPreviewPresets.match(DiaryPreviewPresets.styleOf(id)), id);
    }
    expect(DiaryPreviewPresets.match(_everything), isNull);
  });

  test('preview style codes round trip and reject card codes', () {
    final code = DiaryPreviewStyleCode.encode(_everything, name: '全部');
    final decoded = DiaryPreviewStyleCode.decode('看这个 $code');
    expect(decoded.status, StyleCodeStatus.ok);
    expect(decoded.style, _everything);
    expect(decoded.name, '全部');

    final cardCode = DiaryCardStyleCode.encode(DiaryCardStyle.defaults);
    expect(
      DiaryPreviewStyleCode.decode(cardCode).status,
      StyleCodeStatus.invalid,
    );
  });
}
