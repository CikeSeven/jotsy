import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_cloud.dart';
import 'package:node_diary/core/services/journal_import_cloud_blocks.dart';
import 'package:node_diary/core/services/journal_import_cloud_cookie_jar.dart';
import 'package:node_diary/core/services/journal_import_cloud_http.dart';
import 'package:node_diary/core/services/journal_import_block_writer.dart';
import 'package:node_diary/core/services/journal_import_media.dart';
import 'package:node_diary/core/services/journal_import_models.dart';
import 'package:node_diary/core/services/journal_import_style.dart';
import 'package:path/path.dart' as p;

import '../../support/fake_cloud_http.dart';
import '../../support/diary_content_test_helpers.dart';

/// 云端读取的公共层：传输层的重试与状态映射、Cookie 罐、读取流水线与
/// 富文本块写入。
void main() {
  group('CloudNoteTransport', () {
    late FakeCloudHttp http;
    late List<Duration> waits;
    late CloudNoteTransport transport;

    setUp(() {
      http = FakeCloudHttp();
      waits = <Duration>[];
      transport = CloudNoteTransport(
        'https://api.example.com',
        http,
        headers: const {'X-Extra': '1'},
        wait: (delay) async => waits.add(delay),
      );
    });

    test('sends the desktop UA, Referer and JSON bodies', () async {
      http.json('POST', 'api.example.com/notes', {'ok': true});

      final result = await transport.json(
        'POST',
        '/notes',
        query: const {'page': '2'},
        jsonBody: const {'limit': 10},
      );

      expect(result, {'ok': true});
      final request = http.requests.single;
      expect(request.url.queryParameters, {'page': '2'});
      expect(request.headers['User-Agent'], cloudNoteUserAgent);
      expect(request.headers['Referer'], 'https://api.example.com/');
      expect(request.headers['X-Extra'], '1');
      expect(request.headers['Content-Type'], startsWith('application/json'));
      expect(request.json, {'limit': 10});
    });

    test('retries 5xx and network errors before giving up', () async {
      var calls = 0;
      http.on('GET', 'api.example.com/flaky', (_) {
        calls++;
        if (calls == 1) throw const FakeNetworkError();
        if (calls == 2) return jsonResponse({}, status: 502);
        return jsonResponse({'done': true});
      });

      expect(await transport.json('GET', '/flaky'), {'done': true});
      expect(waits, [const Duration(seconds: 1), const Duration(seconds: 2)]);

      http.on(
        'GET',
        'api.example.com/down',
        (_) => jsonResponse({}, status: 503),
      );
      await expectLater(
        transport.json('GET', '/down'),
        throwsA(_failure(CloudNoteFailure.serverError)),
      );
    });

    test('maps redirects, 401, 403, 429 and other 4xx', () async {
      http.on(
        'GET',
        'api.example.com/redirect',
        (_) => jsonResponse({}, status: 302),
      );
      http.on(
        'GET',
        'api.example.com/auth',
        (_) => jsonResponse({}, status: 401),
      );
      http.on(
        'GET',
        'api.example.com/deny',
        (_) => jsonResponse({}, status: 403),
      );
      http.on(
        'GET',
        'api.example.com/busy',
        (_) => jsonResponse({}, status: 429),
      );
      http.on(
        'GET',
        'api.example.com/bad',
        (_) => jsonResponse({}, status: 400),
      );
      http.on(
        'GET',
        'api.example.com/html',
        (_) => bytesResponse(utf8.encode('<html>')),
      );

      for (final (path, failure) in [
        ('/redirect', CloudNoteFailure.sessionExpired),
        ('/auth', CloudNoteFailure.sessionExpired),
        ('/deny', CloudNoteFailure.forbidden),
        ('/busy', CloudNoteFailure.rateLimited),
        ('/bad', CloudNoteFailure.rejected),
        ('/html', CloudNoteFailure.protocolChanged),
      ]) {
        await expectLater(
          transport.json('GET', path),
          throwsA(_failure(failure)),
          reason: path,
        );
      }
      final redirect = await transport.request(
        'GET',
        '/redirect',
        returnRedirects: true,
      );
      expect(redirect.statusCode, 302);
    });

    test('rejects paths that leave the origin', () {
      expect(
        () => transport.request('GET', '//evil.com/x'),
        throwsArgumentError,
      );
    });
  });

  group('CloudCookieJar', () {
    test('sends cookies to matching hosts and absorbs rotations', () {
      final jar = CloudCookieJar()
        ..addHeader('i.mi.com', 'serviceToken=a; userId=7')
        ..add('passToken', 'p', '.account.xiaomi.com');

      expect(
        jar.header(Uri.parse('https://i.mi.com/note')),
        'serviceToken=a; userId=7',
      );
      expect(jar.header(Uri.parse('https://x.i.mi.com/')), isNull);
      expect(
        jar.header(Uri.parse('https://sub.account.xiaomi.com/')),
        'passToken=p',
      );

      jar.absorb(Uri.parse('https://i.mi.com/status'), [
        'serviceToken=b; Path=/; HttpOnly',
        'userId=; Max-Age=0',
      ]);
      expect(jar.value('serviceToken'), 'b');
      expect(jar.value('userId'), isNull);
      expect(jar.header(Uri.parse('https://i.mi.com/')), 'serviceToken=b');
    });

    test('merges a cookie read on a host and its subdomain into one', () {
      // 荣耀的登录 Cookie 以 Domain=cloud.honor.com 下发，网页视图对接口与
      // 文件服务两个地址都会返回它；负载均衡 Cookie 只对各自主机生效。
      final jar = CloudCookieJar()
        ..addHeader('cloud.honor.com', 'hc_CSRF_Token=c1; agw=main')
        ..addHeader('fileproxy-drcn.cloud.honor.com', 'hc_CSRF_Token=c1')
        ..addHeader('fileproxy-drcn.cloud.honor.com', 'agw=file');

      expect(
        jar.header(Uri.parse('https://fileproxy-drcn.cloud.honor.com/f')),
        'hc_CSRF_Token=c1; agw=file',
      );

      jar.absorb(Uri.parse('https://cloud.honor.com/portal/x'), [
        'hc_CSRF_Token=c2; Domain=cloud.honor.com; Path=/',
      ]);
      expect(jar.value('hc_CSRF_Token'), 'c2');
      expect(
        jar.header(Uri.parse('https://fileproxy-drcn.cloud.honor.com/f')),
        'agw=file; hc_CSRF_Token=c2',
      );
      expect(
        jar.header(Uri.parse('https://cloud.honor.com/portal/x')),
        'agw=main; hc_CSRF_Token=c2',
      );
    });
  });

  group('fetchCloudJournal', () {
    late Directory temp;
    setUp(() async => temp = await Directory.systemTemp.createTemp('cloud_'));
    tearDown(() => temp.delete(recursive: true));

    test(
      'duplicate note IDs stop import before any attachment downloads',
      () async {
        final note = CloudNote(
          id: 'same',
          title: '',
          createdAt: DateTime(2024),
          writeBody: (_, _) {},
        );
        await expectLater(
          fetchCloudJournal(
            _FakeProvider([note, note]),
            JournalMediaStager(temp.path),
          ),
          throwsA(_failure(CloudNoteFailure.protocolChanged)),
        );
        expect(temp.listSync(), isEmpty);
      },
    );

    test(
      'empty files and missing attachment metadata are reported once',
      () async {
        final provider = _FakeProvider([
          CloudNote(
            id: 'one',
            title: '',
            createdAt: DateTime(2024),
            attachments: const [
              CloudAttachment(id: 'empty', name: 'empty.jpg'),
              CloudAttachment(id: 'empty', name: 'duplicate.jpg'),
            ],
            writeBody: (writer, resolve) {
              resolve('empty');
              resolve('unknown');
              resolve('unknown');
              writer.text('Retained');
            },
          ),
        ]);
        final result = await fetchCloudJournal(
          provider,
          JournalMediaStager(temp.path),
        );
        expect(result.entries.single.contentText, 'Retained');
        expect(result.missingMediaCount, 2);
        expect(temp.listSync(), isEmpty);
      },
    );

    test('a changed attachment protocol stops the import', () async {
      final provider = _FakeProvider([
        CloudNote(
          id: 'one',
          title: '',
          createdAt: DateTime(2024),
          attachments: const [
            CloudAttachment(id: 'protocol', name: 'photo.jpg'),
          ],
          writeBody: (_, _) {},
        ),
      ]);
      await expectLater(
        fetchCloudJournal(provider, JournalMediaStager(temp.path)),
        throwsA(_failure(CloudNoteFailure.protocolChanged)),
      );
    });

    test(
      'downloads media, appends unreferenced ones, counts failures',
      () async {
        final provider = _FakeProvider([
          CloudNote(
            id: 'n1',
            title: ' Trip ',
            folder: 'Travel',
            createdAt: DateTime(2024, 5, 1, 8),
            updatedAt: DateTime(2024, 5, 2),
            attachments: const [
              CloudAttachment(id: 'a', name: 'a.jpg'),
              CloudAttachment(id: 'b', name: 'b.jpg'),
              CloudAttachment(id: 'gone', name: 'gone.jpg'),
            ],
            writeBody: (writer, resolve) => writeCloudBlocks(writer, const [
              CloudBlock.paragraph([
                CloudSpan('Day '),
                CloudSpan('one', bold: true),
              ]),
              CloudBlock(CloudBlockKind.attachment, attachmentId: 'b'),
              CloudBlock(CloudBlockKind.attachment, attachmentId: 'gone'),
            ], resolve),
          ),
        ]);
        final progress = <(int, int?)>[];

        final result = await fetchCloudJournal(
          provider,
          JournalMediaStager(temp.path),
          onProgress: (done, total) => progress.add((done, total)),
        );

        final entry = result.entries.single;
        expect(entry.sourceKey, 'n1');
        expect(entry.title, 'Trip');
        expect(entry.tags, isEmpty);
        expect(entry.notebooks, ['Travel']);
        expect(entry.updatedAt, DateTime(2024, 5, 2));
        final images = [
          for (final op in diaryContentQuillOps(entry.contentJson))
            if ((op as Map)['insert'] case {'image': final String path})
              p.basename(path),
        ];
        // b 在正文中引用，a 未引用追加在末尾；gone 下载失败。
        expect(images, ['b.jpg', 'a.jpg']);
        expect(entry.contentJson, contains('"bold":true'));
        expect(result.missingMediaCount, 1);
        expect(progress.last, (1, 1));
      },
    );

    test('a lost session stops the whole read', () async {
      final provider = _FakeProvider([
        CloudNote(
          id: 'n1',
          title: '',
          createdAt: DateTime(2024),
          attachments: const [CloudAttachment(id: 'expired', name: 'x.jpg')],
          writeBody: (writer, resolve) {},
        ),
      ]);
      await expectLater(
        fetchCloudJournal(provider, JournalMediaStager(temp.path)),
        throwsA(_failure(CloudNoteFailure.sessionExpired)),
      );
    });

    test('reports skipped and summary-only notes from one read', () async {
      final provider = _FakeProvider(
        [
          CloudNote(
            id: 'n1',
            title: 'kept',
            createdAt: DateTime(2024),
            writeBody: (writer, resolve) => writer.text('body'),
          ),
        ],
        onFetch: (issues) {
          issues
            ..skip(JournalSkipReason.encrypted, 2)
            ..skip(JournalSkipReason.unsupported)
            ..skip(JournalSkipReason.unreadable, 0)
            ..summaryOnly += 1;
        },
      );

      for (var round = 0; round < 2; round++) {
        final result = await fetchCloudJournal(
          provider,
          JournalMediaStager(temp.path),
        );
        // 每次读取重新计数，第二次不会翻倍；计数为 0 的原因不出现。
        expect(result.skippedNotes, {
          JournalSkipReason.encrypted: 2,
          JournalSkipReason.unsupported: 1,
        });
        expect(result.summaryOnlyCount, 1);
        expect(result.entries.single.title, 'kept');
      }
    });
  });

  test('CloudReadIssues.atLeast only raises a count', () {
    final issues = CloudReadIssues()..skip(JournalSkipReason.encrypted, 3);
    issues
      ..atLeast(JournalSkipReason.encrypted, 2)
      ..atLeast(JournalSkipReason.unsupported, 4)
      ..atLeast(JournalSkipReason.unreadable, 0);
    expect(issues.skipped, {
      JournalSkipReason.encrypted: 3,
      JournalSkipReason.unsupported: 4,
    });
  });

  test('writeCloudBlocks maps every block kind', () {
    final writer = JournalBlockWriterProbe();
    writeCloudBlocks(writer.writer, const [
      CloudBlock(CloudBlockKind.heading, level: 5, spans: [CloudSpan('H')]),
      CloudBlock(CloudBlockKind.list, level: 2, spans: [CloudSpan('item')]),
      CloudBlock(CloudBlockKind.list, ordered: true, spans: [CloudSpan('one')]),
      CloudBlock(
        CloudBlockKind.todo,
        checked: true,
        spans: [CloudSpan('done')],
      ),
      CloudBlock(CloudBlockKind.quote, spans: [CloudSpan('a\nb')]),
      CloudBlock(CloudBlockKind.code, spans: [CloudSpan('x = 1')]),
      CloudBlock(CloudBlockKind.divider),
      CloudBlock(
        CloudBlockKind.table,
        rows: [
          ['名称', '数量'],
          ['苹果', '3'],
        ],
      ),
      CloudBlock.paragraph([
        CloudSpan('link', link: 'https://a.b'),
        CloudSpan(' js', link: 'javascript:alert(1)', highlight: true),
      ]),
    ], (_) => null);

    expect(writer.lines, [
      'H | {"header":3}',
      // 标题不能承载子块，孤立的缩进列表规整到顶层。
      'item | {"list":"bullet"}',
      'one | {"list":"ordered"}',
      'done | {"list":"checked"}',
      'a | {"blockquote":true}',
      'b | {"blockquote":true}',
      'x = 1 | {"code-block":true}',
      // 分隔线嵌入独占一行（探针不打印嵌入本身）。
      ' | {}',
      '名称 数量 | {}',
      '苹果 3 | {}',
      'link js | {}',
    ]);
    expect(writer.json, contains('"href":"https://a.b"'));
    expect(writer.json, isNot(contains('javascript')));
    expect(writer.json, contains('{"type":"divider"}'));
    // 只知道“高亮”的文字写成统一的高亮背景色。
    expect(writer.json, contains('"bg_color":"$journalHighlightColor"'));
  });
}

Matcher _failure(CloudNoteFailure failure) => isA<CloudNoteException>().having(
  (error) => error.failure,
  'failure',
  failure,
);

class _FakeProvider implements CloudNoteProvider {
  _FakeProvider(this.notes, {this.onFetch});

  final List<CloudNote> notes;

  /// 读取时顺带记下的问题（模拟平台跳过笔记）。
  final void Function(CloudReadIssues issues)? onFetch;

  @override
  final CloudReadIssues issues = CloudReadIssues();

  @override
  Future<String> probe() async => 'account';

  @override
  Future<List<CloudNote>> fetchNotes(CloudProgress onProgress) async {
    onFetch?.call(issues);
    return notes;
  }

  @override
  Future<List<int>> download(CloudAttachment attachment) async {
    if (attachment.id == 'empty') return [];
    if (attachment.id == 'protocol') {
      throw const CloudNoteException(CloudNoteFailure.protocolChanged);
    }
    if (attachment.id == 'gone') {
      throw const CloudNoteException(CloudNoteFailure.rejected);
    }
    if (attachment.id == 'expired') {
      throw const CloudNoteException(CloudNoteFailure.sessionExpired);
    }
    return fakeJpeg;
  }
}

/// 把写好的正文按行拆成（文字，块格式），便于断言。
class JournalBlockWriterProbe {
  final JournalBlockWriter writer = JournalBlockWriter();

  String get json => writer.build().contentJson;

  /// 每行为 `文字 | 块格式 JSON`。
  List<String> get lines {
    final result = <String>[];
    var text = StringBuffer();
    for (final op in diaryContentQuillOps(json)) {
      final insert = (op as Map)['insert'];
      if (insert is! String) continue;
      final attributes =
          (op['attributes'] as Map?)?.cast<String, Object?>() ?? const {};
      final parts = insert.split('\n');
      for (var i = 0; i < parts.length; i++) {
        text.write(parts[i]);
        if (i < parts.length - 1) {
          result.add('$text | ${jsonEncode(attributes)}');
          text = StringBuffer();
        }
      }
    }
    return result;
  }
}
