# Repository Guidelines

## Project Structure & Module Organization
This repository is a Flutter application. Main entry is `lib/main.dart`.
- `lib/app/`: app shell and theme setup (`node_diary_app.dart`, theme files).
- `lib/core/services/`: shared services and app-level logic.
- `lib/ui/<feature>/pages/`: feature pages (home, notes, settings).
- `test/`: automated tests (`widget_test.dart` currently).
- `android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/`: platform runners and assets.
- `pubspec.yaml`: dependencies, SDK constraints, and build metadata.

## Build, Test, and Development Commands
Use these commands from repository root:
```bash
flutter pub get
flutter run -d windows
flutter analyze
flutter test
dart run build_runner build --delete-conflicting-outputs
```
- Agent execution note: do not run `dart format` or `flutter analyze` automatically (they may time out in this environment); leave both commands for the user to run manually when needed.
- `flutter pub get`: install/update dependencies.
- `flutter run -d windows`: run locally (replace device as needed, e.g. `chrome`).
- `flutter analyze`: static checks using `analysis_options.yaml`.
- `flutter test`: run unit/widget tests in `test/`.
- `build_runner ...`: regenerate code for tools like `json_serializable` and Drift.

## Coding Style & Naming Conventions
- File encoding must be UTF-8.
- Follow Dart style: 2-space indentation and formatted code.
- Do not run `dart format` or `flutter analyze` as part of automated agent execution; the user runs them manually.
- Lints come from `flutter_lints` (`analysis_options.yaml`).
- Use `snake_case` for files, `UpperCamelCase` for classes/widgets, and `lowerCamelCase` for members.
- Keep feature UI code in `lib/ui/<feature>/...`; cross-feature logic belongs in `lib/core/...`.
- For newly added UI icons, use `font_awesome_flutter` (`FaIcon` + `FontAwesomeIcons`) by default; only mix other icon sets when there is a clear platform-specific reason.
- Rich text editor toolbar icons and their related settings-page icon previews must consistently use `font_awesome_flutter` (`FaIcon` + `FontAwesomeIcons`).
- Dialog action buttons must use text-style actions consistently: left action uses a gray text button (typically cancel), right action uses a colored text button for the primary confirm action.
- For dangerous dialog actions (delete/irreversible operations), the right primary action must use `colorScheme.error` instead of the default primary color.
- Active interactive surfaces (for example: bottom bars, floating panels, and key action containers) should use a glassmorphism style consistent with the app's existing glass components.
- Glass-style implementation notes:
  - Reuse existing theme tokens/components first (for example `AppEffects`, `AppRadii`, and existing glass widgets) to keep style consistent.
  - Keep blur and transparency moderate to preserve text contrast and avoid readability regressions.
  - Avoid stacking multiple heavy blur layers in the same viewport region to reduce rendering cost on lower-end devices.
  - Preserve clear interaction affordance (tap targets, boundaries, and state feedback) even when using translucent backgrounds.
- Do not use any gradient colors in UI (including `LinearGradient`, `RadialGradient`, and `SweepGradient`).
- Write detailed high-value comments for non-trivial logic, state transitions, async chains, rollback behavior, and edge-case handling.
- Avoid redundant comments that only restate obvious code; comments must explain intent, boundaries, and decision rationale.
- Keep files focused and reasonably small; when a file grows beyond about 300 lines, proactively evaluate splitting it into smaller widgets/classes/modules.
- Prefer timely decomposition over monolithic files: extract reusable UI sections, business orchestration, and data-mapping code into dedicated files.

## Diaries Module Layering & Comment Rules
- Scope: all code under `lib/ui/diaries/`.
- `pages/` should be shell-oriented: route wiring, lifecycle, provider watch, and widget composition only. Avoid embedding large business workflows directly in page `State`.
- Business orchestration should be extracted to `controllers/` (search/filter flows, delete/archive/undo, publish chain, draft autosave/debounce, navigation handoff).
- Local derived state and parsing/mapping utilities should live in `viewmodels/` or `models/`, not inline in pages.
- Complex reusable UI blocks belong in `sections/` or `widgets/`; keep page files from becoming mixed UI+business monoliths.
- Add file-level responsibility comments for controllers/pages/complex widgets, including clear boundary notes (inputs, outputs, side effects).
- For methods involving async/timer/queue behavior, add explicit step comments (trigger condition, mutation order, rollback strategy, mounted checks).
- For multi-state UI regions, add section comments to describe structure and intent (for example header/search/selection states, panel main page vs tag page, loading/error/empty/data branches).
- Comment depth should be detailed and practical, but avoid noisy line-by-line narration.

## Testing Guidelines
- Use `flutter_test` for widget and unit tests.
- Name test files `*_test.dart`.
- Prefer behavior-focused test names (for example, `shows_empty_state_when_no_notes`).
- For every functional change, add or update relevant tests and run `flutter test`; `flutter analyze` is executed manually by the user when needed.
- No enforced coverage threshold yet; avoid merging untested logic changes.

## Commit & Pull Request Guidelines
Local workspace does not include `.git` history, so follow this default convention:
- Use Conventional Commit prefixes: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`.
- Keep commits small and single-purpose.
- PRs should include: clear summary, affected modules, test evidence, and screenshots/GIFs for UI changes.
- Link related issues/tasks and call out platform-specific impact if applicable.

## Security & Configuration Tips
- Do not commit secrets, tokens, or machine-local config values.
- Treat files like `android/local.properties` as local-only.
- Review dependency and lockfile changes in `pubspec.yaml` and `pubspec.lock` before merge.
 
