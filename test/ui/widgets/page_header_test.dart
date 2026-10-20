import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_presets.dart';
import 'package:node_diary/ui/home/models/home_bar_style/home_bar_resolved_style.dart';
import 'package:node_diary/ui/home/widgets/home_bar/home_chrome_scope.dart';
import 'package:node_diary/ui/widgets/glass/glass_surface.dart';
import 'package:node_diary/ui/widgets/page_header.dart';

const double _statusBar = 24;

/// [glass] 为 true 时把页头放进玻璃预设的 [HomeChromeScope]（与首页相同）。
Widget _host({required bool glass}) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final page = MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(padding: const EdgeInsets.only(top: _statusBar)),
          child: const Scaffold(
            body: Stack(children: <Widget>[PageHeader(title: 'Explore')]),
          ),
        );
        if (!glass) {
          return page;
        }
        return HomeChromeScope(
          style: HomeBarResolvedStyle.resolve(
            HomeBarPreset.glass.style,
            scheme,
          ),
          child: page,
        );
      },
    ),
  );
}

Finder get _header => find.byType(PageHeader);

void main() {
  testWidgets('without a home scope the header is the plain surface block', (
    tester,
  ) async {
    await tester.pumpWidget(_host(glass: false));
    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.byType(GlassSurface), findsNothing);
    final boxFinder = find
        .descendant(of: _header, matching: find.byType(ColoredBox))
        .first;
    final context = tester.element(_header);
    expect(
      tester.widget<ColoredBox>(boxFinder).color,
      Theme.of(context).colorScheme.surface,
    );
    expect(
      tester.getSize(boxFinder).height,
      _statusBar + PageHeader.contentHeight,
    );
    expect(tester.getTopLeft(find.text('Explore')).dy, greaterThan(_statusBar));
  });

  testWidgets('glass top bars blur behind the header at the same layout', (
    tester,
  ) async {
    await tester.pumpWidget(_host(glass: false));
    final solidTitle = tester.getRect(find.text('Explore'));

    await tester.pumpWidget(_host(glass: true));
    final backdrop = find.descendant(
      of: _header,
      matching: find.byType(BackdropFilter),
    );
    expect(backdrop, findsOneWidget);
    expect(tester.widget<BackdropFilter>(backdrop).enabled, isTrue);
    expect(tester.getRect(find.text('Explore')), solidTitle);
    expect(
      tester.getSize(find.byType(GlassSurface)).height,
      _statusBar + PageHeader.contentHeight,
    );
  });
}
