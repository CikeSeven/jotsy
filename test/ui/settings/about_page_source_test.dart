import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'about page exposes QQ feedback group and copies group number',
    () async {
      final source = await File(
        'lib/ui/settings/pages/about_page.dart',
      ).readAsString();
      expect(
        source,
        contains("static const String _qqFeedbackGroupNumber = '678136434'"),
      );
      expect(source, contains('FontAwesomeIcons.qq'));
      expect(source, contains('Clipboard.setData'));
      expect(
        source,
        contains('ClipboardData(text: AboutPage._qqFeedbackGroupNumber)'),
      );
      expect(source, contains('HomeHintVisibilityScope.showTrackedSnackBar'));
      expect(source, isNot(contains('ScaffoldMessenger.showSnackBar')));
      expect(source, contains('aboutQqFeedbackGroup'));
      expect(source, contains('aboutQqFeedbackGroupSubtitle'));
      expect(source, contains('aboutQqFeedbackGroupCopied'));
    },
  );
}
