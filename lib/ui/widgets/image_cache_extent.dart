/// Converts displayed image dimensions into Flutter image cache dimensions.
abstract final class ImageCacheExtent {
  static int? fromDisplaySize(double displaySize, double devicePixelRatio) {
    if (!displaySize.isFinite || displaySize <= 0) {
      return null;
    }
    final effectiveRatio =
        devicePixelRatio.isFinite && devicePixelRatio > 0
            ? devicePixelRatio
            : 1.0;
    final extent = (displaySize * effectiveRatio).round();
    return extent > 0 ? extent : null;
  }
}
