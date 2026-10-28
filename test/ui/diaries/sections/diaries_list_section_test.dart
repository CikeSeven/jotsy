import 'package:flutter/material.dart';
import '../../../support/expressive_test_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/sections/diaries_list_section.dart';
import 'package:node_diary/ui/diaries/sections/diary_head_section.dart';
import 'package:node_diary/ui/widgets/long_image/long_image_policy.dart';
import 'package:node_diary/ui/diaries/widgets/diary_swipe_action_item.dart';

const _threeTags = <Tag>[
  Tag(id: 1, name: 'Tag 1', color: 0xFF336699),
  Tag(id: 2, name: 'Tag 2', color: 0xFF669933),
  Tag(id: 3, name: 'Tag 3', color: 0xFF993366),
];

void main() {
  testWidgets('list layout applies the configured visible tag limit', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        diary: _createUnlockedDiaryWithTags(),
        layoutMode: DiaryLayoutMode.list,
        maxVisibleTags: 1,
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_tagLabel('Tag 1'), findsOneWidget);
    expect(_tagLabel('Tag 2'), findsNothing);
    expect(_tagLabel('Tag 3'), findsNothing);
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('waterfall layout applies a positive visible tag limit', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        diary: _createUnlockedDiaryWithTags(),
        layoutMode: DiaryLayoutMode.waterfall,
        maxVisibleTags: 1,
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Visible diary'), findsOneWidget);
    expect(_tagLabel('Tag 1'), findsOneWidget);
    expect(_tagLabel('Tag 2'), findsNothing);
    expect(_tagLabel('Tag 3'), findsNothing);
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('list cover crops without distorting the source image', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        diary: _createUnlockedDiaryWithTags(cover: '/missing-cover.png'),
        layoutMode: DiaryLayoutMode.list,
        maxVisibleTags: 2,
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final resizedImage = image.image as ResizeImage;
    expect(image.fit, BoxFit.cover);
    expect(resizedImage.width, isNotNull);
    // 只按宽度定解码尺寸，高度只给安全上限，fit 策略保持原图比例。
    expect(resizedImage.policy, ResizeImagePolicy.fit);
    expect(resizedImage.height, kSafeImageDecodeExtent);
  });

  testWidgets('waterfall cover decodes at the column width', (tester) async {
    await tester.pumpWidget(
      _buildTestApp(
        diary: _createUnlockedDiaryWithTags(cover: '/missing-cover.png'),
        layoutMode: DiaryLayoutMode.waterfall,
        maxVisibleTags: 2,
      ),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final resizedImage = image.image as ResizeImage;
    final dpr = tester.view.devicePixelRatio;
    final imageWidth = tester.getSize(find.byType(Image)).width;
    expect(image.fit, BoxFit.cover);
    // 只限高时竖图只解码出约 140dp 宽、被拉伸到整列宽而发糊；按列宽解码，
    // 高度交给 BoxFit.cover 裁切（不同时限定宽高，避免按容器比例拉伸）。
    expect(resizedImage.width, (imageWidth * dpr).round());
    // 只按宽度定解码尺寸，高度只给安全上限，fit 策略保持原图比例。
    expect(resizedImage.policy, ResizeImagePolicy.fit);
    expect(resizedImage.height, kSafeImageDecodeExtent);
  });

  testWidgets('waterfall layout hides tags when the configured limit is zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        diary: _createUnlockedDiaryWithTags(),
        layoutMode: DiaryLayoutMode.waterfall,
        maxVisibleTags: 0,
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(_tagLabel('Tag 1'), findsNothing);
    expect(_tagLabel('Tag 2'), findsNothing);
    expect(_tagLabel('Tag 3'), findsNothing);
    expect(find.text('+3'), findsNothing);
  });

  testWidgets('selected list card animates its highlight and press response', (
    tester,
  ) async {
    final diary = _createUnlockedDiaryWithTags();
    const surfaceKey = ValueKey<String>('diary_selection_surface_unlocked-1');
    const motionKey = ValueKey<String>('diary_selection_motion_unlocked-1');

    await tester.pumpWidget(
      _buildTestApp(
        diary: diary,
        layoutMode: DiaryLayoutMode.list,
        maxVisibleTags: 2,
        enableSwipeAction: true,
      ),
    );
    await tester.pumpAndSettle();

    final unselectedSurface = tester.widget<Container>(find.byKey(surfaceKey));
    final unselectedDecoration = unselectedSurface.decoration! as BoxDecoration;
    final unselectedColor = unselectedDecoration.color;
    expect(
      tester
          .widget<DiarySwipeActionItem>(find.byType(DiarySwipeActionItem))
          .enabled,
      isTrue,
    );

    await tester.pumpWidget(
      _buildTestApp(
        diary: diary,
        layoutMode: DiaryLayoutMode.list,
        maxVisibleTags: 2,
        selectedDiaryIds: const <String>{'unlocked-1'},
        enableSwipeAction: true,
      ),
    );
    await tester.pump(const Duration(milliseconds: 90));

    final transitioningSurface = tester.widget<Container>(
      find.byKey(surfaceKey),
    );
    final transitioningDecoration =
        transitioningSurface.decoration! as BoxDecoration;
    final transitioningMotion = tester.widget<Transform>(find.byKey(motionKey));
    expect(transitioningDecoration.color, isNot(unselectedColor));
    expect(transitioningMotion.transform.storage[0], lessThan(1));
    expect(
      tester
          .widget<DiarySwipeActionItem>(find.byType(DiarySwipeActionItem))
          .enabled,
      isFalse,
    );

    await tester.pumpAndSettle();

    final selectedSurface = tester.widget<Container>(find.byKey(surfaceKey));
    final selectedDecoration = selectedSurface.decoration! as BoxDecoration;
    final selectedForeground =
        selectedSurface.foregroundDecoration! as BoxDecoration;
    final selectedBorder = selectedForeground.border! as Border;
    expect(selectedDecoration.color, isNot(unselectedColor));
    expect(selectedBorder.left.width, 2);
    expect(selectedBorder.left.color, isNot(Colors.transparent));
  });

  testWidgets(
    'selected waterfall card uses themed outline and shadow in dark mode',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          diary: _createUnlockedDiaryWithTags(),
          layoutMode: DiaryLayoutMode.waterfall,
          maxVisibleTags: 2,
          selectedDiaryIds: const <String>{'unlocked-1'},
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpAndSettle();

      final surface = tester.widget<Container>(
        find.byKey(
          const ValueKey<String>('diary_selection_surface_unlocked-1'),
        ),
      );
      final decoration = surface.decoration! as BoxDecoration;
      final foreground = surface.foregroundDecoration! as BoxDecoration;
      final border = foreground.border! as Border;
      final context = tester.element(find.byKey(const ValueKey('test-root')));
      final colorScheme = Theme.of(context).colorScheme;

      expect(decoration.color, isNot(colorScheme.surfaceContainerLow));
      expect(decoration.boxShadow, isNotEmpty);
      expect(border.top.width, 2);
      expect(border.top.color, colorScheme.primary.withValues(alpha: 0.82));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selected locked capsule receives the shared card highlight', (
    tester,
  ) async {
    final now = DateTime.now();
    final diary = _createLockedDiaryWithTags(now);

    await tester.pumpWidget(
      _buildTestApp(
        diary: diary,
        layoutMode: DiaryLayoutMode.list,
        maxVisibleTags: 3,
        selectedDiaryIds: const <String>{'capsule-1'},
      ),
    );
    await tester.pumpAndSettle();

    final surface = tester.widget<Container>(
      find.byKey(const ValueKey<String>('diary_selection_surface_capsule-1')),
    );
    final foreground = surface.foregroundDecoration! as BoxDecoration;
    final border = foreground.border! as Border;
    expect(border.left.width, 2);
    expect(border.left.color, isNot(Colors.transparent));
  });

  testWidgets(
    'locked capsule card does not overflow in narrow waterfall cell',
    (tester) async {
      final now = DateTime.now();
      final diary = _createLockedDiaryWithTags(now);

      await tester.pumpWidget(
        _buildTestApp(
          diary: diary,
          layoutMode: DiaryLayoutMode.waterfall,
          maxVisibleTags: 3,
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('365 天后解封'), findsOneWidget);
      expect(_tagLabel('Tag 1'), findsNothing);
    },
  );

  for (final layoutMode in DiaryLayoutMode.values) {
    testWidgets(
      'locked capsule ${layoutMode.name} card hides its content without backdrop blur',
      (tester) async {
        final semantics = tester.ensureSemantics();
        final diary = _createLockedDiaryWithTags(DateTime.now());

        await tester.pumpWidget(
          _buildTestApp(
            diary: diary,
            layoutMode: layoutMode,
            maxVisibleTags: 3,
          ),
        );
        await tester.pumpAndSettle();

        // 未解封正文既不能被绘制，也不能出现在语义树里供读屏读出。
        expect(find.textContaining('hidden content'), findsNothing);
        expect(find.bySemanticsLabel(RegExp('hidden content')), findsNothing);
        // 每张卡一个 BackdropFilter 会回读背景模糊，滚动时光栅线程压力大。
        expect(find.byType(BackdropFilter), findsNothing);
        expect(find.text('365 天后解封'), findsOneWidget);
        semantics.dispose();
      },
    );
  }

  testWidgets('undo reveal keeps the same card element after settling', (
    tester,
  ) async {
    final diary = _createUnlockedDiaryWithTags();
    const surfaceKey = ValueKey<String>('diary_selection_surface_unlocked-1');
    await tester.pumpWidget(
      _buildTestApp(
        diary: diary,
        layoutMode: DiaryLayoutMode.list,
        maxVisibleTags: 2,
        appearingDiaryIds: const <String>{'unlocked-1'},
      ),
    );
    final appearingElement = tester.element(
      find.byKey(surfaceKey, skipOffstage: false),
    );
    await tester.pumpAndSettle();

    // 协调器在出现动画结束后清除标记；此前包装层随之变化会重新挂载卡片。
    await tester.pumpWidget(
      _buildTestApp(
        diary: diary,
        layoutMode: DiaryLayoutMode.list,
        maxVisibleTags: 2,
      ),
    );
    expect(
      tester.element(find.byKey(surfaceKey, skipOffstage: false)),
      same(appearingElement),
    );

    await tester.pumpWidget(
      _buildTestApp(
        diary: diary,
        layoutMode: DiaryLayoutMode.list,
        maxVisibleTags: 2,
        pendingHideDiaryIds: const <String>{'unlocked-1'},
      ),
    );
    await tester.pump(const Duration(milliseconds: 60));
    expect(
      tester.element(find.byKey(surfaceKey, skipOffstage: false)),
      same(appearingElement),
    );
    await tester.pumpAndSettle();
  });
}

DiaryWithTags _createUnlockedDiaryWithTags({String? cover}) {
  final now = DateTime.now();
  return DiaryWithTags(
    diary: Diary(
      id: 1,
      diaryId: 'unlocked-1',
      title: 'Visible diary',
      content: '[{"insert":"visible content\\n"}]',
      contentText: 'visible content',
      metadata: '{}',
      cover: cover,
      createdAt: now,
      updatedAt: now,
      isArchived: false,
      isPinned: false,
      isDeleted: false,
    ),
    tags: _threeTags,
  );
}

DiaryWithTags _createLockedDiaryWithTags(DateTime now) {
  return DiaryWithTags(
    diary: Diary(
      id: 1,
      diaryId: 'capsule-1',
      title: 'Future letter',
      content: '[{"insert":"hidden content\\n"}]',
      contentText: 'hidden content for future self',
      metadata: '{}',
      createdAt: now,
      updatedAt: now,
      isArchived: false,
      isPinned: false,
      capsuleLockedAt: now,
      capsuleUnlockAt: now.add(const Duration(days: 365)),
      isDeleted: false,
    ),
    tags: _threeTags,
  );
}

Widget _buildTestApp({
  required DiaryWithTags diary,
  required DiaryLayoutMode layoutMode,
  required int maxVisibleTags,
  Set<String> selectedDiaryIds = const <String>{},
  Set<String> appearingDiaryIds = const <String>{},
  Set<String> pendingHideDiaryIds = const <String>{},
  Brightness brightness = Brightness.light,
  bool enableSwipeAction = false,
}) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: expressiveTestTheme(brightness),
    home: Scaffold(
      body: SizedBox(
        key: const ValueKey<String>('test-root'),
        width: 360,
        child: CustomScrollView(
          slivers: <Widget>[
            DiariesListSection(
              diaries: <DiaryWithTags>[diary],
              layoutMode: layoutMode,
              selectedDiaryIds: selectedDiaryIds,
              isSelectionMode: selectedDiaryIds.isNotEmpty,
              maxVisibleTags: maxVisibleTags,
              onCreate: () {},
              onOpenEditor: (_, _) {},
              onToggleSelection: (_, _) {},
              onArchiveDiary: enableSwipeAction ? (_) {} : null,
              appearingDiaryIds: appearingDiaryIds,
              pendingHideDiaryIds: pendingHideDiaryIds,
            ),
          ],
        ),
      ),
    ),
  );
}

Finder _tagLabel(String label) {
  return find.textContaining(label, findRichText: true);
}
