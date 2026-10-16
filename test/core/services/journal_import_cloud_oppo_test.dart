import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_cloud.dart';
import 'package:node_diary/core/services/journal_import_cloud_envelope.dart';
import 'package:node_diary/core/services/journal_import_cloud_http.dart';
import 'package:node_diary/core/services/journal_import_cloud_oppo.dart';
import 'package:node_diary/core/services/journal_import_delta_writer.dart';

import '../../support/cloud_test_keys.dart';
import '../../support/fake_cloud_http.dart';

const _host = 'owork-api-cn.oppo.com/owork-server';

/// 模拟 OPPO 笔记接口：解开请求信封，交给 [handler] 处理明文请求，再用
/// 同一会话密钥加密 `{code: 0, data: …}` 返回。
void _encryptedRoute(
  FakeCloudHttp http,
  String path,
  Object? Function(Map<String, Object?> request) handler,
) {
  http.on('POST', '$_host$path', (request) {
    final envelope = request.json! as Map;
    final key = unwrapCloudTestKey(base64.decode(envelope['key'] as String));
    final plain = aesCbc(
      key,
      ascii.encode(envelope['iv'] as String),
      base64.decode(envelope['encryptContent'] as String),
      false,
    );
    final data = handler(
      (jsonDecode(utf8.decode(plain)) as Map).cast<String, Object?>(),
    );
    const iv = '0123456789abcdef';
    return jsonResponse({
      'code': 0,
      'data': {
        'iv': iv,
        'encryptContent': base64.encode(
          aesCbc(
            key,
            ascii.encode(iv),
            utf8.encode(jsonEncode({'code': 0, 'data': data})),
            true,
          ),
        ),
      },
    });
  });
}

void main() {
  late FakeCloudHttp http;
  late OppoCloudProvider provider;

  setUp(() {
    http = FakeCloudHttp();
    provider = OppoCloudProvider(
      http,
      wait: (_) async {},
      envelopeKey: cloudTestKeys.publicKey,
    );
    http.json('GET', '$_host/web/account/v1/userInfo', {
      'code': 0,
      'data': {'ssoId': 42},
    });
    _encryptedRoute(
      http,
      '/web/note/v2/group-list-new',
      (_) => [
        {'groupGuid': '', 'groupName': '全部笔记'},
        {'groupGuid': 'g1', 'groupName': '旅行'},
      ],
    );
  });

  test('probe reads the account and opens an encrypted request', () async {
    expect(await provider.probe(), 'oppo:42');
    final request = http.requests.last;
    expect(request.headers['Referer'], 'https://cloud.oppo.com/');
    expect((request.json! as Map).keys, {'key', 'iv', 'encryptContent'});
  });

  test('pages the list, reads details and maps images and todos', () async {
    final pages = <int>[];
    _encryptedRoute(http, '/web/note/v2/list', (request) {
      final page = request['pageNo'] as int;
      pages.add(page);
      expect(request['pageSize'], 50);
      return {
        'records': [
          {'recordId': page == 1 ? 'r1' : 'r2'},
        ],
        'totalCount': 2,
        'hasMore': page == 1,
      };
    });
    _encryptedRoute(http, '/web/note/v2/info', (request) {
      final id = request['recordId'];
      expect(request['version'], '');
      return id == 'r1'
          ? {
              'recordId': 'r1',
              'status': 0,
              'rawTitle': '清单',
              'groupGuid': 'g1',
              'createTime': 1700000000000,
              'updateTime': 1700000100000,
              'rawText':
                  '<h1>标题</h1><p><i>斜体</i></p>'
                  '<ul data-type="taskList"><li data-type="taskItem" data-checked="true">'
                  '<div><p>完成</p></div></li></ul>'
                  '<img src="555" attachid="555"><img src="https://x/y.jpg">',
              'attachments': [
                {'id': 555, 'type': 0, 'url': '/file_abc'},
                {'id': 556, 'type': 1, 'url': '/rec'},
              ],
            }
          : {
              'recordId': 'r2',
              'status': 0,
              'rawText': '<p>二</p>',
              'createTime': 1700000000000,
            };
    });

    final notes = await provider.fetchNotes((_, _) {});

    expect(pages, [1, 2]);
    final [first, second] = notes;
    expect(first.title, '清单');
    expect(first.folder, '旅行');
    expect(first.createdAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    expect(first.attachments.map((item) => (item.id, item.reference)), [
      ('555', 'file_abc'),
    ]);
    final writer = JournalDeltaWriter();
    first.writeBody(
      writer,
      (id) => id == '555' ? {'image': 'local.jpg'} : null,
    );
    final ops = writer.build().contentJson;
    expect(ops, contains('"list":"checked"'));
    expect(ops, contains('"italic":true'));
    expect(ops, contains('"header":1'));
    expect(ops, contains('local.jpg'));
    // 对应不上附件的远程图片不保留。
    expect(ops, isNot(contains('https://x/y.jpg')));
    expect(second.folder, isNull);
  });

  test('a listing whose total disagrees is rejected', () async {
    _encryptedRoute(
      http,
      '/web/note/v2/list',
      (_) => {
        'records': [
          {'recordId': 'only'},
        ],
        'totalCount': 3,
        'hasMore': false,
      },
    );
    await expectLater(
      provider.fetchNotes((_, _) {}),
      throwsA(isA<CloudNoteException>()),
    );
  });

  test('downloads attachment files without the envelope', () async {
    http.on(
      'GET',
      '$_host/web/note/v2/file-download/file_abc',
      (_) => CloudNoteResponse(
        200,
        fakeJpeg,
        headers: const {'content-type': 'image/jpeg'},
      ),
    );
    expect(
      await provider.download(
        const CloudAttachment(id: '555', name: 'x', reference: 'file_abc'),
      ),
      fakeJpeg,
    );
  });
}
