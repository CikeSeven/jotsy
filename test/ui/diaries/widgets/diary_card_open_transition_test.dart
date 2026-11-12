import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/widgets/container_transform/container_transform_source.dart';

import '../../../support/expressive_test_theme.dart';

var _idSeed = 0;

DiaryWithTags _diary() {
  final id = 'open_transition_${_idSeed++}';
  return DiaryWithTags(
    diary: Diary(
      id: _idSeed,
      diaryId: id,
      title: '卡片标题',
      content: '[{"insert":"正文\\n"}]',
      contentText: '正文',
      metadata: '{}',
      createdAt: DateTime(2026, 3, 2, 9, 30),
      updatedAt: DateTime(2026, 3, 2, 9, 30),
      isArchived: false,
      isPinned: false,
      isDeleted: false,
    ),
    tags: const <Tag>[],
  );
}

/// 点按列表卡片：带出“从这张卡片展开”的起点；不作为转场来源时（设置页预览、
/// 宽窗口双栏）不带。
void main() {
  Future<List<ContainerTransformOrigin?>> pump(
    WidgetTester tester,
    DiaryWithTags diary, {
    bool enableCoverHero = true,
  }) async {
    final origins = <ContainerTransformOrigin?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: expressiveTestTheme(Brightness.light),
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              DiariesListSection(
                diaries: <DiaryWithTags>[diary],
                layoutMode: DiaryLayoutMode.list,
                selectedDiaryIds: const <String>{},
                isSelectionMode: false,
                maxVisibleTags: 3,
                enableCoverHero: enableCoverHero,
                onOpenEditor: (_, _, origin) => origins.add(origin),
                onToggleSelection: (_, _) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return origins;
  }

  testWidgets('tapping a card hands over where it sits on screen', (
    tester,
  ) async {
    final diary = _diary();
    final origins = await pump(tester, diary);

    await tester.tap(find.text('卡片标题'));
    await tester.pump();

    final origin = origins.single!;
    expect(origin.tag, diaryCardTransitionTag(diary.diary.diaryId));
    final shot = origin.takeShot()!;
    expect(shot.rect, tester.getRect(find.byType(ContainerTransformSource)));
    expect(shot.image.width, greaterThan(0));
    shot.dispose();
  });

  testWidgets('cards that are not a transition source hand over nothing', (
    tester,
  ) async {
    final origins = await pump(tester, _diary(), enableCoverHero: false);

    await tester.tap(find.text('卡片标题'));
    await tester.pump();

    expect(find.byType(ContainerTransformSource), findsNothing);
    expect(origins, <ContainerTransformOrigin?>[null]);
  });
}
