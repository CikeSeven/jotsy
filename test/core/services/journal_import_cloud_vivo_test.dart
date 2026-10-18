import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_cloud.dart';
import 'package:node_diary/core/services/journal_import_cloud_envelope.dart';
import 'package:node_diary/core/services/journal_import_cloud_http.dart';
import 'package:node_diary/core/services/journal_import_cloud_vivo.dart';
import 'package:node_diary/core/services/journal_import_delta_writer.dart';

import '../../support/cloud_test_keys.dart';
import '../../support/fake_cloud_http.dart';

const _api = 'pc.vivo.com.cn/note-api';

/// 模拟 vivo 接口：明文请求直接交给 [handler]；`jvq_param` 信封按参考实现
/// 测试的方式解开（头部取 IV 与包装的密钥），响应以同一头部、密钥加密成
/// `jvq_response`。
void _route(
  FakeCloudHttp http,
  String path,
  Object? Function(Map<String, Object?> request) handler,
) {
  http.on('POST', '$_api$path', (request) {
    final body = (request.json! as Map).cast<String, Object?>();
    final wrapped = body['jvq_param'];
    if (wrapped is! String) {
      return jsonResponse({'code': 0, 'data': handler(body)});
    }
    final raw = base64Url.decode(
      wrapped + '=' * ((4 - wrapped.length % 4) % 4),
    );
    final size = ByteData.sublistView(raw).getUint16(0);
    final tokenSize = raw[17];
    final iv = raw.sublist(18 + tokenSize, 34 + tokenSize);
    final key = unwrapCloudTestKey(raw.sublist(36 + tokenSize, size));
    final plain = utf8.decode(aesCbc(key, iv, raw.sublist(size), false));
    final data = handler((jsonDecode(plain) as Map).cast<String, Object?>());
    final reply = aesCbc(
      key,
      iv,
      utf8.encode(jsonEncode({'code': 0, 'data': data})),
      true,
    );
    return jsonResponse({
      'jvq_response': base64Url.encode([...raw.sublist(0, size), ...reply]),
    });
  });
}

void main() {
  late FakeCloudHttp http;
  late VivoCloudProvider provider;

  setUp(() {
    http = FakeCloudHttp();
    provider = VivoCloudProvider(
      http,
      wait: (_) async {},
      envelopeKey: cloudTestKeys.publicKey,
    );
    http.json('GET', '$_api/account/getUserCookie', {
      'code': 0,
      'data': {
        'vivo_account_cookie_iqoo_openid': 'open-1',
        'vivo_account_cookie_iqoo_vivotoken': 'token-1',
      },
    });
    _route(http, '/account/getUserInfo', (request) {
      expect(request, {'openId': 'open-1'});
      return {'userId': 'fixture-user'};
    });
    _route(
      http,
      '/statistics/note',
      (_) => {'totalNotes': 2, 'encryptedNotes': 0},
    );
  });

  test('probe adopts the session token headers', () async {
    expect(await provider.probe(), 'vivo:fixture-user');
    final info = http.requests[1];
    expect(info.headers['token'], 'token-1');
    expect(info.headers['openId'], 'open-1');
    expect(info.headers['source'], '1');
  });

  test('reads encrypted pages and bodies, maps vnote markup', () async {
    _route(
      http,
      '/noteBook/getList',
      (_) => [
        {'guid': 'folder', 'name': '旧名', 'nameNew': '工作'},
      ],
    );
    _route(http, '/note/getAllNote/v2', (request) {
      expect(request['maxEntries'], 50);
      return {
        'notes': [
          {
            'guid': 'n1',
            'userId': 'fixture-user',
            'type': 1,
            'deleted': 1,
            'encryptType': 0,
            'title': '清单',
            'createTime': 1720000000000,
            'updateTime': 1720000001000,
            'noteBookGuid': 'folder',
          },
          {
            'guid': 'trash',
            'userId': 'fixture-user',
            'type': 1,
            'deleted': 0,
            'createTime': 1720000000000,
          },
        ],
      };
    });
    _route(http, '/note/getContent/v2', (request) {
      expect(request['guid'], 'n1');
      return '<p>before</p><vnote-image filename="prefix-asset-a.png"></vnote-image>'
          '<vnote-todo><todo-item done="true"><b>done</b></todo-item>'
          '<todo-item done="false">pending</todo-item></vnote-todo>'
          '<vnote-divider></vnote-divider><vnote-handwriting>手写</vnote-handwriting>'
          '<p>after</p>';
    });
    _route(
      http,
      '/note/getIncludeItem/v2',
      (_) => {
        'guid': 'n1',
        'resources': [
          {
            'guid': 'asset-a',
            'userId': 'fixture-user',
            'noteGuid': 'n1',
            'name': 'a.png',
            'mime': 'image/png',
            'resourceSize': fakeJpeg.length,
            'domainAddr': 'https://clouddisk-fixture.vivo.com.cn',
            'resourceKey': 'key-a',
          },
        ],
      },
    );

    await provider.probe();
    final note = (await provider.fetchNotes((_, _) {})).single;

    expect(note.id, 'n1');
    expect(note.title, '清单');
    expect(note.folder, '工作');
    expect(note.attachments.single.id, 'asset-a');
    final writer = JournalDeltaWriter();
    note.writeBody(
      writer,
      (id) => id == 'asset-a' ? {'image': 'local.png'} : null,
    );
    final content = writer.build();
    // 图片与分隔线各占一行。
    expect(content.contentText, 'before\n\ndone\npending\n\n手写\nafter');
    expect(content.contentJson, contains('{"insert":{"divider":"hr"}}'));
    expect(content.contentJson, contains('"list":"checked"'));
    expect(content.contentJson, contains('"list":"unchecked"'));
    expect(content.contentJson, contains('local.png'));
  });

  test('downloads originals cookie-free with the STS token', () async {
    http.json(
      'POST',
      'pc.vivo.com.cn/clouddisk-api/api/suite/web/meta/getStsToken.do',
      {
        'code': 0,
        'data': {'stsToken': 'sts-1'},
      },
    );
    http.on(
      'GET',
      'clouddisk-fixture.vivo.com.cn/api/file/webdisk/source/key-a',
      (request) {
        expect(request.withCookies, isFalse);
        expect(request.url.queryParameters['stsToken'], 'sts-1');
        return bytesResponse(fakeJpeg);
      },
    );
    CloudAttachment attachment(String domain, int size) => CloudAttachment(
      id: 'asset-a',
      name: 'a.png',
      reference: {
        'domainAddr': domain,
        'resourceKey': 'key-a',
        'resourceSize': size,
      },
    );

    expect(
      await provider.download(
        attachment('https://clouddisk-fixture.vivo.com.cn', fakeJpeg.length),
      ),
      fakeJpeg,
    );
    for (final (domain, size) in [
      ('https://evil.example', fakeJpeg.length),
      ('https://clouddisk-fixture.vivo.com.cn/path', fakeJpeg.length),
      ('https://clouddisk-fixture.vivo.com.cn', 999),
    ]) {
      await expectLater(
        provider.download(attachment(domain, size)),
        throwsA(isA<CloudNoteException>()),
        reason: domain,
      );
    }
  });
}
