import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/models/diary_meta_draft.dart';
import 'package:node_diary/ui/diaries/viewmodels/diary_meta_draft_controller.dart';
import 'package:node_diary/ui/diaries/widgets/publish_location_precision_picker.dart';
import 'package:node_diary/ui/diaries/widgets/publish_panel/publish_place_history_page.dart';
import 'package:node_diary/ui/diaries/widgets/publish_panel/publish_place_history_strip.dart';
import 'package:node_diary/ui/diaries/widgets/publish_panel/publish_place_row.dart';

import '../../../support/publish_panel_driver.dart';

final _now = DateTime.now();

DiaryPlaceUsage _place(String label, {bool located = false, int uses = 1}) {
  return DiaryPlaceUsage(
    label: label,
    uses: uses,
    lastUsedAt: _now.subtract(const Duration(days: 2)),
    precision: located ? 'district' : null,
    latitude: located ? 39.98 : null,
    longitude: located ? 116.48 : null,
    addressComponent: located
        ? const <String, Object?>{'city': '北京市', 'district': '朝阳区'}
        : null,
  );
}

final _places = <DiaryPlaceUsage>[
  _place('北京市 · 朝阳区', located: true, uses: 12),
  _place('杭州 · 西湖区'),
  _place('外婆家'),
];

Future<PublishPanelDriver> _mount(
  WidgetTester tester, {
  List<DiaryPlaceUsage>? places,
  DiaryMetaDraftController? draft,
  Size size = const Size(400, 900),
  String locale = 'en',
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    publishPanelHost(
      places: places ?? _places,
      draft: draft,
      locale: locale,
      textScale: textScale,
    ),
  );
  final panel = PublishPanelDriver(tester);
  await panel.expand();
  return panel;
}

Finder _placesButton(PublishPanelDriver panel) =>
    find.byTooltip(panel.l10n.placeHistoryTitle);

Future<void> _openPlaces(WidgetTester tester, PublishPanelDriver panel) async {
  await tester.ensureVisible(_placesButton(panel));
  await tester.pumpAndSettle();
  await tester.tap(_placesButton(panel));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('recent places under an empty field fill it with one tap', (
    tester,
  ) async {
    final panel = await _mount(tester);
    expect(find.byType(PublishPlaceHistoryStrip), findsOneWidget);
    expect(find.byType(PublishLocationPrecisionPicker), findsNothing);
    // 条带只写最具体的一级。
    expect(find.text('朝阳区'), findsOneWidget);
    expect(find.text('西湖区'), findsOneWidget);

    await tester.ensureVisible(find.text('朝阳区'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('朝阳区'));
    await tester.pumpAndSettle();

    expect(panel.locationText, '北京市 · 朝阳区');
    expect(panel.draft.value.locationFromAuto, isTrue);
    // 有地点后这一格换成地址层级入口。
    expect(find.byType(PublishPlaceHistoryStrip), findsNothing);
    expect(find.byType(PublishLocationPrecisionPicker), findsOneWidget);

    // 清空地点，条带回来。
    panel.typeLocation('');
    await tester.pumpAndSettle();
    expect(find.byType(PublishPlaceHistoryStrip), findsOneWidget);
  });

  testWidgets('without recent places the strip takes no room', (tester) async {
    final panel = await _mount(tester, places: const <DiaryPlaceUsage>[]);
    expect(find.text('All 0'), findsNothing);
    expect(
      find.descendant(
        of: find.byType(PublishPlaceHistoryStrip),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );

    await _openPlaces(tester, panel);
    expect(find.text(panel.l10n.placeHistoryEmptyTitle), findsOneWidget);
    expect(find.text(panel.l10n.placeHistoryEmptyBody), findsOneWidget);
  });

  testWidgets('the page searches by pinyin and a pick returns to the panel', (
    tester,
  ) async {
    final draft = DiaryMetaDraftController(
      const DiaryMetaDraft(location: '外婆家'),
    );
    addTearDown(draft.dispose);
    final panel = await _mount(tester, draft: draft);
    await _openPlaces(tester, panel);

    expect(find.byType(PublishPlaceHistoryPage), findsOneWidget);
    expect(find.byType(PublishPlaceRow), findsNWidgets(3));
    PublishPlaceRow row(String name) => tester.widget<PublishPlaceRow>(
      find.ancestor(of: find.text(name), matching: find.byType(PublishPlaceRow)),
    );
    // 当前地点标为选中；带坐标的行第二行是上级，右侧是篇数。
    expect(row('外婆家').selected, isTrue);
    expect(row('朝阳区').selected, isFalse);
    expect(find.text('北京市'), findsOneWidget);
    expect(find.text('12 entries'), findsOneWidget);

    final search = find.descendant(
      of: find.byType(PublishPlaceHistoryPage),
      matching: find.byType(TextField),
    );
    await tester.enterText(search, 'xihu');
    await tester.pumpAndSettle();
    expect(find.byType(PublishPlaceRow), findsOneWidget);

    await tester.enterText(search, 'tokyo');
    await tester.pumpAndSettle();
    expect(find.byType(PublishPlaceRow), findsNothing);
    expect(find.text('No places match “tokyo”'), findsOneWidget);

    await tester.enterText(search, 'xihu');
    await tester.pumpAndSettle();
    await tester.tap(find.text('西湖区'));
    await tester.pumpAndSettle();

    expect(panel.locationText, '杭州 · 西湖区');
    // 手填的地点不带坐标，不保存 geo。
    expect(panel.draft.value.locationFromAuto, isFalse);
    expect(find.byType(PublishPlaceHistoryPage), findsNothing);
    expect(find.byType(PublishLocationPrecisionPicker), findsOneWidget);
  });

  testWidgets('a long history ends the strip with an All chip', (
    tester,
  ) async {
    final many = <DiaryPlaceUsage>[
      for (var i = 0; i < 10; i++) _place('Place $i'),
    ];
    final panel = await _mount(tester, places: many);
    // 条带横向懒构建：滑到末尾才建出“全部”。
    final strip = find.descendant(
      of: find.byType(PublishPlaceHistoryStrip),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.text('All 10'),
      200,
      scrollable: strip,
    );
    await tester.pumpAndSettle();
    expect(find.text('Place 7'), findsOneWidget);
    expect(find.text('Place 8'), findsNothing);

    await tester.tap(find.text('All 10'));
    await tester.pumpAndSettle();
    expect(find.byType(PublishPlaceHistoryPage), findsOneWidget);
    expect(panel.locationText, isEmpty);
  });

  testWidgets('places cannot be picked while locating', (tester) async {
    final panel = await _mount(tester);
    await tester.ensureVisible(find.text('外婆家'));
    await tester.pumpAndSettle();
    // 定位中按钮的加载指示一直在动，不能 pumpAndSettle。
    panel.actions.locating.value = true;
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('外婆家'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(panel.draft.value.location, isNull);

    await tester.tap(_placesButton(panel));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      tester.widgetList<PublishPlaceRow>(find.byType(PublishPlaceRow)).map(
        (row) => row.onTap,
      ),
      everyElement(isNull),
    );
    panel.actions.locating.value = false;
    await tester.pumpAndSettle();
  });

  testWidgets('long places fit a 320dp phone with large text', (tester) async {
    final long = <DiaryPlaceUsage>[
      _place('内蒙古自治区呼和浩特市 · 赛罕区 · 敕勒川大街东延线辅路', uses: 1234),
      _place('一个非常非常非常非常非常非常长的手填地点名称'),
      for (var i = 0; i < 6; i++) _place('城市$i · 区$i'),
    ];
    final panel = await _mount(
      tester,
      places: long,
      size: const Size(320, 800),
      locale: 'zh',
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);

    await _openPlaces(tester, panel);
    expect(tester.takeException(), isNull);
    expect(find.byType(PublishPlaceRow), findsWidgets);
  });
}
