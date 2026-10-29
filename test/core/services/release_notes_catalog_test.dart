import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/release_notes_catalog.dart';

import '../../support/fake_release_notes_bundle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pickReleaseNotesAssets', () {
    const paths = <String>[
      'docs/releases/v0.9.0.md',
      'docs/releases/v0.9.0.en.md',
      'docs/releases/v0.10.0.md',
      'docs/releases/v0.4.5+11.md',
      'docs/releases/v0.4.5+11.en.md',
      'docs/releases/v0.2.0+4.md',
      'docs/releases/v0.2.0+4.zh.md',
      'docs/releases/v0.2.0+4.en.md',
      'docs/releases/v0.1.0.zh.md',
      'docs/releases/README.md',
      'docs/releases/drafts/v1.0.0.md',
      'docs/app_update.md',
      'assets/img/support/alipay.png',
    ];

    test('orders versions newest first and ignores other files', () {
      final picked = pickReleaseNotesAssets(paths, languageCode: 'zh');

      expect(picked.map((asset) => asset.tag), <String>[
        'v0.10.0',
        'v0.9.0',
        'v0.4.5+11',
        'v0.2.0+4',
        'v0.1.0',
      ]);
    });

    test('picks the Chinese file and prefers <tag>.md over <tag>.zh.md', () {
      final picked = {
        for (final asset in pickReleaseNotesAssets(paths, languageCode: 'zh'))
          asset.tag: asset.path,
      };

      expect(picked['v0.9.0'], 'docs/releases/v0.9.0.md');
      expect(picked['v0.2.0+4'], 'docs/releases/v0.2.0+4.md');
      expect(picked['v0.1.0'], 'docs/releases/v0.1.0.zh.md');
    });

    test('picks the English file and falls back to Chinese when missing', () {
      final picked = {
        for (final asset in pickReleaseNotesAssets(paths, languageCode: 'en'))
          asset.tag: asset.path,
      };

      expect(picked['v0.9.0'], 'docs/releases/v0.9.0.en.md');
      expect(picked['v0.4.5+11'], 'docs/releases/v0.4.5+11.en.md');
      expect(picked['v0.10.0'], 'docs/releases/v0.10.0.md');
    });
  });

  group('loadBundledReleaseNotes', () {
    test('strips the web-only title and language switch', () async {
      final bundle = FakeReleaseNotesBundle(<String, String>{
        'docs/releases/v0.9.0.md': releaseNotesMarkdown(
          'v0.9.0',
          highlights: <String>['桌面版'],
        ),
        'docs/releases/v0.9.0.en.md': releaseNotesMarkdown(
          'v0.9.0',
          english: true,
          highlights: <String>['Desktop'],
        ),
      });

      final notes = await loadBundledReleaseNotes(bundle, languageCode: 'en');

      expect(notes, hasLength(1));
      expect(notes.single.tag, 'v0.9.0');
      expect(notes.single.markdown, '## Highlights\n- Desktop');
    });

    test('skips unreadable and empty files but keeps the rest', () async {
      final bundle = FakeReleaseNotesBundle(
        <String, String>{
          'docs/releases/v0.9.0.md': releaseNotesMarkdown('v0.9.0'),
          'docs/releases/v0.8.1.md': '# Release v0.8.1\n\n',
        },
        unreadable: <String>{'docs/releases/v0.8.0.md'},
      );

      final notes = await loadBundledReleaseNotes(bundle, languageCode: 'zh');

      expect(notes.map((entry) => entry.tag), <String>['v0.9.0']);
    });

    test('throws when the asset manifest cannot be read', () async {
      final bundle = FakeReleaseNotesBundle(
        const <String, String>{},
        manifestFails: true,
      );

      await expectLater(
        loadBundledReleaseNotes(bundle, languageCode: 'zh'),
        throwsA(isA<FlutterError>()),
      );
    });

    test('bundles every version in docs/releases in both languages', () async {
      final tags = Directory('docs/releases')
          .listSync()
          .whereType<File>()
          .map((file) => file.uri.pathSegments.last)
          .where((name) => name.endsWith('.md'))
          .map((name) => name.replaceFirst(RegExp(r'(\.en|\.zh)?\.md$'), ''))
          .toSet();
      expect(tags, isNotEmpty);

      for (final languageCode in <String>['zh', 'en']) {
        final notes = await loadBundledReleaseNotes(
          rootBundle,
          languageCode: languageCode,
        );
        expect(
          notes.map((entry) => entry.tag).toSet(),
          tags,
          reason: 'pubspec.yaml must list docs/releases/ as an asset',
        );
        for (final entry in notes) {
          expect(entry.markdown, isNot(startsWith('# Release')));
        }
      }
    });
  });
}
