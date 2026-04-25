import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/explore/widgets/explore_shared_widgets.dart';

void main() {
  testWidgets('ExploreMediaThumb handles infinite dimensions from grid cells', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 96,
            height: 96,
            child: ExploreMediaThumb(
              source: '/missing/image.jpg',
              width: double.infinity,
              height: double.infinity,
              radius: 12,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
