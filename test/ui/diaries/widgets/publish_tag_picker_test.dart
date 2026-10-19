import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/ui/diaries/models/tag_picker_sort.dart';
import 'package:node_diary/ui/diaries/widgets/publish_panel/publish_tag_row.dart';
import 'package:node_diary/ui/widgets/alphabet_index_bar.dart';

import '../../../support/publish_panel_driver.dart';

/// 用户在标签管理里排好的顺序（`tagListProvider` 给出的顺序）。
const _names = <String>[
  '生活', '旅行', 'Work', '读书', '爱好', '电影', '摄影', '健身', '美食', '工作', //
  '家人', '朋友', '音乐', '学习', 'Coding', '运动', '咖啡', '随笔', '梦想', '2024',
];

final _tags = <Tag>[
  for (var i = 0; i < _names.length; i++)
    Tag(id: i + 1, name: _names[i], color: i.isEven ? 0xff2196f3 : 0xffe91e63),
];

int _idOf(String name) => _names.indexOf(name) + 1;

Future<PublishPanelDriver> _openTags(
  WidgetTester tester, {
  TagPickerSort sort = TagPickerSort.custom,
  Size size = const Size(400, 900),
  double textScale = 1,
  Brightness brightness = Brightness.light,
  String locale = 'en',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    publishPanelHost(
      tags: _tags,
      tagPickerSort: sort,
      textScale: textScale,
      brightness: brightness,
      locale: locale,
    ),
  );
  final driver = PublishPanelDriver(tester);
  await driver.openTags();
  return driver;
}

/// 标签行在屏幕上的纵坐标（整份列表一次建好，屏外的行也有位置）。
double _rowTop(WidgetTester tester, String name) =>
    tester.getTopLeft(find.widgetWithText(PublishTagRow, name)).dy;

Finder _sectionHeader(String letter) =>
    find.widgetWithText(PublishTagSectionHeader, letter);

Finder _indexLetter(String letter) => find.descendant(
  of: find.byType(AlphabetIndexBar),
  matching: find.text(letter),
);

void main() {
  group('search', () {
    testWidgets('narrows tags by name, full pinyin and initials', (
      tester,
    ) async {
      final driver = await _openTags(tester);
      expect(find.byType(PublishTagRow), findsNWidgets(_names.length));

      await tester.enterText(driver.tagSearchField, 'shenghuo');
      await tester.pump();
      expect(find.byType(PublishTagRow), findsOneWidget);
      expect(find.widgetWithText(PublishTagRow, '生活'), findsOneWidget);

      await tester.enterText(driver.tagSearchField, 'lx');
      await tester.pump();
      expect(find.byType(PublishTagRow), findsOneWidget);
      expect(find.widgetWithText(PublishTagRow, '旅行'), findsOneWidget);

      await tester.enterText(driver.tagSearchField, 'wor');
      // 等清空按钮的出现动画结束（缩放为 0 时点不中）。
      await tester.pumpAndSettle();
      expect(find.widgetWithText(PublishTagRow, 'Work'), findsOneWidget);

      // 清空按钮回到完整列表。
      await tester.tap(find.byTooltip(driver.l10n.autoT0130));
      await tester.pumpAndSettle();
      expect(find.byType(PublishTagRow), findsNWidgets(_names.length));
    });

    for (final sort in TagPickerSort.values) {
      testWidgets('typing after scrolling starts results at the top '
          '(${sort.name})', (tester) async {
        final driver = await _openTags(tester, sort: sort);
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -500),
        );
        await tester.pumpAndSettle();
        final scrollable = tester.state<ScrollableState>(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          ),
        );
        expect(scrollable.position.pixels, greaterThan(0));

        await tester.enterText(driver.tagSearchField, 's');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(scrollable.position.pixels, 0);
      });
    }

    testWidgets('a result row still toggles the tag on the draft', (
      tester,
    ) async {
      final driver = await _openTags(tester);
      await tester.enterText(driver.tagSearchField, '旅');
      await tester.pump();

      await tester.tap(find.widgetWithText(PublishTagRow, '旅行'));
      await tester.pumpAndSettle();
      expect(driver.draft.value.tagIds, {_idOf('旅行')});
    });

    testWidgets('no result offers to create a tag named after the search', (
      tester,
    ) async {
      final driver = await _openTags(tester);
      final l10n = driver.l10n;

      await tester.enterText(driver.tagSearchField, '跑步');
      await tester.pump();
      expect(find.byType(PublishTagRow), findsNothing);
      expect(find.text(l10n.tagPickerSearchEmpty('跑步')), findsOneWidget);

      await tester.tap(find.text(l10n.tagPickerCreateNamed('跑步')));
      await tester.pumpAndSettle();
      final nameField = tester.widget<TextField>(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
      );
      expect(nameField.controller!.text, '跑步');
      // 打开弹窗前已收起搜索框的键盘。
      expect(
        tester.widget<TextField>(driver.tagSearchField).focusNode!.hasFocus,
        isFalse,
      );
    });

    testWidgets('an existing name keeps the plain create row', (tester) async {
      final driver = await _openTags(tester);
      // 忽略大小写：已有 Work 时不再提议新建 work。
      await tester.enterText(driver.tagSearchField, 'work');
      await tester.pump();
      expect(find.text(driver.l10n.autoT0157), findsOneWidget);
      expect(find.text(driver.l10n.tagPickerCreateNamed('work')), findsNothing);
    });
  });

  group('sort', () {
    testWidgets('default order follows tag management without letters', (
      tester,
    ) async {
      await _openTags(tester);
      expect(_rowTop(tester, '生活'), lessThan(_rowTop(tester, '旅行')));
      expect(_rowTop(tester, '旅行'), lessThan(_rowTop(tester, 'Work')));
      expect(find.byType(PublishTagSectionHeader), findsNothing);
      expect(find.byType(AlphabetIndexBar), findsNothing);
    });

    testWidgets('alphabetical groups tags by pinyin letter with # last', (
      tester,
    ) async {
      final driver = await _openTags(tester);
      await driver.chooseTagSort(TagPickerSort.alphabetical);

      final order = ['爱好', 'Coding', '电影', '读书', '工作', '家人', '旅行'];
      for (var i = 1; i < order.length; i++) {
        expect(
          _rowTop(tester, order[i - 1]),
          lessThan(_rowTop(tester, order[i])),
          reason: '${order[i - 1]} before ${order[i]}',
        );
      }
      expect(_rowTop(tester, '运动'), lessThan(_rowTop(tester, '2024')));
      expect(_sectionHeader('A'), findsOneWidget);
      expect(_sectionHeader('#'), findsOneWidget);
      // 只列出现有的分组：没有以 I 开头的标签。
      expect(_indexLetter('A'), findsOneWidget);
      expect(_indexLetter('I'), findsNothing);

      // 换回默认排序，分组与索引条随之消失。
      await driver.chooseTagSort(TagPickerSort.custom);
      expect(find.byType(PublishTagSectionHeader), findsNothing);
      expect(find.byType(AlphabetIndexBar), findsNothing);
    });

    testWidgets('the sort menu marks the current choice', (tester) async {
      final driver = await _openTags(tester, sort: TagPickerSort.alphabetical);
      await tester.tap(driver.tagSortButton);
      await tester.pumpAndSettle();

      final selected = tester.widget<MenuItemButton>(
        find.widgetWithText(
          MenuItemButton,
          driver.l10n.tagPickerSortAlphabetical,
        ),
      );
      final other = tester.widget<MenuItemButton>(
        find.widgetWithText(MenuItemButton, driver.l10n.tagPickerSortCustom),
      );
      expect(selected.trailingIcon, isNotNull);
      expect(other.trailingIcon, isNull);
    });
  });

  group('letter index', () {
    double viewportTop(WidgetTester tester) =>
        tester.getTopLeft(find.byType(SingleChildScrollView)).dy;

    testWidgets('tapping a letter jumps its group to the top', (tester) async {
      await _openTags(tester, sort: TagPickerSort.alphabetical);
      expect(
        _rowTop(tester, '家人'),
        greaterThan(tester.getBottomLeft(find.byType(AlphabetIndexBar)).dy),
        reason: 'the J group starts below the visible list',
      );

      await tester.tap(_indexLetter('J'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(_sectionHeader('J')).dy,
        moreOrLessEquals(viewportTop(tester), epsilon: 1),
      );
    });

    testWidgets('dragging along the bar follows the finger with a bubble', (
      tester,
    ) async {
      await _openTags(tester, sort: TagPickerSort.alphabetical);
      final gesture = await tester.startGesture(
        tester.getCenter(_indexLetter('A')),
      );
      await tester.pump();
      // 按下即显示气泡：字母在分组标题、索引条与气泡里各出现一次。
      expect(find.text('A'), findsNWidgets(3));

      await gesture.moveTo(tester.getCenter(_indexLetter('M')));
      await tester.pump();
      expect(
        tester.getTopLeft(_sectionHeader('M')).dy,
        moreOrLessEquals(viewportTop(tester), epsilon: 1),
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('a search that leaves one group hides the bar', (tester) async {
      final driver = await _openTags(tester, sort: TagPickerSort.alphabetical);
      expect(find.byType(AlphabetIndexBar), findsOneWidget);

      await tester.enterText(driver.tagSearchField, 'lx');
      await tester.pumpAndSettle();
      expect(find.byType(AlphabetIndexBar), findsNothing);
      expect(_sectionHeader('L'), findsOneWidget);
    });
  });

  for (final brightness in Brightness.values) {
    for (final locale in ['en', 'zh']) {
      testWidgets('fits 320dp at 1.3x text in $locale, ${brightness.name}', (
        tester,
      ) async {
        final driver = await _openTags(
          tester,
          sort: TagPickerSort.alphabetical,
          size: const Size(320, 700),
          textScale: 1.3,
          brightness: brightness,
          locale: locale,
        );
        await tester.enterText(driver.tagSearchField, 'xyz');
        await tester.pumpAndSettle();
        await tester.enterText(driver.tagSearchField, '');
        await tester.pumpAndSettle();
        await tester.tap(driver.tagSortButton);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
