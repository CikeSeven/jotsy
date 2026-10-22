import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_codec.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_media.dart';
import 'package:node_diary/core/database/diary_blocks/diary_blocks_walk.dart';
import 'package:node_diary/l10n/app_localizations_gen.dart';
import 'package:node_diary/ui/diaries/models/style_library/style_code.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_blocks.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_code.dart';
import 'package:node_diary/ui/diary_templates/models/diary_template_json.dart';
import 'package:node_diary/ui/diary_templates/viewmodels/diary_template_application.dart';
import 'package:node_diary/ui/diary_templates/viewmodels/diary_template_variable_values.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
  final tree = {
    'document': {
      'type': 'page',
      'children': [
        {
          'type': 'quote',
          'data': {
            'delta': [
              {
                'insert': '{{日期}}',
                'attributes': {'bold': true, 'font_color': '#FF123456'},
              },
            ],
          },
          'children': [
            {
              'type': 'todo_list',
              'data': {
                'checked': true,
                'delta': [
                  {'insert': 'nested'},
                ],
              },
            },
            {'type': 'divider'},
          ],
        },
      ],
    },
  };

  test('v2 payload and code retain nested text, formatting and todo state', () {
    final template = DiaryTemplate(
      id: 'tree',
      name: 'nested',
      bodyJson: encodeDiaryTemplateBody(tree),
    );
    final payload = DiaryTemplateJson.toJson(template);
    expect(payload['v'], 2);
    expect(payload['body'], tree);
    expect(DiaryTemplateJson.fromJson(payload, id: 'tree'), template);
    final code = encodeDiaryTemplateCode(template)!;
    expect(code, startsWith('jotsy-template:v2:'));
    expect(
      diaryTemplateCodeFormat.decode(code).style,
      template.copyWith(id: ''),
    );
  });

  test('v1 codes migrate their Delta body when read and write only v2', () {
    final legacy =
        StyleCodeFormat<Map<String, Object?>>(
          scheme: 'jotsy-template',
          version: 1,
          fromJson: (raw) => Map.from(raw as Map),
          toJson: (value) => value,
        ).encode({
          'v': 1,
          'name': 'old',
          'body': [
            {'insert': 'title'},
            {
              'insert': '\n',
              'attributes': {'header': 2},
            },
            {
              'insert': 'linked',
              'attributes': {'link': 'https://example.com', 'strike': true},
            },
            {'insert': '\n'},
          ],
        });
    final decoded = diaryTemplateCodeFormat.decode(legacy);
    expect(decoded.status, StyleCodeStatus.ok);
    final document =
        jsonDecode(decoded.style!.bodyJson) as Map<String, dynamic>;
    expect(document['document']['children'][0]['type'], 'heading');
    expect(
      document['document']['children'][1]['data']['delta'][0]['attributes'],
      {'href': 'https://example.com', 'strikethrough': true},
    );
    expect(
      encodeDiaryTemplateCode(decoded.style!),
      startsWith('jotsy-template:v2:'),
    );
  });

  test(
    'nested media, unknown metadata and private links never enter a template',
    () {
      final dirty = {
        'document': {
          'type': 'page',
          'children': [
            {
              'type': 'paragraph',
              'data': {
                'path': '/private/a',
                'custom': {'image': '/private/b'},
                'delta': [
                  {
                    'insert': 'kept',
                    'attributes': {
                      'bold': true,
                      'href': 'file:///private/c',
                      'path': '/private/d',
                    },
                  },
                ],
              },
              'children': [
                {
                  'type': 'image',
                  'data': {'url': '/private/photo.png'},
                },
                {
                  'type': 'audio',
                  'data': {'path': '/private/a.m4a'},
                },
                {
                  'type': 'attachment',
                  'data': {'path': '/private/a.pdf'},
                },
                {
                  'type': 'future',
                  'data': {'url': '/private/future'},
                  'children': [
                    {
                      'type': 'paragraph',
                      'data': {
                        'delta': [
                          {'insert': 'nested text'},
                        ],
                      },
                    },
                  ],
                },
              ],
            },
          ],
        },
      };
      final clean = sanitizeDiaryTemplateBlocks(dirty);
      expect(jsonEncode(clean), isNot(contains('/private/')));
      expect(diaryBlocksMedia(clean), isEmpty);
      expect(diaryBlocksPlainText(clean), 'kept\nnested text');
      expect(walkDiaryBlocks(clean).map((entry) => entry.$2), [0, 1]);
      expect(sanitizeDiaryTemplateBlocks(clean), clean);
    },
  );

  test('variables resolve inside child nodes without flattening the body', () {
    final template = DiaryTemplate(
      id: 'tree',
      name: 'nested',
      bodyJson: encodeDiaryTemplateBody(tree),
    );
    final values = DiaryTemplateVariableValues.compute(
      l10n: lookupAppLocalizations(const Locale('en')),
      diaryDate: DateTime(2026, 10, 22),
      now: DateTime(2026, 10, 22),
    );
    final applied = DiaryTemplateApplication.resolve(template, values);
    expect(jsonEncode(applied.document), isNot(contains('{{')));
    expect(walkDiaryBlocks(applied.document).map((entry) => entry.$2), [
      0,
      1,
      1,
    ]);
    expect(
      diaryBlockData(walkDiaryBlocks(applied.document).first.$1)['delta'],
      isNotEmpty,
    );
  });
}
