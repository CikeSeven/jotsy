import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/utils/provider_retention.dart';
import 'package:node_diary/utils/query_retention_budget.dart';

void main() {
  testWidgets(
    'idle byte budget evicts oldest queries and never an active query',
    (tester) async {
      final budget = QueryRetentionBudget(maxEntries: 10, maxBytes: 100);
      final query = Provider.autoDispose.family<int, int>((ref, id) {
        retainQueryWhileRecentlyUsed(ref, estimatedBytes: () => 60);
        return id;
      });
      final container = ProviderContainer(
        overrides: [queryRetentionBudgetProvider.overrideWithValue(budget)],
      );
      addTearDown(container.dispose);
      final active = container.listen(query(0), (_, _) {});
      addTearDown(active.close);
      container.listen(query(1), (_, _) {}).close();
      container.listen(query(2), (_, _) {}).close();
      await tester.pump(const Duration(milliseconds: 20));
      expect(container.exists(query(0)), isTrue);
      expect(container.exists(query(1)), isFalse);
      expect(container.exists(query(2)), isTrue);
      expect(budget.retainedBytes, 60);
      await tester.pump(queryIdleRetention);
      expect(container.exists(query(0)), isTrue);
      expect(container.exists(query(2)), isFalse);
      expect(budget.idleEntries, 0);
    },
  );

  test('an idle result growing past budget is released on update', () {
    final budget = QueryRetentionBudget(maxBytes: 100);
    var bytes = 20;
    var releases = 0;
    budget.retain(Object(), bytes: () => bytes, release: () => releases++);
    bytes = 120;
    budget.trim();
    expect(releases, 1);
    expect(budget.retainedBytes, 0);
  });
}
