import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/explore/models/explore_appearance.dart';
import 'package:node_diary/ui/explore/models/explore_module_config.dart';
import 'package:node_diary/ui/explore/models/explore_module_id.dart';
import 'package:node_diary/ui/explore/sections/explore_modules_view.dart';
import 'package:node_diary/ui/explore/widgets/explore_appearance_scope.dart';

class _Card extends StatefulWidget {
  const _Card(this.id, this.mounts);

  final ExploreModuleId id;
  final Map<ExploreModuleId, int> mounts;

  @override
  State<_Card> createState() => _CardState();
}

class _CardState extends State<_Card> {
  int count = 0;

  @override
  void initState() {
    super.initState();
    widget.mounts.update(widget.id, (n) => n + 1, ifAbsent: () => 1);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 300,
    child: TextButton(
      onPressed: () => setState(() => count++),
      child: Text('${widget.id.name}: $count'),
    ),
  );
}

void main() {
  for (final brightness in Brightness.values) {
    for (final mode in <(double, ExploreWideFlow)>[
      (400, ExploreWideFlow.rows),
      (960, ExploreWideFlow.rows),
      (960, ExploreWideFlow.staggered),
    ]) {
      testWidgets('only mounts nearby cards and retains visited state '
          '(${brightness.name}, ${mode.$1}, ${mode.$2.name})', (tester) async {
        tester.view.physicalSize = Size(mode.$1, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final scroll = ScrollController();
        addTearDown(scroll.dispose);
        final mounts = <ExploreModuleId, int>{};
        final ids = ExploreModuleId.values;
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: ExploreAppearanceScope(
                appearance: ExploreAppearance(
                  columns: ExploreWideColumns.two,
                  flow: mode.$2,
                ),
                child: CustomScrollView(
                  controller: scroll,
                  slivers: <Widget>[
                    ExploreModulesView(
                      sliver: true,
                      slots: <ExploreModuleSlot>[
                        for (final id in ids)
                          ExploreModuleSlot(
                            config: ExploreModuleConfig(
                              id,
                              visible: true,
                              span: ExploreModuleSpan.half,
                            ),
                            child: _Card(id, mounts),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        expect(mounts.length, lessThan(ids.length ~/ 2));
        expect(mounts, isNot(contains(ids.last)));
        await tester.tap(find.text('${ids.first.name}: 0'));
        await tester.pump();
        await tester.scrollUntilVisible(
          find.text('${ids.last.name}: 0'),
          400,
          scrollable: find.byType(Scrollable),
        );
        scroll.jumpTo(0);
        await tester.pumpAndSettle();
        expect(find.text('${ids.first.name}: 1'), findsOneWidget);
        expect(mounts[ids.first], 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
