import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_saved_strip.dart';
import 'package:node_diary/ui/diaries/widgets/diary_color_panel/diary_color_strip_slots.dart';

/// 我的颜色一行的条目顺序、增删排位与格宽（纯计算）。
void main() {
  const a = Color(0xFF112233);
  const b = Color(0xFF445566);
  const c = Color(0xFF778899);

  List<String> keys(List<DiaryColorStripSlot> slots) => <String>[
    for (final slot in slots) '${slot.leaving ? '-' : ''}${slot.key}',
  ];
  List<DiaryColorStripSlot> shown(List<DiaryColorStripEntry> entries) =>
      <DiaryColorStripSlot>[
        for (final entry in entries) DiaryColorStripSlot(entry),
      ];
  String saved(Color color) => 'saved-${color.toARGB32()}';
  String document(Color color) => 'document-${color.toARGB32()}';

  group('diaryColorStripEntries', () {
    test('saved colors first, a divider, then unsaved colors of the entry', () {
      final entries = diaryColorStripEntries(
        saved: const <Color>[a, b],
        document: const <Color>[b, c],
      );
      expect(entries.map((DiaryColorStripEntry e) => e.key), <String>[
        saved(a),
        saved(b),
        'divider',
        document(c),
      ]);
    });

    test('no divider when one group is empty', () {
      expect(
        diaryColorStripEntries(
          saved: const <Color>[a],
          document: const <Color>[a],
        ).map((DiaryColorStripEntry e) => e.key),
        <String>[saved(a)],
      );
      expect(
        diaryColorStripEntries(
          saved: const <Color>[],
          document: const <Color>[c],
        ).map((DiaryColorStripEntry e) => e.key),
        <String>[document(c)],
      );
    });
  });

  group('mergeDiaryColorStripSlots', () {
    test('a removed color stays in place while it collapses', () {
      final previous = shown(
        diaryColorStripEntries(
          saved: const <Color>[a, b, c],
          document: const <Color>[],
        ),
      );
      final merged = mergeDiaryColorStripSlots(
        previous,
        diaryColorStripEntries(
          saved: const <Color>[a, c],
          document: const <Color>[],
        ),
      );
      expect(keys(merged), <String>[saved(a), '-${saved(b)}', saved(c)]);
    });

    test('a kept color leaves the entry group and appears first', () {
      final previous = shown(
        diaryColorStripEntries(
          saved: const <Color>[a],
          document: const <Color>[c],
        ),
      );
      final merged = mergeDiaryColorStripSlots(
        previous,
        diaryColorStripEntries(
          saved: const <Color>[c, a],
          document: const <Color>[c],
        ),
      );
      expect(keys(merged), <String>[
        saved(c),
        saved(a),
        '-divider',
        '-${document(c)}',
      ]);
    });

    test('a collapsing slot that comes back is shown again in place', () {
      final leaving = mergeDiaryColorStripSlots(
        shown(
          diaryColorStripEntries(
            saved: const <Color>[a, b],
            document: const <Color>[],
          ),
        ),
        diaryColorStripEntries(
          saved: const <Color>[a],
          document: const <Color>[],
        ),
      );
      final back = mergeDiaryColorStripSlots(
        leaving,
        diaryColorStripEntries(
          saved: const <Color>[a, b],
          document: const <Color>[],
        ),
      );
      expect(keys(back), <String>[saved(a), saved(b)]);
    });
  });

  group('diaryColorStripSlotWidth', () {
    test('a half slot peeks out at the end of the visible area', () {
      // 392dp 的手机：8 列，每列 45dp，中间可见 6 列宽。
      const cell = 45.0;
      const viewport = 6 * cell;
      final width = diaryColorStripSlotWidth(viewport, cell);
      expect(width, greaterThanOrEqualTo(40));
      expect((viewport / width) % 1, closeTo(0.5, 1e-9));
    });

    test('wide toolbars keep slots close to the grid columns', () {
      final width = diaryColorStripSlotWidth(14 * 72, 72);
      expect(width, inInclusiveRange(72 * 0.85, 72 * 1.1));
    });
  });
}
