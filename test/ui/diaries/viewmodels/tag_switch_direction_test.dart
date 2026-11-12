import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/viewmodels/tag_switch_direction.dart';

void main() {
  const order = <int>[10, 20, 30];

  group('tagStripPosition', () {
    test('no selection sits at the clear button on the far left', () {
      expect(tagStripPosition(<int>{}, order), 0);
    });

    test('a single tag sits after the clear button in strip order', () {
      expect(tagStripPosition(<int>{10}, order), 1);
      expect(tagStripPosition(<int>{30}, order), 3);
    });

    test('multiple or off-strip selections have no position', () {
      expect(tagStripPosition(<int>{10, 20}, order), isNull);
      expect(tagStripPosition(<int>{99}, order), isNull);
    });
  });

  group('tagSwitchDirection', () {
    const ltr = TextDirection.ltr;

    test('moving right brings content in from the right', () {
      expect(tagSwitchDirection(0, 2, ltr), 1);
      expect(tagSwitchDirection(1, 3, ltr), 1);
    });

    test('moving left (or clearing) brings content in from the left', () {
      expect(tagSwitchDirection(3, 1, ltr), -1);
      expect(tagSwitchDirection(2, 0, ltr), -1);
    });

    test('same or unknown positions fall back to vertical', () {
      expect(tagSwitchDirection(2, 2, ltr), 0);
      expect(tagSwitchDirection(null, 2, ltr), 0);
      expect(tagSwitchDirection(1, null, ltr), 0);
    });

    test('right-to-left strips mirror the direction', () {
      expect(tagSwitchDirection(0, 2, TextDirection.rtl), -1);
      expect(tagSwitchDirection(3, 1, TextDirection.rtl), 1);
    });
  });
}
