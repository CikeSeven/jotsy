import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/ui/widgets/image_cache_extent.dart';

void main() {
  group('ImageCacheExtent', () {
    test('returns scaled integer cache size for finite dimensions', () {
      expect(ImageCacheExtent.fromDisplaySize(120, 2.5), 300);
    });

    test('returns null for infinite dimensions', () {
      expect(ImageCacheExtent.fromDisplaySize(double.infinity, 3), isNull);
    });

    test('returns null for zero, negative, or invalid dimensions', () {
      expect(ImageCacheExtent.fromDisplaySize(0, 3), isNull);
      expect(ImageCacheExtent.fromDisplaySize(-12, 3), isNull);
      expect(ImageCacheExtent.fromDisplaySize(double.nan, 3), isNull);
    });

    test('uses a minimum positive device pixel ratio', () {
      expect(ImageCacheExtent.fromDisplaySize(80, 0), 80);
      expect(ImageCacheExtent.fromDisplaySize(80, -2), 80);
    });
  });
}
