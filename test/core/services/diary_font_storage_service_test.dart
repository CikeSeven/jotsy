import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/diary_font_storage_service.dart';
import 'package:path/path.dart' as p;

import '../../support/font_file_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Directory base;
  late DiaryFontStorageService storage;

  const bundledFontPath =
      'assets/fonts/harmonyos_sans_sc/HarmonyOS_Sans_SC_Regular.ttf';

  setUp(() async {
    root = await Directory.systemTemp.createTemp('jotsy_diary_fonts_');
    base = await Directory(p.join(root.path, 'support')).create();
    storage = DiaryFontStorageService(baseDirectory: () async => base);
  });

  tearDown(() async {
    await root.delete(recursive: true);
  });

  Future<String> writeSource(String name, List<int> bytes) async {
    final file = File(p.join(root.path, name));
    await file.writeAsBytes(bytes);
    return file.path;
  }

  Directory fontDirectory() =>
      Directory(p.join(base.path, DiaryFontStorageService.directoryName));

  test('imports a font under its family name and lists it', () async {
    final source = await writeSource(
      'LXGWWenKai-Regular.ttf',
      buildTestFont(
        names: <TestFontName>[
          (
            platform: 3,
            encoding: 1,
            language: 0x0409,
            nameId: 1,
            value: 'LXGW',
          ),
          (platform: 3, encoding: 1, language: 0x0804, nameId: 1, value: '霞鹜'),
        ],
      ),
    );

    final font = await storage.importFont(source, languageCode: 'zh');

    expect(font.name, '霞鹜');
    expect(font.fileName, '${font.id}.ttf');
    expect(
      await File(p.join(fontDirectory().path, font.fileName)).exists(),
      isTrue,
    );
    expect(await storage.listFonts(), <DiaryImportedFont>[font]);
    // 新实例从清单读出同样的条目（重启后仍在）。
    expect(
      await DiaryFontStorageService(
        baseDirectory: () async => base,
      ).listFonts(),
      <DiaryImportedFont>[font],
    );
  });

  test('uses the file name when the font has no family name', () async {
    final source = await writeSource(
      'MyHandwriting.otf',
      buildTestFont(version: 0x4F54544F, includeNameTable: false),
    );

    final font = await storage.importFont(source, languageCode: 'en');

    expect(font.name, 'MyHandwriting');
    expect(font.fileName, endsWith('.otf'));
  });

  test('importing the same font twice keeps a single entry', () async {
    final bytes = buildTestFont(
      names: <TestFontName>[
        (platform: 3, encoding: 1, language: 0x0409, nameId: 1, value: 'Same'),
      ],
    );
    final first = await storage.importFont(
      await writeSource('a.ttf', bytes),
      languageCode: 'en',
    );
    final second = await storage.importFont(
      await writeSource('b.ttf', bytes),
      languageCode: 'en',
    );

    expect(second, first);
    expect(await storage.listFonts(), hasLength(1));
  });

  test('rejects files that are not fonts without writing anything', () async {
    final source = await writeSource('notes.txt', 'hello'.codeUnits);

    await expectLater(
      storage.importFont(source, languageCode: 'en'),
      throwsA(
        isA<DiaryFontImportException>().having(
          (error) => error.failure,
          'failure',
          DiaryFontImportFailure.unsupportedFormat,
        ),
      ),
    );
    await expectLater(
      storage.importFont(p.join(root.path, 'missing.ttf'), languageCode: 'en'),
      throwsA(
        isA<DiaryFontImportException>().having(
          (error) => error.failure,
          'failure',
          DiaryFontImportFailure.unreadable,
        ),
      ),
    );
    expect(await storage.listFonts(), isEmpty);
  });

  test('deleting a font removes its file and manifest entry', () async {
    final keep = await storage.importFont(
      await writeSource(
        'keep.ttf',
        buildTestFont(
          names: <TestFontName>[
            (platform: 3, encoding: 1, language: 0x0409, nameId: 1, value: 'K'),
          ],
        ),
      ),
      languageCode: 'en',
    );
    final drop = await storage.importFont(
      await writeSource(
        'drop.ttf',
        buildTestFont(
          names: <TestFontName>[
            (platform: 3, encoding: 1, language: 0x0409, nameId: 1, value: 'D'),
          ],
        ),
      ),
      languageCode: 'en',
    );

    await storage.deleteFont(drop.id);

    expect(await storage.listFonts(), <DiaryImportedFont>[keep]);
    expect(
      await File(p.join(fontDirectory().path, drop.fileName)).exists(),
      isFalse,
    );
  });

  test(
    'entries whose files vanished and corrupt manifests are skipped',
    () async {
      final font = await storage.importFont(
        await writeSource(
          'gone.ttf',
          buildTestFont(
            names: <TestFontName>[
              (
                platform: 3,
                encoding: 1,
                language: 0x0409,
                nameId: 1,
                value: 'G',
              ),
            ],
          ),
        ),
        languageCode: 'en',
      );
      await File(p.join(fontDirectory().path, font.fileName)).delete();

      expect(await storage.listFonts(), isEmpty);

      await File(
        p.join(fontDirectory().path, 'fonts.json'),
      ).writeAsString('{broken');
      expect(await storage.listFonts(), isEmpty);
    },
  );

  test('registers an imported font with the engine once', () async {
    final source = await writeSource(
      'HarmonyCopy.ttf',
      await File(bundledFontPath).readAsBytes(),
    );
    final font = await storage.importFont(source, languageCode: 'en');

    final family = await storage.loadFontFamily(font);

    expect(family, DiaryFontStorageService.familyFor(font.id));
    expect(storage.loadFontFamily(font), completion(family));
  });

  test('loading a font whose file is gone fails and can be retried', () async {
    const font = DiaryImportedFont(
      id: 'fmissing',
      name: 'Missing',
      fileName: 'fmissing.ttf',
    );

    await expectLater(storage.loadFontFamily(font), throwsA(anything));

    final source = await writeSource(
      'again.ttf',
      await File(bundledFontPath).readAsBytes(),
    );
    await fontDirectory().create(recursive: true);
    await File(source).copy(p.join(fontDirectory().path, font.fileName));
    expect(
      await storage.loadFontFamily(font),
      DiaryFontStorageService.familyFor(font.id),
    );
  });
}
