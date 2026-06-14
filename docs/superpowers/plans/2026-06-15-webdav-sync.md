# WebDAV Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete NAS-friendly WebDAV backup sync flow for Jotsy.

**Architecture:** Add focused WebDAV model, settings, protocol client, and orchestration service files under `lib/core/services`, then integrate a dedicated `WebDavSyncPage` from the existing data management page. Reuse `DataArchiveService` for ZIP export/import so remote sync remains backup-based and avoids unsafe record-level conflict handling.

**Tech Stack:** Flutter, Riverpod, SharedPreferences, dart:io `HttpClient`, XML parsing via `package:xml`, existing l10n/ARB generation.

---

### Task 1: WebDAV pure models and manifest

**Files:**
- Create: `lib/core/services/webdav_models.dart`
- Test: `test/core/services/webdav_models_test.dart`

- [ ] Write failing tests for config validation, remote path normalization, manifest JSON parsing, and backup sorting.
- [ ] Implement pure model classes and JSON helpers.
- [ ] Run `flutter test test/core/services/webdav_models_test.dart` and verify pass.

### Task 2: WebDAV protocol client

**Files:**
- Create: `lib/core/services/webdav_client.dart`
- Test: `test/core/services/webdav_client_test.dart`
- Modify: `pubspec.yaml` to add direct `xml` dependency.

- [ ] Write failing local `HttpServer` tests for Basic auth, recursive `MKCOL`, `PROPFIND` parsing, streaming `PUT`, streaming `GET`, and WebDAV status errors.
- [ ] Implement `WebDavClient` with `HttpClient` factory injection.
- [ ] Run `flutter test test/core/services/webdav_client_test.dart` and verify pass.

### Task 3: Settings and sync orchestration

**Files:**
- Create: `lib/core/services/webdav_settings_service.dart`
- Create: `lib/core/services/webdav_sync_service.dart`
- Modify: `lib/core/services/app_service.dart`
- Test: `test/core/services/webdav_sync_service_source_test.dart`

- [ ] Write failing tests/source checks for credential exclusion from archive, stream-safe transfer, manifest filename policy, and provider registration.
- [ ] Implement settings persistence and sync service methods: test connection, upload, list, download, restore, delete.
- [ ] Run targeted tests and verify pass.

### Task 4: UI integration and localization

**Files:**
- Modify: `lib/ui/settings/pages/data_management_page.dart`
- Create: `lib/ui/settings/pages/webdav_sync_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Regenerate: `lib/l10n/app_localizations_gen*.dart`

- [ ] Add ARB keys with metadata for every visible WebDAV string.
- [ ] Add data management entry and dedicated WebDAV sync page.
- [ ] Use FontAwesome icons, loading_indicator_m3e, colorScheme, text dialog buttons, and tracked SnackBars.
- [ ] Run `flutter gen-l10n` and verify generated code updated.

### Task 5: Verification and cleanup

**Files:**
- All changed Dart/ARB/doc files.

- [ ] Run `dart format` on modified Dart files.
- [ ] Run WebDAV-related tests.
- [ ] Run `flutter analyze`.
- [ ] Run broader `flutter test` if time permits.
- [ ] Review `git diff` for unrelated changes, hardcoded UI strings, direct SnackBars, gradients, and missing ARB metadata.
