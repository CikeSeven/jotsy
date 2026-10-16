import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/font_file_info.dart';

import '../../support/font_file_fixtures.dart';

void main() {
  test('reads Chinese and English family names from a TrueType font', () {
    final info = readFontFileInfo(
      buildTestFont(
        names: <TestFontName>[
          (platform: 3, encoding: 1, language: 0x0409, nameId: 1, value: 'Wen'),
          (
            platform: 3,
            encoding: 1,
            language: 0x0409,
            nameId: 16,
            value: 'LXGW WenKai',
          ),
          (platform: 3, encoding: 1, language: 0x0404, nameId: 1, value: '霞鶩'),
          (
            platform: 3,
            encoding: 1,
            language: 0x0804,
            nameId: 1,
            value: '霞鹜文楷',
          ),
        ],
      ),
    );

    expect(info, isNotNull);
    expect(info!.format, FontFileFormat.trueType);
    expect(info.fileExtension, 'ttf');
    // 排版字族名（nameID 16）优先；简体中文优先于繁体中文。
    expect(info.familyNameFor('en'), 'LXGW WenKai');
    expect(info.familyNameFor('zh'), '霞鹜文楷');
  });

  test('falls back to Mac Roman names and to any available language', () {
    final info = readFontFileInfo(
      buildTestFont(
        version: 0x4F54544F,
        names: <TestFontName>[
          (platform: 1, encoding: 0, language: 0, nameId: 1, value: 'Mac Sans'),
        ],
      ),
    );

    expect(info!.format, FontFileFormat.openType);
    expect(info.familyNameFor('zh'), 'Mac Sans');
  });

  test('reads the first face of a font collection', () {
    final info = readFontFileInfo(
      buildTestFont(
        collection: true,
        names: <TestFontName>[
          (platform: 0, encoding: 3, language: 0, nameId: 1, value: 'Noto'),
        ],
      ),
    );

    expect(info!.format, FontFileFormat.collection);
    expect(info.fileExtension, 'ttc');
    expect(info.familyNameFor('en'), 'Noto');
  });

  test('a font without a name table is still accepted', () {
    final info = readFontFileInfo(buildTestFont(includeNameTable: false));

    expect(info, isNotNull);
    expect(info!.familyNameFor('zh'), isNull);
  });

  test('rejects files that are not sfnt fonts or are truncated', () {
    expect(readFontFileInfo(Uint8List(0)), isNull);
    expect(
      readFontFileInfo(utf8.encode('wOFF0000 compressed web font')),
      isNull,
    );
    expect(
      readFontFileInfo(utf8.encode('just some text that is long')),
      isNull,
    );
    final font = buildTestFont(
      names: <TestFontName>[
        (platform: 3, encoding: 1, language: 0x0409, nameId: 1, value: 'Cut'),
      ],
    );
    expect(readFontFileInfo(Uint8List.sublistView(font, 0, 40)), isNull);
  });

  test('reads the bundled HarmonyOS Sans font', () async {
    final bytes = await File(
      'assets/fonts/harmonyos_sans_sc/HarmonyOS_Sans_SC_Regular.ttf',
    ).readAsBytes();

    final info = readFontFileInfo(bytes);

    expect(info, isNotNull);
    expect(info!.familyNameFor('en'), contains('HarmonyOS'));
  });
}
