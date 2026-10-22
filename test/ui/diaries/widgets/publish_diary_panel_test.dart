import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/models/time_capsule.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/diaries/widgets/publish_diary_panel.dart';
import 'package:node_diary/ui/diaries/widgets/publish_panel/publish_cover_tile.dart';
import 'package:node_diary/ui/diaries/widgets/publish_panel/publish_panel_tile.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';

import '../../../support/publish_panel_driver.dart';

/// 表头双箭头的纵向缩放：1 = 上指，-1 = 下指。
double _arrowFlip(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .ancestor(
            of: find.byIcon(FontAwesomeIcons.anglesUp.data),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .storage[5];

void main() {
  testWidgets('time capsule picker stays inside publish panel', (tester) async {
    await tester.pumpWidget(publishPanelHost(capsuleEnabled: true));

    await tester.tap(PublishPanelDriver(tester).collapsedHeader);
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Time lock'));

    await tester.pumpAndSettle();

    await tester.tap(find.text('Time lock'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Choose unlock time'), findsOneWidget);
  });

  group('time capsule picker', () {
    Future<void> openCapsulePage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(publishPanelHost(capsuleEnabled: true));
      await PublishPanelDriver(tester).expand();
      await tester.ensureVisible(find.text('Time lock'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Time lock'));
      await tester.pumpAndSettle();
    }

    CupertinoDatePicker picker(WidgetTester tester) =>
        tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));

    testWidgets('a quick preset moves the wheel and is what gets confirmed', (
      tester,
    ) async {
      await openCapsulePage(tester);
      final before = picker(tester);

      await tester.tap(find.text('One month'));
      await tester.pumpAndSettle();
      // 选择器只在创建时读初始值：预设必须让它以新值重建，滚轮才会跟着动。
      final after = picker(tester);
      final expectedDay = DateUtils.dateOnly(
        DateTime.now().add(const Duration(days: 30)),
      );
      expect(after.key, isNot(before.key));
      expect(DateUtils.dateOnly(after.initialDateTime), expectedDay);

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      final confirmed = PublishPanelDriver(tester).draft.value.capsule;
      expect(confirmed?.precision, TimeCapsulePrecision.date);
      expect(confirmed?.normalizedUnlockAt, expectedDay);
    });

    testWidgets('date only shows a date wheel that starts tomorrow', (
      tester,
    ) async {
      await openCapsulePage(tester);
      final tomorrow = DateUtils.dateOnly(
        DateTime.now(),
      ).add(const Duration(days: 1));
      expect(picker(tester).mode, CupertinoDatePickerMode.date);
      expect(picker(tester).minimumDate, tomorrow);

      await tester.tap(find.text('Exact time'));
      await tester.pumpAndSettle();
      expect(picker(tester).mode, CupertinoDatePickerMode.dateAndTime);

      await tester.tap(find.text('Date only'));
      await tester.pumpAndSettle();
      expect(picker(tester).mode, CupertinoDatePickerMode.date);
      expect(tester.takeException(), isNull);
    });
  });

  group('collapsed summary bar', () {
    testWidgets('shows what the diary carries and expands from the summary', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final draft = DiaryMetaDraftController(
        const DiaryMetaDraft(tagIds: {1, 2}, location: '北京市 · 望京街道'),
      );
      addTearDown(draft.dispose);
      await tester.pumpWidget(
        publishPanelHost(
          draft: draft,
          tags: const [
            Tag(id: 1, name: 'Life', color: 0xff2196f3),
            Tag(id: 2, name: 'Travel', color: 0xffe91e63),
          ],
        ),
      );
      await tester.pumpAndSettle();
      final panel = PublishPanelDriver(tester);

      // 第一个 RichText 是摘要本身（图标也是 RichText，排在它里面）。
      final summary = tester.widget<RichText>(
        find
            .descendant(
              of: panel.collapsedHeader,
              matching: find.byType(RichText),
            )
            .first,
      );
      final text = summary.text.toPlainText();
      expect(text, contains('Life'));
      expect(text, contains('+1'));
      expect(text, contains('望京街道'));

      // 发布页进入即发表，收起栏与编辑页一样只有摘要，没有发表按钮。
      expect(find.byType(FilledButton), findsNothing);
      // 摘要区点按展开面板。
      await panel.expand();
      expect(panel.expandedHeader, findsOneWidget);
    });

    testWidgets('an empty draft shows the hint', (tester) async {
      await tester.pumpWidget(publishPanelHost());
      await tester.pumpAndSettle();
      expect(find.text('Add tags, mood, place…'), findsOneWidget);
    });

    testWidgets('the expanded panel has no publish button', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(publishPanelHost());
      await PublishPanelDriver(tester).expand();

      expect(find.text('Publish diary'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final brightness in Brightness.values) {
      for (final locale in ['en', 'zh']) {
        testWidgets('fits 320dp at 1.3x text in $locale, ${brightness.name}', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final draft = DiaryMetaDraftController(
            DiaryMetaDraft(
              tagIds: const {1},
              location: 'A very long hand written place name',
              weather: 'Sunny 24℃',
              moodEmoji: '🙂',
              capsule: TimeCapsuleSchedule(
                unlockAt: DateTime(2030),
                precision: TimeCapsulePrecision.date,
              ),
            ),
          );
          addTearDown(draft.dispose);
          await tester.pumpWidget(
            publishPanelHost(
              draft: draft,
              capsuleEnabled: true,
              keyboardLayout: true,
              brightness: brightness,
              locale: locale,
              textScale: 1.3,
              tags: const [
                Tag(id: 1, name: 'A long tag name', color: 0xff2196f3),
              ],
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(PublishPanelDriver(tester).collapsedHeader, findsOneWidget);

          await PublishPanelDriver(tester).expand();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('cover row', () {
    Future<DiaryMetaDraftController> pumpWithCover(
      WidgetTester tester,
      String? cover,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final draft = DiaryMetaDraftController(DiaryMetaDraft(cover: cover));
      addTearDown(draft.dispose);
      await tester.pumpWidget(publishPanelHost(draft: draft));
      await PublishPanelDriver(tester).expand();
      return draft;
    }

    Finder thumbnail() => find.descendant(
      of: find.byType(PublishCoverTile),
      matching: find.byType(Image),
    );

    testWidgets('a cover shows a downsized thumbnail instead of a file name', (
      tester,
    ) async {
      final draft = await pumpWithCover(tester, '/covers/cover_1700000.jpg');
      expect(find.textContaining('cover_1700000'), findsNothing);
      expect(find.text('Tap to change'), findsOneWidget);
      final image = tester.widget<Image>(thumbnail());
      expect(image.image, isA<ResizeImage>());
      expect(image.frameBuilder, isNotNull);

      await tester.tap(find.byTooltip('Clear cover'));
      await tester.pumpAndSettle();
      expect(draft.value.cover, isNull);
      expect(thumbnail(), findsNothing);
      expect(find.text('Tap to choose a cover (optional)'), findsOneWidget);
    });

    testWidgets('importing a cover shows progress and blocks another pick', (
      tester,
    ) async {
      await pumpWithCover(tester, null);
      final actions = PublishPanelDriver(tester).actions;
      actions.importingCover.value = true;
      await tester.pump();
      // 300ms 内完成的导入不闪加载指示。
      expect(
        find.descendant(
          of: find.byType(PublishCoverTile),
          matching: find.byType(ExpressiveLoadingIndicator),
        ),
        findsNothing,
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.descendant(
          of: find.byType(PublishCoverTile),
          matching: find.byType(ExpressiveLoadingIndicator),
        ),
        findsOneWidget,
      );
      final tile = tester.widget<PublishPanelTile>(
        find.descendant(
          of: find.byType(PublishCoverTile),
          matching: find.byType(PublishPanelTile),
        ),
      );
      expect(tile.onTap, isNull);
      actions.importingCover.value = false;
      await tester.pumpAndSettle();
    });
  });

  group('publish time row', () {
    testWidgets('the whole row opens the picker', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var picks = 0;
      await tester.pumpWidget(
        publishPanelHost(
          publishTime: PublishTimeOption(label: null, onPick: () => picks++),
        ),
      );
      await PublishPanelDriver(tester).expand();

      expect(find.text('Auto use current time'), findsOneWidget);
      await tester.ensureVisible(find.text('Publish time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publish time'));
      await tester.tap(find.text('Auto use current time'));
      expect(picks, 2);
    });

    testWidgets('a time lock dates the diary and disables the row', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final draft = DiaryMetaDraftController(
        DiaryMetaDraft(
          capsule: TimeCapsuleSchedule(
            unlockAt: DateTime(2027),
            precision: TimeCapsulePrecision.date,
          ),
        ),
      );
      addTearDown(draft.dispose);
      var picks = 0;
      await tester.pumpWidget(
        publishPanelHost(
          draft: draft,
          capsuleEnabled: true,
          publishTime: PublishTimeOption(label: null, onPick: () => picks++),
        ),
      );
      await PublishPanelDriver(tester).expand();

      expect(find.text('Follows the time lock · Jan 1, 2027'), findsOneWidget);
      await tester.ensureVisible(find.text('Publish time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publish time'));
      expect(picks, 0);

      // 移除定时锁后恢复可选。
      draft.setCapsule(null);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Publish time'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publish time'));
      expect(picks, 1);
    });
  });

  testWidgets('energy switch toggles between enabled and disabled states', (
    tester,
  ) async {
    final draft = DiaryMetaDraftController(
      const DiaryMetaDraft(energyLevel: 4),
    );
    addTearDown(draft.dispose);

    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 1. Initial state with energy enabled (4.0)
    await tester.pumpWidget(publishPanelHost(draft: draft));
    await tester.tap(PublishPanelDriver(tester).collapsedHeader);
    await tester.pumpAndSettle();

    final energySwitchFinder = find.byType(Switch);
    expect(energySwitchFinder, findsOneWidget);
    await tester.ensureVisible(energySwitchFinder);
    await tester.pumpAndSettle();

    final switchWidgetOn = tester.widget<Switch>(energySwitchFinder);
    expect(switchWidgetOn.value, isTrue);
    expect(find.byType(Slider), findsOneWidget);
    // 五格电量：滑块按整档 1–5 移动。
    expect(tester.widget<Slider>(find.byType(Slider)).divisions, 4);
    final switchRightOn = tester.getTopRight(energySwitchFinder).dx;

    // Toggle switch off
    await tester.tap(energySwitchFinder);
    await tester.pumpAndSettle();
    expect(draft.value.energyLevel, isNull);

    // 2. Disabled state

    final switchWidgetOff = tester.widget<Switch>(energySwitchFinder);
    expect(switchWidgetOff.value, isFalse);
    expect(find.byType(Slider), findsNothing);
    expect(find.text('Not recorded'), findsOneWidget);
    final switchRightOff = tester.getTopRight(energySwitchFinder).dx;
    expect(switchRightOff, equals(switchRightOn));

    // Toggle switch back on
    await tester.ensureVisible(energySwitchFinder);
    await tester.tap(energySwitchFinder);
    await tester.pumpAndSettle();
    expect(draft.value.energyLevel, 4.0);
  });

  testWidgets('a legacy fractional energy value still shows', (tester) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final draft = DiaryMetaDraftController(
      const DiaryMetaDraft(energyLevel: 3.37),
    );
    addTearDown(draft.dispose);
    await tester.pumpWidget(publishPanelHost(draft: draft));
    await PublishPanelDriver(tester).expand();

    expect(tester.widget<Slider>(find.byType(Slider)).value, 3.37);
    expect(find.text('So-so'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // 区块各自监听草稿里自己的字段：拖动精力滑块的每一格不该重建心情网格
  // 和封面行。
  testWidgets('an energy change rebuilds only the energy section', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final draft = DiaryMetaDraftController(
      const DiaryMetaDraft(energyLevel: 4),
    );
    addTearDown(draft.dispose);
    await tester.pumpWidget(publishPanelHost(draft: draft));
    await PublishPanelDriver(tester).expand();
    final moodChipBefore = tester.widget(find.byType(ChoiceChip).first);
    final sliderBefore = tester.widget(find.byType(Slider));

    draft.setEnergy(2);
    await tester.pump();

    expect(
      identical(tester.widget(find.byType(ChoiceChip).first), moodChipBefore),
      isTrue,
    );
    expect(
      identical(tester.widget(find.byType(Slider)), sliderBefore),
      isFalse,
    );
    expect(tester.widget<Slider>(find.byType(Slider)).value, 2);
  });

  // 键盘弹出后 body 只剩 340dp：展开高度随可用高度收缩，主页、标签页、胶囊
  // 页的表头都留在可视区域里，而不是被固定的 470/540 挤出顶边。
  testWidgets('the expanded panel shrinks to fit above the keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      publishPanelHost(keyboardLayout: true, capsuleEnabled: true),
    );
    final panel = PublishPanelDriver(tester);
    await panel.expand();
    const bodyHeight = 640.0 - 300.0;

    expect(tester.getRect(panel.expandedHeader).top, greaterThanOrEqualTo(0));
    expect(
      tester.getSize(find.byType(PublishDiaryPanel)).height,
      lessThanOrEqualTo(bodyHeight),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Tags'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Choose tags')).top,
      greaterThanOrEqualTo(0),
    );

    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Time lock'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Time lock'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Choose unlock time')).top,
      greaterThanOrEqualTo(0),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tall screen keeps the designed panel height', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(publishPanelHost(keyboardLayout: true));
    await PublishPanelDriver(tester).expand();
    // 设计高度 470 + 底部留白 10。
    expect(tester.getSize(find.byType(PublishDiaryPanel)).height, 480);
  });

  testWidgets(
    'collapsed panel sits just above the keyboard, not lifted twice',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.reset);

      // 与编辑页/发布页一致：Scaffold 默认随键盘缩小 body，面板贴 body 底边。
      await tester.pumpWidget(publishPanelHost(keyboardLayout: true));
      await tester.pumpAndSettle();

      const keyboardTop = 900.0 - 300.0;
      final handleLabel = tester.getRect(
        PublishPanelDriver(tester).collapsedHeader,
      );
      // 收起态面板高 56dp，底部留白 10 + 18；标签应紧贴键盘上方，
      // 而不是被再抬升一个键盘高度。
      expect(handleLabel.bottom, lessThan(keyboardTop));
      expect(keyboardTop - handleLabel.bottom, lessThan(80));
    },
  );
  testWidgets(
    'dragging the panel follows the finger without rebuilding content',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(publishPanelHost());
      expect(_arrowFlip(tester), 1);
      await tester.tap(PublishPanelDriver(tester).collapsedHeader);
      await tester.pumpAndSettle();
      expect(_arrowFlip(tester), -1);
      expect(PublishPanelDriver(tester).expandedHeader, findsOneWidget);

      final contentBefore = tester.widget<Text>(find.text('Cover'));
      final gesture = await tester.startGesture(
        tester.getCenter(PublishPanelDriver(tester).expandedHeader),
      );
      await gesture.moveBy(const Offset(0, 40));
      await gesture.moveBy(const Offset(0, 40));
      await tester.pump();

      // 拖到半途：箭头处在压扁/翻转的中间态，而不是在阈值处硬切朝向。
      final flip = _arrowFlip(tester);
      expect(flip, greaterThan(-1));
      expect(flip, lessThan(1));
      // 宽度内缩、淡入逐帧变化，但子页内容没有随进度重建。
      expect(
        identical(tester.widget<Text>(find.text('Cover')), contentBefore),
        isTrue,
      );

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('header arrow keeps a discrete direction under reduce motion', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(publishPanelHost());
    await tester.tap(PublishPanelDriver(tester).collapsedHeader);
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(PublishPanelDriver(tester).expandedHeader),
    );
    await gesture.moveBy(const Offset(0, 40));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(_arrowFlip(tester).abs(), 1);

    await gesture.up();
    await tester.pumpAndSettle();
  });
}
