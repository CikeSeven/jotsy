import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_cloud.dart';
import 'package:node_diary/core/services/journal_import_cloud_http.dart';
import 'package:node_diary/core/services/journal_import_cloud_meizu.dart';
import 'package:node_diary/core/services/journal_import_delta_writer.dart';

import '../../support/fake_cloud_http.dart';

const _api = 'notes.flyme.cn/c/browser/note';

/// 夹具：标题、含 emoji 的多种行内样式、待办、嵌套列表、图片、对齐。
final String _body = jsonEncode([
  {'state': 60, 'level': 1, 'text': '周末计划'},
  {
    'state': 0,
    'text': '😀加粗斜体 删除 高亮 链接',
    'span': jsonEncode([
      {'span': 1, 'param': 1, 'start': 2, 'end': 4},
      {'span': 7, 'param': 2, 'start': 4, 'end': 6},
      {'span': 6, 'param': '', 'start': 2, 'end': 6},
      {'span': 18, 'param': '', 'start': 7, 'end': 9},
      {'span': 19, 'param': '', 'start': 10, 'end': 12},
      {'span': 17, 'param': 'https://example.com/a', 'start': 13, 'end': 15},
    ]),
  },
  {'state': 2, 'text': '已完成'},
  {'state': 1, 'text': '未完成'},
  {
    'state': 50,
    'children': [
      {
        'state': 53,
        'children': [
          {'state': 0, 'text': '第一项'},
          {
            'state': 51,
            'children': [
              {
                'state': 53,
                'children': [
                  {'state': 0, 'text': '子项'},
                ],
              },
            ],
          },
        ],
      },
    ],
  },
  {'state': 3, 'name': 'a1b2c3d4.png'},
  {
    'state': 0,
    'text': '居中',
    'span': jsonEncode([
      {'span': 1, 'param': 2, 'start': 0, 'end': 2},
    ]),
  },
]);

String _spans(List<Object?> spans) => spans
    .cast<dynamic>()
    .map((span) {
      final marks = [
        if (span.bold) 'b',
        if (span.italic) 'i',
        if (span.underline) 'u',
        if (span.strike) 's',
        if (span.highlight) 'hl',
        if (span.link != null) 'a',
      ];
      return '${span.text}${marks.isEmpty ? '' : '{${marks.join(',')}}'}';
    })
    .join('|');

void main() {
  group('decodeMeizuSpans', () {
    test('splits on UTF-16 ranges and combines overlapping styles', () {
      expect(
        _spans(
          decodeMeizuSpans(
            '😀标题',
            jsonEncode([
              {'span': 1, 'param': 1, 'start': 2, 'end': 4},
              {'span': 7, 'param': 2, 'start': 3, 'end': 4},
            ]),
          ),
        ),
        '😀|标{b}|题{b,i}',
      );
    });

    test('rejects ranges that split a surrogate pair', () {
      expect(
        () =>
            decodeMeizuSpans('😀', '[{"span":1,"param":1,"start":1,"end":2}]'),
        throwsFormatException,
      );
    });
  });

  group('MeizuCloudProvider', () {
    late FakeCloudHttp http;
    late MeizuCloudProvider provider;

    setUp(() {
      http = FakeCloudHttp();
      provider = MeizuCloudProvider(http, wait: (_) async {});
      http.json('POST', '$_api/gettags', {
        'returnCode': 200,
        'returnValue': {
          'userId': 123,
          'data': [
            {'id': '-1', 'name': '全部'},
            {'id': 'bbbb', 'name': '工作'},
          ],
        },
      });
    });

    test('probe reads the account from gettags', () async {
      expect(await provider.probe(), 'meizu:123');
      expect(
        http.requests.single.headers['X-Requested-With'],
        'XMLHttpRequest',
      );

      http.json('POST', '$_api/gettags', {
        'returnCode': 401,
        'returnValue': null,
      });
      await expectLater(
        provider.probe(),
        throwsA(
          isA<CloudNoteException>().having(
            (error) => error.failure,
            'failure',
            CloudNoteFailure.sessionExpired,
          ),
        ),
      );
    });

    test('pages notes and converts the block tree', () async {
      http.on('POST', '$_api/getnotegroups', (request) {
        expect(request.url.queryParameters, {
          'start': '0',
          'length': '200',
          'groupUuid': '-1',
        });
        return jsonResponse({
          'returnCode': 200,
          'returnValue': {
            'count': 3,
            'content': [
              {
                'uuid': '0f1e',
                'userId': 0,
                'groupStatus': 'bbbb',
                'title': '周末计划',
                'body': _body,
                'files': {'a1b2c3d4.png': '/file/a1b2c3d4.png'},
                'createTime': 1720000000000,
                'modifyTime': 1720000001000,
                'encrypt': 0,
              },
              {
                'uuid': '1111',
                'groupStatus': '-1',
                'title': '',
                'body': '[{"state":0,"text":"无标题笔记第一行"}]',
                'createTime': 1719990000000,
              },
              {
                'uuid': '2222',
                'body': '[{"state":99,"text":"未知"}]',
                'createTime': 1719990000000,
              },
            ],
          },
        });
      });

      final notes = await provider.fetchNotes((_, _) {});

      // 含未知区块的笔记整篇跳过。
      final [first, second] = notes;
      expect(first.title, '周末计划');
      expect(first.folder, '工作');
      expect(first.attachments.single.reference, '/file/a1b2c3d4.png');
      expect(second.folder, isNull);
      final writer = JournalDeltaWriter();
      first.writeBody(writer, (id) => {'image': id});
      final content = writer.build();
      expect(
        content.contentText,
        '周末计划\n😀加粗斜体 删除 高亮 链接\n已完成\n未完成\n第一项\n子项\n\n居中',
      );
      final ops = (jsonDecode(content.contentJson) as List).cast<Map>();
      Map? attributesOf(String text) =>
          ops.firstWhere((op) => op['insert'] == text)['attributes'] as Map?;
      expect(attributesOf('加粗'), {'bold': true, 'underline': true});
      expect(attributesOf('删除'), {'strike': true});
      expect(attributesOf('链接'), {'link': 'https://example.com/a'});
      final blockAttributes = ops
          .where((op) => op['insert'] == '\n' && op['attributes'] != null)
          .map((op) => op['attributes'])
          .toList();
      expect(blockAttributes, [
        {'header': 1},
        {'list': 'checked'},
        {'list': 'unchecked'},
        {'list': 'ordered'},
        {'list': 'bullet', 'indent': 1},
      ]);
    });

    test('downloads relative file paths and rejects foreign hosts', () async {
      http.on(
        'GET',
        'notes.flyme.cn/file/a.png',
        (_) => CloudNoteResponse(
          200,
          fakeJpeg,
          headers: const {'content-type': 'image/png'},
        ),
      );
      expect(
        await provider.download(
          const CloudAttachment(id: 'a', name: 'a', reference: '/file/a.png'),
        ),
        fakeJpeg,
      );
      for (final url in [
        '//evil.com/x',
        'https://evil.com/x',
        'http://notes.flyme.cn/x',
      ]) {
        await expectLater(
          provider.download(
            CloudAttachment(id: 'a', name: 'a', reference: url),
          ),
          throwsA(isA<CloudNoteException>()),
          reason: url,
        );
      }
    });
  });
}
