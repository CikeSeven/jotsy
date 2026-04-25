# UI Performance Obvious Fixes Design

## Background

The UI performance audit found several high-confidence issues that can be fixed without changing product behavior or data architecture. This work intentionally targets only obvious, low-risk fixes. Larger structural work such as database pagination, Quill editor scroll redesign, image import compression, and persisted Explore statistics remains out of scope for this pass.

## Goals

- Prevent invalid or unbounded image cache size calculations in Explore media thumbnails.
- Reduce unnecessary app-root rebuilds caused by startup diary preloading.
- Limit large-image decoding in cover, preview, and image viewer surfaces.
- Reduce high-frequency parent rebuilds caused by publish panel drag progress where this can be done safely.
- Preserve existing UI behavior, layout, localization, and navigation flows.

## Non-goals

- Do not implement database-level pagination for diary lists.
- Do not redesign Quill editor scrolling or rich-text document virtualization.
- Do not add image compression or thumbnail generation to import/storage services.
- Do not rewrite Explore page aggregation or statistics data flow.
- Do not change visible UI style beyond behavior-preserving loading/image fixes.

## Proposed Changes

### 1. Explore Thumbnail Decode Safety

`ExploreMediaThumb` currently accepts explicit `width` and `height`, then immediately multiplies them by device pixel ratio to compute `cacheWidth` and `cacheHeight`. The media gallery passes `double.infinity`, which can produce invalid rounding and disables meaningful decode constraints.

The component will be updated to derive finite render dimensions from layout constraints when explicit dimensions are not finite. The gallery grid will provide bounded dimensions through `LayoutBuilder`, so each thumbnail decodes close to its displayed cell size. The component will also guard cache size calculation with finite, positive checks.

Expected result: media gallery thumbnails keep their current square layout while avoiding invalid cache dimensions and excessive decode size.

### 2. App Startup Preload Without Long-lived Root Diary Watch

`NodeDiaryApp` uses `ref.watch(filteredDiariesProvider)` in `build()` for startup gating. After startup completes, this keeps the app root subscribed to diary list changes and may rebuild `MaterialApp` for unrelated diary/filter updates.

Startup diary readiness will move into local state driven by a one-time provider listener or future read. The app shell will continue to wait for settings readiness, minimum loading duration, and the first diary preload result. Once diary preload settles, later diary list changes will not affect app-root build state.

Expected result: startup behavior stays the same, but normal diary mutations no longer trigger root-level app rebuilds.

### 3. Large Image Decode Bounds

Large image surfaces will calculate reasonable `cacheWidth` and `cacheHeight` from available display size and device pixel ratio.

Initial targets:

- `PublishDiaryCoverSliver` cover image.
- Diary preview cover image.
- Explore image viewer current page image.

The implementation will preserve existing `BoxFit`, alignment, error builders, and local/network image support. Cache size calculation will be conservative and skipped when dimensions are unavailable or invalid.

Expected result: cover and viewer pages avoid decoding full original images when a screen-sized decode is enough.

### 4. Publish Panel Drag Rebuild Containment

The publish panel currently calls `setState()` on every meaningful sheet progress update and forwards progress to the parent page. This can cause more rebuild work than necessary during drag gestures.

This pass will make only low-risk containment changes. The panel will avoid redundant callbacks and parent updates when the derived layout effect does not change enough to matter. If a deeper refactor would require changing the sheet architecture, it will be deferred.

Expected result: drag behavior remains unchanged while avoiding unnecessary parent rebuilds in common cases.

## Data Flow

- Image widgets receive or derive finite display dimensions.
- A small helper converts display dimensions plus device pixel ratio into nullable cache dimensions.
- Startup readiness becomes local app state instead of direct root `watch()` on the diary list stream.
- Publish panel progress remains owned by the panel coordinator; parent communication is throttled or guarded by value changes.

## Error Handling

- Existing image `errorBuilder` behavior remains unchanged.
- Invalid image dimensions produce `null` cache dimensions instead of throwing.
- Startup diary preload failures keep the existing behavior: the app enters home and shows the startup notice.
- Provider/listener cancellation must happen in `dispose()` to avoid late updates after unmount.

## Testing and Verification

Automated checks:

- Run `dart format` on changed Dart files.
- Run `flutter analyze` from the repository root.

Manual checks:

- Open Explore media gallery and verify thumbnails render without exceptions.
- Open image viewer from Explore gallery for local and remote images if available.
- Open diary preview and publish/edit cover screens and verify cover display is unchanged.
- Create or edit a diary after startup and verify no startup overlay regression or app-shell flicker.
- Drag the publish panel and verify layout, keyboard spacing, and bottom spacer behavior remain correct.
- Check affected image surfaces in both light and dark themes.

## Implementation Boundaries

Changes should stay near the audited hotspots:

- `lib/ui/explore/widgets/explore_shared_widgets.dart`
- `lib/ui/explore/pages/explore_media_gallery_page.dart`
- `lib/app/node_diary_app.dart`
- `lib/ui/diaries/widgets/publish_diary_cover_sliver.dart`
- `lib/ui/diaries/pages/diary_preview_page.dart`
- `lib/ui/explore/pages/explore_image_viewer_page.dart`
- `lib/ui/diaries/widgets/publish_diary_panel.dart` only if the low-risk guard is straightforward

If any fix requires broad architecture changes, defer it and document it in the final notes instead of expanding scope.
