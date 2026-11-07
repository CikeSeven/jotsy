import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/widgets/expressive_reorder_proxy.dart';
import 'package:node_diary/ui/widgets/reorder_handle.dart';

/// 应用里的两种可排序列表。拖起时二者处理原行的方式不同：
/// `ReorderableListView` 给每行套了 GlobalKey，原行的 State 会搬进拖起的
/// 副本；`SliverReorderableList`（目录、模板、日记本管理）没有，原行直接卸载、
/// 副本是新建的一份，手柄要两种都能对上。
enum _ListKind { listView, sliver }

/// 三行可排序列表，每行行尾一个 [ReorderHandle]；排序结果写回 [order]。
Widget _host({
  required _ListKind kind,
  required List<String> order,
  bool enabled = true,
  String? semanticLabel,
}) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          void reorder(int oldIndex, int newIndex) =>
              setState(() => order.insert(newIndex, order.removeAt(oldIndex)));
          Widget row(BuildContext context, int index) => ListTile(
            key: ValueKey<String>(order[index]),
            title: Text(order[index]),
            trailing: ReorderHandle(
              index: index,
              enabled: enabled,
              semanticLabel: semanticLabel,
            ),
          );
          return switch (kind) {
            _ListKind.listView => ReorderableListView.builder(
              buildDefaultDragHandles: false,
              proxyDecorator: expressiveReorderProxyDecorator,
              itemCount: order.length,
              onReorderItem: reorder,
              itemBuilder: row,
            ),
            _ListKind.sliver => CustomScrollView(
              slivers: <Widget>[
                SliverReorderableList(
                  proxyDecorator: cardRowReorderProxyDecorator,
                  itemCount: order.length,
                  onReorderItem: reorder,
                  itemBuilder: row,
                ),
              ],
            ),
          };
        },
      ),
    ),
  );
}

/// 第 [index] 个手柄（含拖起的副本）里画握把的那个 CustomPaint。
Finder _grip(int index) => find.descendant(
  of: find.byType(ReorderHandle).at(index),
  matching: find.byType(CustomPaint),
);

/// 从第一行手柄的 [from] 处按下，往下拖过第二行（不到第三行）再松手。
Future<void> _dragFirstRowDown(WidgetTester tester, Offset from) async {
  final gesture = await tester.startGesture(from);
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await gesture.moveBy(const Offset(0, 12));
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  for (final kind in _ListKind.values) {
    group(kind.name, () {
      testWidgets('the whole 48dp square picks a row up, not only the dots', (
        tester,
      ) async {
        final order = <String>['a', 'b', 'c'];
        await tester.pumpWidget(_host(kind: kind, order: order));
        final handle = find.byType(ReorderHandle).first;
        expect(tester.getSize(handle), const Size.square(ReorderHandle.extent));
        // 按在左上角（离中间的圆点十几像素）也能拿起。以前 Padding 包图标时，
        // 留白不参与命中测试，这里按下去什么都不会发生。
        await _dragFirstRowDown(
          tester,
          tester.getTopLeft(handle) + const Offset(3, 3),
        );
        expect(order, <String>['b', 'a', 'c']);
        expect(tester.takeException(), isNull);
      });

      testWidgets('a disabled handle does not pick the row up', (tester) async {
        final order = <String>['a', 'b', 'c'];
        await tester.pumpWidget(
          _host(kind: kind, order: order, enabled: false),
        );
        await _dragFirstRowDown(
          tester,
          tester.getCenter(find.byType(ReorderHandle).first),
        );
        expect(order, <String>['a', 'b', 'c']);
      });

      testWidgets(
        'pressing shows the held capsule and the lifted row keeps it',
        (tester) async {
          final order = <String>['a', 'b', 'c'];
          await tester.pumpWidget(_host(kind: kind, order: order));
          final scheme = Theme.of(
            tester.element(find.byType(ReorderHandle).first),
          ).colorScheme;
          // 常态只有圆点，没有胶囊。
          expect(tester.renderObject(_grip(0)), isNot(paints..rrect()));

          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(ReorderHandle).first),
          );
          await tester.pumpAndSettle();
          expect(
            tester.renderObject(_grip(0)),
            paints..rrect(color: scheme.secondaryContainer),
          );

          // 拖起后原行换成占位，手柄只剩拖起的副本里那一个，仍是握住状态。
          for (var i = 0; i < 3; i++) {
            await gesture.moveBy(const Offset(0, 12));
            await tester.pump();
          }
          await tester.pumpAndSettle();
          final lifted = find.ancestor(
            of: find.text('a'),
            matching: find.byType(ReorderHandleLift),
          );
          expect(lifted, findsOneWidget);
          final liftedGrip = find.descendant(
            of: lifted,
            matching: find.descendant(
              of: find.byType(ReorderHandle),
              matching: find.byType(CustomPaint),
            ),
          );
          expect(
            tester.renderObject(liftedGrip),
            paints..rrect(color: scheme.secondaryContainer),
          );

          // 松手回位后回到常态；原行已卸载时松手事件不能再打到它身上。
          await gesture.up();
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(ReorderHandleLift), findsNothing);
          for (var i = 0; i < order.length; i++) {
            expect(tester.renderObject(_grip(i)), isNot(paints..rrect()));
          }
        },
      );

      testWidgets('a tap without moving releases the held state', (
        tester,
      ) async {
        final order = <String>['a', 'b', 'c'];
        await tester.pumpWidget(_host(kind: kind, order: order));
        await tester.tap(find.byType(ReorderHandle).first);
        await tester.pumpAndSettle();
        expect(tester.renderObject(_grip(0)), isNot(paints..rrect()));
        expect(order, <String>['a', 'b', 'c']);
      });
    });
  }

  testWidgets('screen readers hear a default or a row-specific label', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(kind: _ListKind.listView, order: <String>['a', 'b']),
    );
    // ReorderableListView 把整行合并成一个节点，标签接在标题后面。
    expect(
      find.bySemanticsLabel(RegExp(r'\nDrag to reorder$')),
      findsNWidgets(2),
    );

    await tester.pumpWidget(
      _host(
        kind: _ListKind.listView,
        order: <String>['a', 'b'],
        semanticLabel: 'Drag to reorder a',
      ),
    );
    expect(
      find.bySemanticsLabel(RegExp(r'\nDrag to reorder a$')),
      findsNWidgets(2),
    );
    semantics.dispose();
  });
}
