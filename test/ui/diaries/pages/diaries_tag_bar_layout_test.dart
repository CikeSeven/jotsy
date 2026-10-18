import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/app/theme/app_spacing.dart';
import 'package:node_diary/ui/diaries/widgets/tag_filter_chip.dart';
import 'package:node_diary/ui/diaries/widgets/tag_filter_clear_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'diaries_tag_filter_test_support.dart';

/// 首页标签栏的位置与显隐：标签行紧跟在搜索条下方，没有标签时不留孤零零的清除叉。
void main() {
  final searchPreview = find.byKey(const ValueKey<String>('search_preview'));

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('the tag row sits right under the search bar', (tester) async {
    await pumpTagPage(tester);

    final chip = find.byWidgetPredicate(
      (widget) => widget is TagFilterChip && widget.label == 'Tag 1',
    );
    final gap = tester.getRect(chip).top - tester.getRect(searchPreview).bottom;
    expect(gap, greaterThan(0));
    expect(gap, lessThanOrEqualTo(AppSpacing.m));
    expect(tester.takeException(), isNull);
  });

  testWidgets('without tags the home page shows no clear button', (
    tester,
  ) async {
    await pumpTagPage(tester, tagCount: 0);

    expect(find.byType(TagFilterClearButton).hitTestable(), findsNothing);
    expect(tester.getSize(tagBarFinder).height, 0);
    expect(tester.takeException(), isNull);
  });
}
