import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/providers/diary_filters.dart';

void main() {
  test('setTags filters non-positive ids and replaces selected tags', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(diaryFilterProvider.notifier);
    notifier.toggleTag(99, true);

    notifier.setTags(<int>[7, 0, -2, 7, 5]);

    expect(
      container.read(diaryFilterProvider).selectedTagIds,
      unorderedEquals(<int>[7, 5]),
    );
  });
}
