import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_cloud.dart';
import 'package:node_diary/core/services/journal_import_cloud_blocks.dart';
import 'package:node_diary/core/services/journal_import_cloud_http.dart';
import 'package:node_diary/core/services/journal_import_cloud_xiaomi.dart';
import 'package:node_diary/core/services/journal_import_cloud_xiaomi_markup.dart';

import '../../support/fake_cloud_http.dart';

/// 块的简写：`kind[:属性]:文字`，便于对照参考实现测试中的期望。
String _describe(CloudBlock block) {
  final flags = [
    if (block.kind == CloudBlockKind.heading) 'h${block.level}',
    if (block.kind == CloudBlockKind.list) block.ordered ? 'ol' : 'ul',
    if (block.kind == CloudBlockKind.list || block.kind == CloudBlockKind.todo)
      'l${block.level}',
    if (block.kind == CloudBlockKind.todo) block.checked ? 'x' : ' ',
    if (block.attachmentId case final id?) id,
  ];
  final spans = block.spans
      .map((span) {
        final marks = [
          if (span.bold) 'b',
          if (span.italic) 'i',
          if (span.underline) 'u',
          if (span.strike) 's',
          if (span.highlight) 'hl',
          if (span.link case final link?) 'a=$link',
        ];
        return marks.isEmpty ? span.text : '${span.text}{${marks.join(',')}}';
      })
      .join('|');
  return [block.kind.name, ...flags, spans].join(':');
}

List<String> _parse(String content) =>
    parseXiaomiMarkup(content).blocks.map(_describe).toList();

void main() {
  // 向量取自参考实现 tests/test_xiaomi_markup.py 与 test_xiaomi_contract.py。
  group('parseXiaomiMarkup', () {
    test('headings, paragraphs and inline marks', () {
      expect(
        _parse('<new-format/><h2/><b>Heading</b>\nbody\n<h3/>subheading\nend'),
        [
          'heading:h2:Heading{b}',
          'paragraph:body',
          'heading:h3:subheading',
          'paragraph:end',
        ],
      );
      expect(
        _parse(
          '<background color="#9affe8af"><delete><u><i><b>原生样式</b></i></u>'
          '</delete></background>',
        ),
        ['paragraph:原生样式{b,i,u,s,hl}'],
      );
    });

    test('ordered, bullet and legacy nested lists', () {
      expect(
        _parse(
          '<order indent="1" inputNumber="1"/>first\n'
          '<order indent="2" inputNumber="1"/><i>nested</i>\n'
          '<bullet indent="3"/>bullet',
        ),
        ['list:ol:l1:first', 'list:ol:l2:nested{i}', 'list:ul:l3:bullet'],
      );
      expect(_parse('<ol><li>first<ul><li>nested</li></ul></li></ol>\nafter'), [
        'list:ol:l1:first',
        'list:ul:l2:nested',
        'paragraph:after',
      ]);
    });

    test('quotes, dividers and literal list characters', () {
      expect(
        _parse(
          'before\n<quote><text indent="1"><b>quote</b></text></quote>\n<hr/>\nafter',
        ),
        ['paragraph:before', 'quote:quote{b}', 'divider:', 'paragraph:after'],
      );
      expect(_parse('☑ literal\n• literal\n<del>old completed task</del>'), [
        'paragraph:☑ literal',
        'paragraph:• literal',
        'todo:l1:x:old completed task',
      ]);
    });

    test('checkboxes count as done only with checked="true"', () {
      expect(
        _parse(
          '<input type="checkbox"/><b>第一项</b>\n'
          '<input type="checkbox" checked="true"/><i>第二项</i>\n<bullet/>第三项',
        ),
        ['todo:l1: :第一项{b}', 'todo:l1:x:第二项{i}', 'list:ul:l1:第三项'],
      );
      for (final (attribute, done) in [
        ('', false),
        (' checked', false),
        (' checked="checked"', false),
        (' checked="false"', false),
        (' checked="True"', false),
        (' checked="true"', true),
      ]) {
        final block = parseXiaomiMarkup(
          '<input type="checkbox"$attribute/>item',
        ).blocks.single;
        expect(block.checked, done, reason: attribute);
      }
    });

    test('drops active content, keeps br inline and moves links out', () {
      expect(
        _parse('<script>bad()<script>nested()</script></script><b>safe</b>'),
        ['paragraph:safe{b}'],
      );
      expect(_parse('one<br/>two'), ['paragraph:onetwo']);
      expect(
        _parse(
          '<b>before</b><a href="https://example.com/"><i>title</i></a>after',
        ),
        [
          'paragraph:before{b}|after',
          'paragraph:title{a=https://example.com/}',
        ],
      );
      expect(_parse('<strong>text</strong>'), ['paragraph:text']);
    });

    test('a newline after media is only a separator', () {
      for (final (gap, empties) in [('\n', 0), ('\n\n', 1), ('\n\n\n', 2)]) {
        final blocks = _parse(
          '<b>before</b>\n<img fileid="image"/>$gap<i>after</i>',
        );
        expect(
          blocks.where((block) => block == 'paragraph:'),
          hasLength(empties),
        );
        expect(blocks.first, 'paragraph:before{b}');
        expect(blocks.last, 'paragraph:after{i}');
      }
      final media = parseXiaomiMarkup(
        '<img fileid="a"/>\n<sound fileid="b"/>',
      ).media;
      expect(media, [(id: 'a', audio: false), (id: 'b', audio: true)]);
    });

    test('decodes entities and keeps emoji', () {
      expect(_parse('&lt;不是标签&gt; &amp; 😀'), ['paragraph:<不是标签> & 😀']);
    });
  });

  group('XiaomiCloudProvider', () {
    late FakeCloudHttp http;
    late XiaomiCloudProvider provider;

    setUp(() {
      http = FakeCloudHttp(cookies: {'userId': 'synthetic-user'});
      provider = XiaomiCloudProvider(http, wait: (_) async {});
    });

    test('probe needs the userId cookie and a readable first page', () async {
      http.json('GET', 'i.mi.com/note/full/page', {
        'code': 0,
        'data': {'entries': [], 'folders': [], 'lastPage': true},
      });
      expect(await provider.probe(), 'xiaomi:synthetic-user');

      final anonymous = XiaomiCloudProvider(FakeCloudHttp());
      await expectLater(
        anonymous.probe(),
        throwsA(
          isA<CloudNoteException>().having(
            (error) => error.failure,
            'failure',
            CloudNoteFailure.sessionExpired,
          ),
        ),
      );
    });

    test('pages, reads details, maps folders, titles and media', () async {
      http.on('GET', 'i.mi.com/note/full/page', (request) {
        final cursor = request.url.queryParameters['syncTag'];
        expect(request.url.queryParameters['limit'], '200');
        return jsonResponse({
          'code': 0,
          'data': cursor == null
              ? {
                  'entries': [
                    {'id': 'fixture-detail', 'status': 'normal'},
                    {'id': 'trashed', 'status': 'deleted'},
                    {'id': 'f1', 'type': 'folder'},
                  ],
                  'folders': [
                    {'id': 'group', 'subject': '工作', 'status': 'normal'},
                    {'id': 'old', 'subject': '已删', 'status': 'deleted'},
                  ],
                  'lastPage': false,
                  'syncTag': 'next',
                }
              : {
                  'entries': [
                    {'id': 12, 'status': 'normal', 'folderId': 0},
                  ],
                  'lastPage': true,
                },
        });
      });
      http.json('GET', 'i.mi.com/note/note/fixture-detail/', {
        'code': 0,
        'data': {
          'entry': {
            'id': 'fixture-detail',
            'status': 'normal',
            'createDate': 1720000000000,
            'modifyDate': 1720000001000,
            'folderId': 'group',
            'extraInfo': '{"title":"标题"}',
            'setting': {
              'data': [
                {
                  'fileId': 'image1',
                  'mimeType': 'image/png',
                  'fileName': '图.png',
                },
                {'fileId': 'image2', 'mimeType': 'image/jpeg'},
              ],
            },
            'content':
                '<new-format/><h2/><b>Heading</b>\n'
                '<input type="checkbox" indent="1" level="-1" checked="true"/>完成\n'
                '<img fileid="image1"/>\n<sound fileid="audio1"/>',
          },
        },
      });
      http.json('GET', 'i.mi.com/note/note/12/', {
        'code': 0,
        'data': {
          'entry': {
            'id': 12,
            'createDate': 1720000000000,
            'folderId': 0,
            'encryptInfo': {'version': 1},
            'content': 'secret',
          },
        },
      });
      final progress = <(int, int?)>[];

      final notes = await provider.fetchNotes((done, total) {
        progress.add((done, total));
      });

      final note = notes.single;
      expect(note.id, 'fixture-detail');
      expect(note.title, '标题');
      expect(note.folder, '工作');
      expect(note.createdAt, DateTime.utc(2024, 7, 3, 9, 46, 40).toLocal());
      expect(note.updatedAt, DateTime.utc(2024, 7, 3, 9, 46, 41).toLocal());
      expect(note.attachments.map((item) => (item.id, item.name)), [
        ('image1', '图.png'),
        ('image2', 'image2.jpg'),
        ('audio1', 'audio1'),
      ]);
      expect(http.requests.last.url.queryParameters, isEmpty);
      expect(progress, [(1, null), (2, null), (1, 2), (2, 2)]);
    });

    test('an account where every note is encrypted is reported', () async {
      http.json('GET', 'i.mi.com/note/full/page', {
        'code': 0,
        'data': {
          'entries': [
            {'id': 'e', 'status': 'normal'},
          ],
          'lastPage': true,
        },
      });
      http.json('GET', 'i.mi.com/note/note/e/', {
        'code': 0,
        'data': {
          'entry': {
            'id': 'e',
            'createDate': 1,
            'encryptInfo': 'x',
            'content': '',
          },
        },
      });
      await expectLater(
        provider.fetchNotes((_, _) {}),
        throwsA(
          isA<CloudNoteException>().having(
            (error) => error.failure,
            'failure',
            CloudNoteFailure.unsupportedAccount,
          ),
        ),
      );
    });

    test('stops when the cursor stalls', () async {
      http.json('GET', 'i.mi.com/note/full/page', {
        'code': 0,
        'data': {'entries': [], 'lastPage': false},
      });
      await expectLater(
        provider.fetchNotes((_, _) {}),
        throwsA(isA<CloudNoteException>()),
      );
    });

    test('downloads through the signed redirect without cookies', () async {
      http.on(
        'GET',
        'i.mi.com/file/full',
        (_) => CloudNoteResponse(
          302,
          const [],
          headers: const {
            'location': 'https://ali.xmssdn.micloud.mi.com/file?signature=s',
          },
        ),
      );
      http.on(
        'GET',
        'ali.xmssdn.micloud.mi.com/file',
        (_) => CloudNoteResponse(
          200,
          fakeJpeg,
          headers: const {'content-type': 'image/jpeg'},
        ),
      );

      final bytes = await provider.download(
        const CloudAttachment(id: 'image1', name: 'a.jpg'),
      );

      expect(bytes, fakeJpeg);
      final [first, second] = http.requests;
      expect(first.url.queryParameters, {
        'type': 'note_img',
        'fileid': 'image1',
      });
      expect(first.withCookies, isTrue);
      expect(second.url.queryParameters, {'signature': 's'});
      expect(second.withCookies, isFalse);
    });

    test('rejects redirects that leave the file service', () async {
      for (final location in [
        'https://evil.invalid/file',
        'https://account.xiaomi.com/login',
        'http://ali.xmssdn.micloud.mi.com/x',
        'https://ali.xmssdn.micloud.mi.com:8443/x',
        'https://ali.xmssdn.micloud.mi.com/x#f',
      ]) {
        http.on(
          'GET',
          'i.mi.com/file/full',
          (_) =>
              CloudNoteResponse(302, const [], headers: {'location': location}),
        );
        await expectLater(
          provider.download(const CloudAttachment(id: 'x', name: 'x')),
          throwsA(isA<CloudNoteException>()),
          reason: location,
        );
      }
      expect(
        http.requests.every((request) => request.url.host == 'i.mi.com'),
        isTrue,
      );
    });
  });
}
