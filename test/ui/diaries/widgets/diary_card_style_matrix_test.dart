import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style.dart';
import 'package:node_diary/ui/diaries/models/diary_card_style/diary_card_style_presets.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_card_view_data.dart';

import '../../../support/expressive_test_theme.dart';

/// 把每个数值拉到上限、打开所有附加信息的样式：最容易在窄屏溢出的组合。
const _extreme = DiaryCardStyle(
  surface: DiaryCardSurfaceStyle(
    cornerRadius: 40,
    borderWidth: 4,
    accentBar: DiaryCardAccentBar.start,
    accentWidth: 12,
    shadow: DiaryCardShadowStyle.custom,
    shadowElevation: 24,
  ),
  typography: DiaryCardTypography(
    titleScale: 1.4,
    previewScale: 1.3,
    metaScale: 1.3,
    lineHeight: DiaryCardLineHeight.relaxed,
  ),
  content: DiaryCardContentStyle(
    coverFallback: DiaryCardCoverFallback.dateBlock,
    collage: true,
  ),
  meta: DiaryCardMetaStyle(
    dateFormat: DiaryCardDateFormat.full,
    showTime: true,
    footerTime: DiaryCardFooterTime.absoluteUpdated,
    showLocation: true,
    showEnergy: true,
    showWordCount: true,
    showMedia: true,
  ),
  list: DiaryCardModeStyle(
    coverPosition: DiaryCardCoverPosition.start,
    coverSide: 168,
    coverHeight: 280,
    coverGap: 24,
    paddingH: 32,
    paddingV: 28,
    cardGap: 24,
    sideMargin: 32,
    elementGap: 16,
    titleMaxLines: 4,
    previewMaxLines: 8,
    metaPosition: DiaryCardMetaPosition.eyebrow,
  ),
  waterfall: DiaryCardModeStyle(
    coverPosition: DiaryCardCoverPosition.top,
    coverHeight: 280,
    coverGap: 24,
    paddingH: 32,
    paddingV: 28,
    cardGap: 24,
    sideMargin: 32,
    elementGap: 16,
    titleMaxLines: 4,
    previewMaxLines: 8,
    metaPosition: DiaryCardMetaPosition.eyebrow,
    columns: 3,
  ),
);

List<DiaryWithTags> _diaries() {
  final now = DateTime.now();
  const tags = <Tag>[
    Tag(id: 1, name: '一个很长很长的标签名字', color: 0xFF4CAF50),
    Tag(id: 2, name: '日常', color: 0xFF2196F3),
    Tag(id: 3, name: '读书', color: 0xFFE91E63),
  ];
  Diary diary(
    String id, {
    required String title,
    String? cover,
    bool pinned = false,
    bool locked = false,
    String embeds = '',
  }) => Diary(
    id: id.hashCode,
    diaryId: 'matrix_$id',
    title: title,
    content: '[$embeds{"insert":"很长的一段正文，用来确认摘要在任何行数下都能截断而不是溢出。\\n"}]',
    contentText: '很长的一段正文，用来确认摘要在任何行数下都能截断而不是溢出。' * 3,
    metadata:
        '{"context":{"moodEmoji":"😊","weatherIconCode":"100",'
        '"location":"一个非常非常长的地点名称用来测试截断","energyLevel":4}}',
    cover: cover,
    createdAt: DateTime(2025, 12, 28, 9, 30),
    updatedAt: DateTime(2025, 12, 28, 23, 59),
    isArchived: false,
    isPinned: pinned,
    isDeleted: false,
    capsuleLockedAt: locked ? now : null,
    capsuleUnlockAt: locked ? now.add(const Duration(days: 300)) : null,
  );
  return <DiaryWithTags>[
    DiaryWithTags(
      diary: diary(
        'pinned',
        title: '置顶并带封面的日记，标题足够长以至于需要折行显示',
        cover: '/cover.png',
        pinned: true,
      ),
      tags: tags,
    ),
    DiaryWithTags(
      diary: diary(
        'collage',
        title: '多图',
        embeds:
            '{"insert":{"image":"/a.png"}},{"insert":{"image":"/b.png"}},'
            '{"insert":{"image":"/c.png"}},{"insert":{"audio":"{}"}},',
      ),
      tags: tags.sublist(1),
    ),
    DiaryWithTags(
      diary: diary('plain', title: '没有封面的日记，标题也很长很长很长很长很长'),
      tags: tags,
    ),
    DiaryWithTags(
      diary: diary('locked', title: '时间胶囊', locked: true, pinned: true),
      tags: tags,
    ),
  ];
}

void main() {
  setUp(DiaryCardViewData.debugClearCache);

  final styles = <String, DiaryCardStyle>{
    for (final id in DiaryCardPresetId.values)
      id.name: DiaryCardPresets.styleOf(id),
    'extreme': _extreme,
  };
  const sizes = <(Size, double)>[(Size(360, 800), 1.0), (Size(320, 640), 1.3)];

  for (final entry in styles.entries) {
    for (final layout in DiaryLayoutMode.values) {
      for (final brightness in Brightness.values) {
        for (final (size, textScale) in sizes) {
          testWidgets('${entry.key} ${layout.name} ${brightness.name} '
              '${size.width.toInt()}dp@$textScale does not overflow', (
            tester,
          ) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = textScale;
            addTearDown(tester.view.reset);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            await tester.pumpWidget(
              MaterialApp(
                theme: expressiveTestTheme(brightness),
                locale: const Locale('zh'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: CustomScrollView(
                    slivers: <Widget>[
                      DiariesListSection(
                        diaries: _diaries(),
                        layoutMode: layout,
                        selectedDiaryIds: const <String>{'matrix_pinned'},
                        isSelectionMode: true,
                        maxVisibleTags: 3,
                        onCreate: () {},
                        onOpenEditor: (_, _) {},
                        onToggleSelection: (_, _) {},
                        cardStyle: entry.value,
                      ),
                    ],
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}
