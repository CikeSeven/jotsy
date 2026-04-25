# UI Performance Obvious Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the obvious low-risk UI performance issues identified in the audit without changing product behavior.

**Architecture:** Add one small image cache sizing helper, use it from thumbnail/cover/viewer surfaces, and decouple startup preload state from a root-level diary list watch. Keep changes localized to audited hotspots and defer any broad architecture work.

**Tech Stack:** Flutter, Dart, Riverpod, Drift-backed providers, existing image widgets, Flutter test.

---

## File Structure

- Create: `lib/ui/widgets/image_cache_extent.dart` — shared helper for finite image cache dimension calculation.
- Create: `test/ui/widgets/image_cache_extent_test.dart` — pure unit tests for helper edge cases.
- Modify: `lib/ui/explore/widgets/explore_shared_widgets.dart` — make `ExploreMediaThumb` derive finite sizes from constraints.
- Modify: `lib/ui/explore/pages/explore_media_gallery_page.dart` — provide bounded grid cell sizes to `ExploreMediaThumb`.
- Modify: `lib/ui/diaries/widgets/publish_diary_cover_sliver.dart` — add bounded cache sizes for cover images.
- Modify: `lib/ui/diaries/pages/diary_preview_page.dart` — add bounded cache sizes for static share cover images.
- Modify: `lib/ui/explore/pages/explore_image_viewer_page.dart` — add bounded cache sizes for full-screen viewer images.
- Modify: `lib/app/node_diary_app.dart` — replace root `watch(filteredDiariesProvider)` with startup-only listener state.
- Optional modify: `lib/ui/diaries/widgets/publish_diary_panel.dart` — add low-risk redundant parent-progress callback guard only if the code change is small.

## Task 1: Image Cache Extent Helper

**Files:**
- Create: `lib/ui/widgets/image_cache_extent.dart`
- Create: `test/ui/widgets/image_cache_extent_test.dart`

- [ ] **Step 1: Write failing tests**

Create `test/ui/widgets/image_cache_extent_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/ui/widgets/image_cache_extent_test.dart`

Expected: FAIL because `lib/ui/widgets/image_cache_extent.dart` does not exist yet.

- [ ] **Step 3: Implement helper**

Create `lib/ui/widgets/image_cache_extent.dart`:

```dart
/// Converts displayed image dimensions into Flutter image cache dimensions.
abstract final class ImageCacheExtent {
  static int? fromDisplaySize(double displaySize, double devicePixelRatio) {
    if (!displaySize.isFinite || displaySize <= 0) {
      return null;
    }
    final effectiveRatio =
        devicePixelRatio.isFinite && devicePixelRatio > 0 ? devicePixelRatio : 1.0;
    final extent = (displaySize * effectiveRatio).round();
    return extent > 0 ? extent : null;
  }
}
```

- [ ] **Step 4: Run tests to verify helper passes**

Run: `flutter test test/ui/widgets/image_cache_extent_test.dart`

Expected: PASS, 4 tests.

## Task 2: Explore Thumbnail Decode Safety

**Files:**
- Modify: `lib/ui/explore/widgets/explore_shared_widgets.dart`
- Modify: `lib/ui/explore/pages/explore_media_gallery_page.dart`

- [ ] **Step 1: Update thumbnail widget sizing**

In `lib/ui/explore/widgets/explore_shared_widgets.dart`, import the helper:

```dart
import 'package:node_diary/ui/widgets/image_cache_extent.dart';
```

Replace `ExploreMediaThumb.build` with a `LayoutBuilder` that resolves finite dimensions before calculating cache sizes:

```dart
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final resolvedWidth =
            width.isFinite ? width : constraints.maxWidth.isFinite ? constraints.maxWidth : null;
        final resolvedHeight =
            height.isFinite ? height : constraints.maxHeight.isFinite ? constraints.maxHeight : null;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth =
            resolvedWidth == null ? null : ImageCacheExtent.fromDisplaySize(resolvedWidth, dpr);
        final cacheHeight =
            resolvedHeight == null ? null : ImageCacheExtent.fromDisplaySize(resolvedHeight, dpr);
        final uri = Uri.tryParse(source);
        final isRemote =
            uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
        final image = isRemote
            ? Image.network(
                source,
                width: width,
                height: height,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                filterQuality: FilterQuality.low,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              )
            : Image.file(
                File(source),
                width: width,
                height: height,
                fit: BoxFit.cover,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                filterQuality: FilterQuality.low,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              );

        return ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            width: width,
            height: height,
            color: colorScheme.surfaceContainer,
            child: image,
          ),
        );
      },
    );
  }
```

- [ ] **Step 2: Pass finite gallery grid dimensions**

In `lib/ui/explore/pages/explore_media_gallery_page.dart`, wrap the `ExploreMediaThumb` child with `LayoutBuilder`:

```dart
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side = constraints.biggest.shortestSide;
                    return ExploreMediaThumb(
                      source: item.source,
                      width: side,
                      height: side,
                      radius: 12,
                    );
                  },
                ),
```

- [ ] **Step 3: Run focused test**

Run: `flutter test test/ui/widgets/image_cache_extent_test.dart`

Expected: PASS.

## Task 3: Large Image Decode Bounds

**Files:**
- Modify: `lib/ui/diaries/widgets/publish_diary_cover_sliver.dart`
- Modify: `lib/ui/diaries/pages/diary_preview_page.dart`
- Modify: `lib/ui/explore/pages/explore_image_viewer_page.dart`

- [ ] **Step 1: Add cache bounds to publish cover image**

In `lib/ui/diaries/widgets/publish_diary_cover_sliver.dart`, import `image_cache_extent.dart`, pass `maxExtentHeight` into `_CoverImage`, and compute cache sizes from `MediaQuery.sizeOf(context).width` and `maxExtentHeight`.

The `_CoverImage` constructor should become:

```dart
  const _CoverImage({required this.cover, required this.displayHeight});

  final String cover;
  final double displayHeight;
```

The delegate usage should become:

```dart
              child: _CoverImage(
                cover: cover,
                displayHeight: maxExtentHeight,
              ),
```

Inside `_CoverImage.build`, add:

```dart
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final displayWidth = MediaQuery.sizeOf(context).width;
    final cacheWidth = ImageCacheExtent.fromDisplaySize(displayWidth, dpr);
    final cacheHeight = ImageCacheExtent.fromDisplaySize(displayHeight, dpr);
```

Then pass `cacheWidth` and `cacheHeight` to both `Image.network` and `Image.file`.

- [ ] **Step 2: Add cache bounds to preview static cover**

In `lib/ui/diaries/pages/diary_preview_page.dart`, import `image_cache_extent.dart`. In `_buildPreviewCoverImage`, calculate cache dimensions using screen width and `420` display height, then pass them to `Image.network` and `Image.file`.

Use:

```dart
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = ImageCacheExtent.fromDisplaySize(
      MediaQuery.sizeOf(context).width,
      dpr,
    );
    final cacheHeight = ImageCacheExtent.fromDisplaySize(420, dpr);
```

- [ ] **Step 3: Add cache bounds to image viewer**

In `lib/ui/explore/pages/explore_image_viewer_page.dart`, import `image_cache_extent.dart`. In `_buildImagePage`, wrap the page in `LayoutBuilder` and compute cache dimensions from the available viewer constraints. Pass those cache dimensions to `Image.network` and `Image.file`.

Keep `InteractiveViewer`, `BoxFit.contain`, `loadingBuilder`, and `errorBuilder` behavior unchanged.

- [ ] **Step 4: Run focused helper test**

Run: `flutter test test/ui/widgets/image_cache_extent_test.dart`

Expected: PASS.

## Task 4: Startup Preload Decoupling

**Files:**
- Modify: `lib/app/node_diary_app.dart`

- [ ] **Step 1: Add startup preload state fields**

Add fields to `_NodeDiaryAppState`:

```dart
  ProviderSubscription<AsyncValue<List<DiaryWithTags>>>? _diariesBootstrapSubscription;
  bool _diariesBootstrapSettled = false;
  Object? _diariesBootstrapError;
```

- [ ] **Step 2: Start one-time listener in `initState`**

In `initState`, after timer setup, add a listener to `filteredDiariesProvider` that sets settled state once the stream has a value or error, then closes the subscription.

```dart
    _diariesBootstrapSubscription = ref.listenManual(
      filteredDiariesProvider,
      (_, next) {
        if (_diariesBootstrapSettled || (!next.hasValue && !next.hasError)) {
          return;
        }
        _diariesBootstrapSubscription?.close();
        _diariesBootstrapSubscription = null;
        if (!mounted) {
          return;
        }
        setState(() {
          _diariesBootstrapSettled = true;
          _diariesBootstrapError = next.asError?.error;
        });
      },
      fireImmediately: true,
    );
```

- [ ] **Step 3: Dispose listener**

In `dispose`, close `_diariesBootstrapSubscription` before `super.dispose()`.

- [ ] **Step 4: Remove root diary watch from `build`**

Remove `final diariesBootstrapAsync = ref.watch(filteredDiariesProvider);` and replace usages with `_diariesBootstrapSettled` and `_diariesBootstrapError`.

The startup readiness section should use:

```dart
    final diariesSettled = _diariesBootstrapSettled;
    final bootstrapReady =
        _minimumLoadingElapsed && settingsReady && diariesSettled;
    final startupNotice =
        bootstrapReady && _diariesBootstrapError != null
            ? _pickBootstrapText(
              settingsService: settingsService,
              zh: '启动时预加载日记失败，已进入主页。',
              en: 'Startup preload failed. Entered home anyway.',
            )
            : null;
```

- [ ] **Step 5: Run analyzer after this task**

Run: `flutter analyze`

Expected: no new analyzer errors from `node_diary_app.dart`.

## Task 5: Low-risk Publish Panel Progress Guard

**Files:**
- Modify: `lib/ui/diaries/widgets/publish_diary_panel.dart`

- [ ] **Step 1: Inspect existing progress callback behavior**

Read `_handleSheetMetricsChanged` and parent callback usage. If the parent depends on exact per-frame progress, skip this task and document it in the final notes.

- [ ] **Step 2: Add guard only if safe**

If safe, add a field:

```dart
  double? _lastReportedProgress;
```

Then replace the direct callback with a small threshold guard:

```dart
      final progress = _panelCoordinator.progress;
      final lastReportedProgress = _lastReportedProgress;
      if (lastReportedProgress == null ||
          (progress - lastReportedProgress).abs() >= 0.01 ||
          progress == 0 ||
          progress == 1) {
        _lastReportedProgress = progress;
        widget.onProgressChanged?.call(progress);
      }
```

- [ ] **Step 3: Verify analyzer after optional change**

Run: `flutter analyze`

Expected: no new analyzer errors from `publish_diary_panel.dart`.

## Task 6: Final Formatting and Verification

**Files:**
- All modified Dart files.

- [ ] **Step 1: Format changed Dart files**

Run: `dart format lib test`

Expected: formatter completes successfully.

- [ ] **Step 2: Run focused tests**

Run: `flutter test test/ui/widgets/image_cache_extent_test.dart`

Expected: PASS.

- [ ] **Step 3: Run full analysis**

Run: `flutter analyze`

Expected: no new errors or warnings introduced by this change.

- [ ] **Step 4: Report manual verification checklist**

Report these manual checks for the user to run if a simulator/device is not available:

```text
1. Open Explore media gallery; thumbnails render and tapping opens viewer.
2. Open image viewer; local/network images render and pinch zoom still works.
3. Open diary preview/publish cover pages; cover fit and alignment are unchanged.
4. Start app, then create/edit a diary; no startup overlay regression or app-shell flicker.
5. Drag publish panel; bottom spacing and keyboard behavior remain correct.
6. Repeat affected image surfaces in light and dark themes.
```

## Plan Self-review

- Spec coverage: all goals map to tasks 1-6; non-goals are explicitly deferred.
- Placeholder scan: no task contains TBD/TODO or unspecified implementation.
- Type consistency: helper name, imports, and field names are consistent across tasks.
- Commit handling: no commit step is included because repository instructions require explicit user request before committing.
