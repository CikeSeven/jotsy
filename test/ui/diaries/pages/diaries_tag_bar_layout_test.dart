import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/diaries/widgets/tag_filter_clear_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'diaries_tag_filter_test_support.dart';

/// 首页标签栏的位置与显隐：没有标签时不留孤零零的清除叉。
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
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
