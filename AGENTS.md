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
- Run `dart format .` before committing.
- Lints come from `flutter_lints` (`analysis_options.yaml`).
- Use `snake_case` for files, `UpperCamelCase` for classes/widgets, and `lowerCamelCase` for members.
- Keep feature UI code in `lib/ui/<feature>/...`; cross-feature logic belongs in `lib/core/...`.
- For newly added UI icons, use `font_awesome_flutter` (`FaIcon` + `FontAwesomeIcons`) by default; only mix other icon sets when there is a clear platform-specific reason.
- Do not use any gradient colors in UI (including `LinearGradient`, `RadialGradient`, and `SweepGradient`).
- Write more high-value comments for non-trivial logic, state transitions, and edge-case handling; avoid redundant comments that only restate the code.
- Keep files focused and reasonably small; when a file grows beyond about 300 lines, evaluate splitting it into smaller widgets/classes/modules.
- Prefer timely decomposition over large monolithic files: extract reusable UI sections, business logic, and data-mapping code into dedicated files.

## Testing Guidelines
- Use `flutter_test` for widget and unit tests.
- Name test files `*_test.dart`.
- Prefer behavior-focused test names (for example, `shows_empty_state_when_no_notes`).
- For every functional change, add or update relevant tests and run `flutter test` + `flutter analyze`.
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

