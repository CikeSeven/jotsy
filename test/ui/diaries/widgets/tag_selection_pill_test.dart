import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/app_database.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/widgets/diary_tag_filter_bar.dart';
import 'package:node_diary/ui/diaries/widgets/tag_filter_chip.dart';
import 'package:node_diary/ui/diaries/widgets/tag_selection_pill.dart';

import '../../../support/expressive_test_theme.dart';

/// 会响应点按的标签栏：单击只选这一个（再点取消）、长按加减、✕ 清空，
/// 与首页的选择规则一致。
class _SelectableBar extends StatefulWidget {
  const _SelectableBar({required this.tags, this.initial = const <int>{}});

  final List<Tag> tags;
  final Set<int> initial;

  @override
  State<_SelectableBar> createState() => _SelectableBarState();
}

class _SelectableBarState extends State<_SelectableBar> {
  late Set<int> _selected = widget.initial;
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: DiaryTagFilterBar(
        tags: widget.tags,
        expansionProgress: _progress,
        canExpand: () => false,
        canCollapse: () => false,
        selectedTagFilterIds: _selected,
        onSelectTag: (int id) => setState(
          () => _selected = _selected.length == 1 && _selected.contains(id)
              ? <int>{}
              : <int>{id},
        ),
        onToggleTagFilter: (int id, bool selected) => setState(
          () => _selected = selected
              ? <int>{..._selected, id}
              : (<int>{..._selected}..remove(id)),
        ),
        onClearTagFilters: () => setState(() => _selected = <int>{}),
        onVerticalDragStart: (_) {},
        onVerticalDragUpdate: (_, __) {},
        onVerticalDragEnd: (_) {},
        onCollapse: () {},
      ),
    );
  }
}

List<Tag> _tags(int count) => <Tag>[
  for (var i = 1; i <= count; i++)
    Tag(id: i, name: 'Tag $i', color: 0xff336699 + i * 0x101010),
];

Future<void> _pump(
  WidgetTester tester, {
  int count = 4,
  Set<int> initial = const <int>{},
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(390, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: expressiveTestTheme(Brightness.light),
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: _SelectableBar(tags: _tags(count), initial: initial),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _chip(int id) => find.byWidgetPredicate(
  (Widget widget) => widget is TagFilterChip && widget.label == 'Tag $id',
);

RenderTagSelectionPill _layer(WidgetTester tester) => tester
    .renderObject<RenderTagSelectionPill>(find.byType(TagSelectionPillLayer));

/// 色块此刻的外框（全局坐标）；不画时为 null。
Rect? _pill(WidgetTester tester) {
  final layer = _layer(tester);
  final rect = layer.debugPaintedRect;
  if (rect == null) {
    return null;
  }
  return rect.shift(layer.localToGlobal(Offset.zero));
}

void _expectRectClose(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, 0.5));
  expect(actual.top, closeTo(expected.top, 0.5));
  expect(actual.right, closeTo(expected.right, 0.5));
  expect(actual.bottom, closeTo(expected.bottom, 0.5));
}

void main() {
  testWidgets('no pill is painted without a selection', (tester) async {
    await _pump(tester);
    expect(_pill(tester), isNull);
  });

  testWidgets('selecting a tag grows the pill onto its chip', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Tag 2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final growing = _pill(tester)!;
    final chip = tester.getRect(_chip(2));
    // 出现途中略小于胶囊，围着胶囊中心放大。
    expect(growing.width, lessThan(chip.width));
    expect(growing.center.dx, closeTo(chip.center.dx, 0.5));

    await tester.pumpAndSettle();
    _expectRectClose(_pill(tester)!, tester.getRect(_chip(2)));
    // 选中的胶囊自己不画选中底色，由色块代画。
    expect(
      tester.widget<TagFilterChip>(_chip(2)).paintsSelectedSurface,
      isFalse,
    );
  });

  testWidgets('switching tags slides the pill from the old chip to the new', (
    tester,
  ) async {
    await _pump(tester, initial: const <int>{1});
    _expectRectClose(_pill(tester)!, tester.getRect(_chip(1)));
    final from = tester.getRect(_chip(1)).center.dx;
    final to = tester.getRect(_chip(3)).center.dx;

    await tester.tap(find.text('Tag 3'));
    var sawMidway = false;
    var sawStretch = false;
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final pill = _pill(tester)!;
      if (pill.center.dx > from + 4 && pill.center.dx < to - 4) {
        sawMidway = true;
        // 途中按速度沿运动方向拉长。
        final chipWidth = tester.getRect(_chip(3)).width;
        if (pill.width > chipWidth + 2) {
          sawStretch = true;
        }
      }
    }
    expect(sawMidway, isTrue);
    expect(sawStretch, isTrue);
    await tester.pumpAndSettle();
    _expectRectClose(_pill(tester)!, tester.getRect(_chip(3)));
  });

  testWidgets('multi-select hides the pill and chips paint themselves', (
    tester,
  ) async {
    await _pump(tester, initial: const <int>{1});

    await tester.longPress(find.text('Tag 2'));
    await tester.pumpAndSettle();
    expect(_pill(tester), isNull);
    for (final id in <int>[1, 2]) {
      final chip = tester.widget<TagFilterChip>(_chip(id));
      expect(chip.selected, isTrue);
      expect(chip.paintsSelectedSurface, isTrue);
    }

    // 回到只选一个：色块在它身上重新出现。
    await tester.longPress(find.text('Tag 2'));
    await tester.pumpAndSettle();
    _expectRectClose(_pill(tester)!, tester.getRect(_chip(1)));
  });

  testWidgets('clearing fades the pill out where it is', (tester) async {
    await _pump(tester, initial: const <int>{2});
    final chip = tester.getRect(_chip(2));

    await tester.tap(find.bySemanticsLabel('Clear tag filters'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final fading = _pill(tester);
    expect(fading, isNotNull);
    expect(fading!.center.dx, closeTo(chip.center.dx, 0.5));
    await tester.pumpAndSettle();
    expect(_pill(tester), isNull);
  });

  testWidgets('reduce motion moves the pill without sliding', (tester) async {
    await _pump(tester, initial: const <int>{1}, reduceMotion: true);

    await tester.tap(find.text('Tag 3'));
    await tester.pump();
    _expectRectClose(_pill(tester)!, tester.getRect(_chip(3)));
  });

  testWidgets('a chip clipped at the edge scrolls fully into view', (
    tester,
  ) async {
    await _pump(tester, count: 12);
    final viewport = tester.getRect(
      find.descendant(
        of: find.byType(DiaryTagFilterBar),
        matching: find.byType(ListView),
      ),
    );
    // 找一个被右缘截住的胶囊，点它露出来的那一截。
    var clipped = 0;
    for (var id = 1; id <= 12; id++) {
      if (_chip(id).evaluate().isEmpty) {
        break;
      }
      final rect = tester.getRect(_chip(id));
      if (rect.left < viewport.right - 8 && rect.right > viewport.right) {
        clipped = id;
        break;
      }
    }
    expect(clipped, isNot(0));
    final visiblePart = tester.getRect(_chip(clipped)).left + 4;
    await tester.tapAt(
      Offset(visiblePart, tester.getCenter(_chip(clipped)).dy),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(_chip(clipped));
    expect(rect.right, lessThanOrEqualTo(viewport.right - 8));
    _expectRectClose(_pill(tester)!, rect);
  });
}
