import 'package:flutter_test/flutter_test.dart';
import 'package:node_note/core/database/content_codec.dart';

void main() {
  test('plain text and delta json codec should round-trip', () {
    const plainText = '今天下雨了\n心情还不错';
    final deltaJson = plainTextToDeltaJson(plainText);
    final restored = deltaJsonToPlainText(deltaJson);

    expect(restored, plainText);
  });

  test('metadata json should require object', () {
    expect(isValidMetadataJsonObject('{"weather":"rainy"}'), isTrue);
    expect(isValidMetadataJsonObject('[1,2,3]'), isFalse);
  });
}
