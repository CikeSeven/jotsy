import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_block_writer.dart';
import 'package:node_diary/core/services/journal_import_cloud.dart';
import 'package:node_diary/core/services/journal_import_cloud_http.dart';
import 'package:node_diary/core/services/journal_import_cloud_smartisan.dart';
import 'package:node_diary/core/services/journal_import_media.dart';
import 'package:node_diary/core/services/journal_import_models.dart';

import '../../support/diary_content_test_helpers.dart';
import '../../support/fake_cloud_http.dart';

const _api = 'yun.smartisan.com/apps/note/index.php';
const _images = 'yun.smartisan.com/apps/note/notesimage';

Matcher _failure(CloudNoteFailure failure) => isA<CloudNoteException>().having(
  (error) => error.failure,
  'failure',
  failure,
);

/// 按 `r=` 动作分发的假接口：v2/getList 按页码取 [pages]。
void _serve(
  FakeCloudHttp http, {
  Object? account = const {'uid': 1000001, 'nickname': '锤子'},
  Object? folders = const [],
  List<Map<String, Object?>> pages = const [],
}) {
  http.on('GET', _api, (request) {
    final query = request.url.queryParameters;
    return switch (query['r']) {
      'account/login' => jsonResponse({'code': 0, 'data': account}),
      'folder/getList' => jsonResponse({'code': 0, 'data': folders}),
      'v2/getList' => jsonResponse({
        'code': 0,
        'data': pages[int.parse(query['page']!) - 1],
      }),
      _ => jsonResponse({
        'code': 1,
        'errInfo': {'404': 'unknown'},
      }),
    };
  });
}

Map<String, Object?> _note(
  String id, {
  String detail = '正文',
  Object? folderId = '0',
  Object? folderType = 0,
  Object? modified = 1700000000000,
  Object? markdown = 0,
  Object? locked = 0,
}) => {
  'uid': 1000001,
  'sync_id': id,
  'seqid': '1106367541401362432',
  'folderId': folderId,
  'favorite': 0,
  'markdown': markdown,
  'pos': 1,
  'modify_time': modified,
  // 服务端按正文第一行生成的标题，不应作为日记标题导入。
  'title': '服务端生成的标题',
  'detail': detail,
  'folder_type': folderType,
  'formatting_mode': 0,
  'is_locked': locked,
};

/// 写出正文，返回纯文本镜像与块属性（附件换成 `{'image': 文件名}`）。
({String text, List<Map<String, Object?>> ops}) _write(
  String detail, {
  bool markdown = false,
  Set<String> missing = const {},
}) {
  final writer = JournalBlockWriter();
  writeSmartisanBody(
    writer,
    detail,
    (name) => missing.contains(name) ? null : {'image': name},
    markdown: markdown,
  );
  final content = writer.build();
  return (
    text: content.contentText,
    ops: diaryContentQuillOps(content.contentJson),
  );
}

List<Object?> _images0(List<Map<String, Object?>> ops) => [
  for (final op in ops)
    if (op['insert'] case final Map embed) embed['image'],
];

/// 正文逐行：图片写作 `[图]`。
List<String> _lines(List<Map<String, Object?>> ops) {
  final lines = <String>[];
  final current = StringBuffer();
  for (final op in ops) {
    switch (op['insert']) {
      case final String text:
        final parts = text.split('\n');
        for (var i = 0; i < parts.length; i++) {
          if (i > 0) {
            lines.add('$current');
            current.clear();
          }
          current.write(parts[i]);
        }
      case Map():
        current.write('[图]');
    }
  }
  if (current.isNotEmpty) lines.add('$current');
  return lines;
}

void main() {
  group('writeSmartisanBody', () {
    test('keeps single line breaks and blank lines of plain notes', () {
      final result = _write('第一行。\n第二行，紧挨着上一行。\n\n这是新的一段。');
      expect(result.text, '第一行。\n第二行，紧挨着上一行。\n\n这是新的一段。');
    });

    test('plain notes keep Markdown markers as literal text', () {
      final result = _write('**这里的星号是纯文本，不是 Markdown 加粗。**\n# 不是标题');
      expect(result.text, '**这里的星号是纯文本，不是 Markdown 加粗。**\n# 不是标题');
      expect(result.ops.where((op) => op['attributes'] != null), isEmpty);
    });

    test('Markdown notes are converted', () {
      final result = _write('# 标题\n**加粗**\n- 列表', markdown: true);
      expect(result.text, '标题\n加粗\n列表');
      Map? attributesOf(String text) =>
          result.ops.firstWhere((op) => op['insert'] == text)['attributes']
              as Map?;
      expect(attributesOf('加粗'), {'bold': true});
      final blocks = result.ops
          .where((op) => op['insert'] == '\n' && op['attributes'] != null)
          .map((op) => op['attributes'])
          .toList();
      expect(blocks, [
        {'header': 1},
        {'list': 'bullet'},
      ]);
    });

    test('image tags become embeds on their own lines', () {
      final result = _write(
        '开头\n'
        '<image w=95 h=53 describe= name=Notes_1552613545131.jpeg>\n'
        '中间<image w=720 h=3099 describe=一张 有空格的说明 name=0123456789abcdef0123>后面\n'
        '\n'
        '<image w=1 h=1 describe= name=a.png><image w=1 h=1 describe= name=b.png>',
      );
      expect(_images0(result.ops), [
        'Notes_1552613545131.jpeg',
        '0123456789abcdef0123',
        'a.png',
        'b.png',
      ]);
      // 图片独占一行，不多出空行；便签里原有的空行保留。
      expect(_lines(result.ops), [
        '开头',
        '[图]',
        '中间',
        '[图]',
        '后面',
        '',
        '[图]',
        '[图]',
      ]);
    });

    test('image placeholders in Markdown notes resolve by position', () {
      final result = _write(
        '**图**<image w=1 h=1 describe= name=Notes_1.jpeg>\n'
        '![](https://example.com/remote.png)',
        markdown: true,
      );
      expect(_images0(result.ops), [
        'Notes_1.jpeg',
        'https://example.com/remote.png',
      ]);
    });

    test('images that failed to download are dropped', () {
      final result = _write(
        '前<image w=1 h=1 describe= name=gone.jpg>后',
        missing: {'gone.jpg'},
      );
      expect(_images0(result.ops), isEmpty);
      expect(_lines(result.ops), ['前', '后']);
    });
  });

  test('smartisanImageNames lists each referenced file once', () {
    expect(
      smartisanImageNames(
        '<image w=1 h=2 describe= name=Notes_1.jpeg>'
        '<image w=1 h=2 describe=说明 name=Notes_1.jpeg>'
        '<image w=3 h=4 describe= name=abcdef0123456789>',
      ),
      ['Notes_1.jpeg', 'abcdef0123456789'],
    );
  });

  test('decodeSmartisanFolders accepts the known list shapes', () {
    const rows = [
      {'sync_id': 'f1', 'title': '日记'},
      {'sync_id': 'f2', 'title': ' '},
      {'title': '没有 ID'},
    ];
    for (final data in <Object?>[
      rows,
      {'noteFolder': rows},
      {'list': rows},
    ]) {
      expect(decodeSmartisanFolders(data), {'f1': '日记'}, reason: '$data');
    }
    expect(decodeSmartisanFolders(null), isEmpty);
    expect(
      () => decodeSmartisanFolders({'folders': rows}),
      throwsA(_failure(CloudNoteFailure.protocolChanged)),
    );
  });

  group('SmartisanCloudProvider', () {
    late FakeCloudHttp http;
    late SmartisanCloudProvider provider;

    setUp(() {
      http = FakeCloudHttp();
      provider = SmartisanCloudProvider(http, wait: (_) async {});
    });

    test('probe checks the login state', () async {
      _serve(http);
      expect(await provider.probe(), 'smartisan:1000001');
      final request = http.requests.single;
      expect(request.url.queryParameters, {'r': 'account/login'});
      expect(request.headers['X-Requested-With'], 'XMLHttpRequest');

      for (final body in <Object?>[
        {'code': 1701, 'data': null},
        {
          'code': 1,
          'errInfo': {'1701': '未登录'},
        },
        {'code': 0, 'data': null},
        {'code': 0, 'data': <String, Object?>{}},
      ]) {
        http.json('GET', _api, body);
        await expectLater(
          provider.probe(),
          throwsA(_failure(CloudNoteFailure.sessionExpired)),
          reason: '$body',
        );
      }
    });

    test('reads every page and maps folders, trash and locked notes', () async {
      _serve(
        http,
        folders: const {
          'noteFolder': [
            {'uid': 1, 'sync_id': 'diary', 'title': '日记', 'position': 1},
          ],
        },
        pages: [
          {
            'note': {
              'page_count': 2,
              'total': 7,
              'list': [
                _note(
                  'a',
                  detail: '在日记分类里',
                  folderId: 'diary',
                  modified: 1552613545131,
                ),
                _note('b', detail: '未分类'),
                _note('c', detail: '回收站里的', folderType: 3),
                _note('d', detail: '', locked: 1),
              ],
            },
          },
          {
            'note': {
              'page_count': '2',
              'total': 7,
              'list': [
                // 分页边界重复的条目只导入一次。
                _note('b', detail: '未分类'),
                _note('e', detail: '分类已删除', folderId: 'gone'),
                _note('f', modified: null),
                _note('g', detail: '**加粗**', markdown: '1', locked: 1),
              ],
            },
          },
        ],
      );

      final progress = <(int, int?)>[];
      final notes = await provider.fetchNotes(
        (done, total) => progress.add((done, total)),
      );

      expect(notes.map((note) => note.id), ['a', 'b', 'e', 'g']);
      expect(provider.issues.skipped, {
        JournalSkipReason.encrypted: 1,
        JournalSkipReason.unreadable: 1,
      });
      expect(progress, [(4, 7), (8, null)]);
      final [a, b, e, g] = notes;
      expect(a.title, isEmpty);
      expect(a.folder, '日记');
      expect(a.createdAt, DateTime.fromMillisecondsSinceEpoch(1552613545131));
      expect(a.updatedAt, a.createdAt);
      expect(b.folder, isNull);
      expect(e.folder, isNull);
      final writer = JournalBlockWriter();
      g.writeBody(writer, (_) => null);
      final ops = diaryContentQuillOps(writer.build().contentJson);
      expect(ops.first, {
        'insert': '加粗',
        'attributes': {'bold': true},
      });
      final pages = http.requests
          .where((request) => request.url.queryParameters['r'] == 'v2/getList')
          .map((request) => request.url.queryParameters)
          .toList();
      expect(pages, [
        {'r': 'v2/getList', 'page': '1', 'page_size': '3000'},
        {'r': 'v2/getList', 'page': '2', 'page_size': '3000'},
      ]);
    });

    test('an unknown list shape stops the import', () async {
      _serve(
        http,
        pages: [
          {'list': <Object?>[]},
        ],
      );
      await expectLater(
        provider.fetchNotes((_, _) {}),
        throwsA(_failure(CloudNoteFailure.protocolChanged)),
      );
    });

    test('a note without sync_id stops the import', () async {
      _serve(
        http,
        pages: [
          {
            'note': {
              'page_count': 1,
              'list': [
                {'detail': '没有 ID', 'modify_time': 1700000000000},
              ],
            },
          },
        ],
      );
      await expectLater(
        provider.fetchNotes((_, _) {}),
        throwsA(_failure(CloudNoteFailure.protocolChanged)),
      );
    });

    test('a page count that changes while paging stops the import', () async {
      _serve(
        http,
        pages: [
          {
            'note': {
              'page_count': 2,
              'list': [_note('a')],
            },
          },
          {
            'note': {
              'page_count': 3,
              'list': [_note('b')],
            },
          },
        ],
      );
      await expectLater(
        provider.fetchNotes((_, _) {}),
        throwsA(_failure(CloudNoteFailure.protocolChanged)),
      );
    });

    test('downloads images and rejects error bodies', () async {
      http.on('GET', '$_images/Notes_1.jpeg', (_) {
        return CloudNoteResponse(
          200,
          fakeJpeg,
          headers: const {'content-type': 'image/jpeg'},
        );
      });
      expect(
        await provider.download(
          const CloudAttachment(id: 'Notes_1.jpeg', name: 'Notes_1.jpeg'),
        ),
        fakeJpeg,
      );

      // 文件名整体作为一个路径段，不能借 ../ 走出图片目录。
      await expectLater(
        provider.download(
          const CloudAttachment(id: '../index.php', name: '../index.php'),
        ),
        throwsA(_failure(CloudNoteFailure.rejected)),
      );
      expect(
        http.requests.last.url.path,
        '/apps/note/notesimage/..%2Findex.php',
      );

      http.on(
        'GET',
        '$_images/expired.jpeg',
        (_) => CloudNoteResponse(
          200,
          utf8.encode(jsonEncode({'code': 1701, 'data': null})),
          headers: const {'content-type': 'application/json'},
        ),
      );
      await expectLater(
        provider.download(
          const CloudAttachment(id: 'expired.jpeg', name: 'expired.jpeg'),
        ),
        throwsA(_failure(CloudNoteFailure.sessionExpired)),
      );

      http.on(
        'GET',
        '$_images/missing.jpeg',
        (_) => CloudNoteResponse(
          200,
          utf8.encode('<html></html>'),
          headers: const {'content-type': 'text/html; charset=utf-8'},
        ),
      );
      await expectLater(
        provider.download(
          const CloudAttachment(id: 'missing.jpeg', name: 'missing.jpeg'),
        ),
        throwsA(_failure(CloudNoteFailure.rejected)),
      );
    });

    test(
      'imports through fetchCloudJournal with the images in place',
      () async {
        final temp = await Directory.systemTemp.createTemp('smartisan_');
        addTearDown(() => temp.delete(recursive: true));
        _serve(
          http,
          folders: const [
            {'sync_id': 'diary', 'title': '日记'},
          ],
          pages: [
            {
              'note': {
                'page_count': 1,
                'list': [
                  _note(
                    'a',
                    folderId: 'diary',
                    detail:
                        '今天 😀\n<image w=1 h=1 describe= name=Notes_1.jpeg>\n'
                        '<image w=1 h=1 describe= name=gone.jpeg>结尾',
                  ),
                ],
              },
            },
          ],
        );
        http.on(
          'GET',
          '$_images/Notes_1.jpeg',
          (_) => CloudNoteResponse(
            200,
            fakeJpeg,
            headers: const {'content-type': 'image/jpeg'},
          ),
        );
        http.on(
          'GET',
          '$_images/gone.jpeg',
          (_) => jsonResponse({
            'code': 1,
            'errInfo': {'404': 'not found'},
          }),
        );

        final result = await fetchCloudJournal(
          provider,
          JournalMediaStager(temp.path),
        );

        final entry = result.entries.single;
        expect(entry.sourceKey, 'a');
        expect(entry.title, isEmpty);
        expect(entry.notebooks, ['日记']);
        expect(_lines(diaryContentQuillOps(entry.contentJson)), [
          '今天 😀',
          '[图]',
          '结尾',
        ]);
        expect(result.missingMediaCount, 1);
        final images = [
          for (final op in diaryContentQuillOps(entry.contentJson))
            if (op['insert'] case final Map embed) embed['image'],
        ];
        expect(images, hasLength(1));
        expect(images.single, isA<String>());
      },
    );
  });
}
