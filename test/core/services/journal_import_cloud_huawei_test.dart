import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_cloud.dart';
import 'package:node_diary/core/services/journal_import_cloud_http.dart';
import 'package:node_diary/core/services/journal_import_cloud_huawei.dart';
import 'package:node_diary/core/services/journal_import_delta_writer.dart';

import '../../support/fake_cloud_http.dart';

const _host = 'cloud.huawei.com';
const _image = 'synthetic-prefix_30_20_1720000000000.png';

/// 参考实现夹具 H-1：新版（包在 content 里）、旧版平铺与已删除分组。
Map<String, Object?> _tags() => {
  'Result': {'code': '0'},
  'ctagNoteTag': 'tag-version',
  'rspInfo': {
    'noteList': [
      {
        'data': jsonEncode({
          'content': {
            'uuid': 'category-id',
            'name': '工作',
            'type': 2,
            'delete_flag': 0,
          },
        }),
      },
      {
        'data': jsonEncode({
          'uuid': 'legacy-flat-id',
          'name': '生活',
          'type': 2,
          'delete_flag': 0,
        }),
      },
      {
        'data': jsonEncode({
          'content': {
            'uuid': 'deleted-id',
            'name': '旧分组',
            'type': 2,
            'delete_flag': 1,
          },
        }),
      },
    ],
  },
};

/// 夹具 H-3：`rspInfo.data` 与 `content.data5` 都是 JSON 字符串。
Map<String, Object?> _detail() => {
  'Result': {'code': '0'},
  'rspInfo': {
    'guid': 'cloud-guid-A',
    'kind': 'note',
    'etag': 'synthetic-version-1',
    'attachments': [
      {
        'assetId': 'synthetic-asset-0',
        'usage': _image,
        'versionId': 'version-1',
        'resourceLength': fakeJpeg.length,
        'resourceType': 0,
      },
    ],
    'data': jsonEncode({
      'guid': 'legacy-client-guid',
      'content': {
        'delete_flag': 0,
        'created': 1720000000000,
        'modified': 1720000001000,
        'data5': jsonEncode({'data1': '购物清单', 'data2': 'edit'}),
        'title': '购物清单\n加粗普通',
        'tag_id': 'category-id',
        'html_content':
            '<note><element type="Text"><hw_font size="1.0">购物清单</hw_font></element>'
            '<element type="Text"><hw_font size="1.0"><b>加粗</b>普通<i>斜体</i><u>下划线</u>'
            '<u><i><b>三合一</b></i></u></hw_font></element>'
            '<element type="Bullet">1<hw_font size="1.0">已完成</hw_font></element>'
            '<element type="Bullet">0<hw_font size="1.0">未完成</hw_font></element>'
            '<element type="Attachment">/data/user/0/com.example.android.notepad/images/$_image</element>'
            '<element type="Text"><hw_font size="1.0"></hw_font></element>'
            '<element type="Text"><hw_font size="1.0">第一行<br/>第二行</hw_font></element></note>',
      },
    }),
  },
};

void main() {
  late FakeCloudHttp http;
  late HuaweiCloudProvider provider;

  setUp(() {
    http = FakeCloudHttp(cookies: {'userId': 'u1', 'shareToken': 'share-0'});
    provider = HuaweiCloudProvider(http, wait: (_) async {}, random: Random(1));
    http.json('POST', '$_host/notepad/notetag/query', _tags());
  });

  test('probe sends the official traceId and the CSRF token', () async {
    expect(await provider.probe(), 'huawei:u1');
    final request = http.requests.single;
    expect(
      (request.json! as Map)['traceId'],
      matches(RegExp(r'^03133_02_\d+_[1-9]{8}$')),
    );
    expect(request.headers['CSRFToken'], 'share-0');
    expect(request.headers['Referer'], 'https://cloud.huawei.com/home');
    expect(request.headers.containsKey('x-hw-trace-id'), isFalse);
  });

  test(
    'falls back to the account parameters without a userId cookie',
    () async {
      http = FakeCloudHttp();
      provider = HuaweiCloudProvider(http, wait: (_) async {});
      http.json('POST', '$_host/notepad/notetag/query', _tags());
      http.json('POST', '$_host/html/getCommonParam', {
        'code': 0,
        'isLogin': 1,
        'userid': 'from-param',
      });
      expect(await provider.probe(), 'huawei:from-param');
    },
  );

  test(
    'rotates the CSRF token from response headers into the cookie',
    () async {
      var calls = 0;
      http.on('POST', '$_host/notepad/notetag/query', (_) {
        calls++;
        return CloudNoteResponse(
          200,
          utf8.encode(jsonEncode(_tags())),
          headers: calls == 1
              ? const {'csrftoken': 'synthetic/+=%rotation'}
              : const {},
        );
      });
      await provider.probe();
      await provider.probe();
      expect(
        http.requests.last.headers['CSRFToken'],
        'synthetic%2F%2B%3D%25rotation',
      );
      expect(http.cookie('shareToken'), 'synthetic%2F%2B%3D%25rotation');
    },
  );

  test('reads folders, decodes nested JSON and rewrites the body', () async {
    http.json('POST', '$_host/notepad/simplenote/query', {
      'Result': {'code': '0'},
      'ctagNoteInfo': 'note-version',
      'startCursor': 'listing-cursor',
      'rspInfo': {
        'noteList': [
          {'guid': 'cloud-guid-A', 'kind': 'note', 'etag': '1'},
          {'guid': 'task-1', 'kind': 'task', 'etag': '1'},
        ],
      },
    });
    http.on('POST', '$_host/notepad/note/query', (request) {
      final body = request.json! as Map;
      expect(body['ctagNoteInfo'], 'note-version');
      expect(body['startCursor'], 'listing-cursor');
      return jsonResponse(_detail());
    });

    final note = (await provider.fetchNotes((_, _) {})).single;

    expect(note.id, 'cloud-guid-A');
    expect(note.title, '购物清单');
    expect(note.folder, '工作');
    expect(note.createdAt, DateTime.utc(2024, 7, 3, 9, 46, 40).toLocal());
    expect(note.attachments.single.id, 'synthetic-asset-0');
    final writer = JournalDeltaWriter();
    note.writeBody(
      writer,
      (id) => id == 'synthetic-asset-0' ? {'image': 'local.png'} : null,
    );
    final content = writer.build();
    // 与标题相同的第一段去掉；空 hw_font 是空行；<br/> 换行。
    expect(content.contentText, '加粗普通斜体下划线三合一\n已完成\n未完成\n\n\n第一行\n第二行');
    final ops = content.contentJson;
    expect(ops, contains('"list":"checked"'));
    expect(ops, contains('"list":"unchecked"'));
    expect(ops, contains('local.png'));
    final combined = (jsonDecode(ops) as List).firstWhere(
      (op) => (op as Map)['insert'] == '三合一',
    );
    expect((combined as Map)['attributes'], {
      'bold': true,
      'italic': true,
      'underline': true,
    });
  });

  test(
    'prepares each note once and downloads through the file proxy',
    () async {
      http.json('POST', '$_host/html/getAboutGet', {
        'code': 0,
        'dataSwitch': 1,
        'dataVersion': 'dataVersion=2.0',
      });
      http.json('POST', '$_host/html/getCommonParam', {
        'code': 0,
        'fileProxyGrayStrategyVersionValue': 'synthetic-version',
      });
      http.json('POST', '$_host/proxyserver/driveFileProxy/preProcess', {
        'code': '0',
      });
      final route = Uri.encodeComponent(
        '/v2/dataSync/callback/v1/1001/kind/note/record/cloud-guid-A/assets/'
        'a%24b/revisions/version-1',
      );
      http.on('GET', '$_host/proxy/v1/download/$route', (request) {
        expect(request.url.queryParameters['version'], 'synthetic-version');
        expect(request.headers['version'], 'synthetic-version');
        expect(request.headers.containsKey('CSRFToken'), isFalse);
        return bytesResponse(fakeJpeg);
      });
      const attachment = CloudAttachment(
        id: r'a$b',
        name: 'x.png',
        reference: (
          note: 'cloud-guid-A',
          asset: r'a$b',
          version: 'version-1',
          length: 8,
        ),
      );

      expect(await provider.download(attachment), fakeJpeg);
      expect(await provider.download(attachment), fakeJpeg);

      final paths = http.requests.map((request) => request.url.path).toList();
      expect(paths.where((path) => path.endsWith('preProcess')), hasLength(1));
      expect(paths.where((path) => path.endsWith('getAboutGet')), hasLength(1));
      // `$` 先编码成 %24，整段路由再编码一次成为 %2524。
      expect(http.requests.last.url.toString(), contains('%2Fa%2524b%2F'));
    },
  );

  test('refuses attachments when the new file proxy is not enabled', () async {
    http.json('POST', '$_host/html/getAboutGet', {
      'code': 0,
      'dataSwitch': 1,
      'dataVersion': 'dataVersion=1.0',
    });
    http.json('POST', '$_host/html/getCommonParam', {
      'code': 0,
      'fileProxyGrayStrategyVersionValue': 'v',
    });
    await expectLater(
      provider.download(
        const CloudAttachment(
          id: 'a',
          name: 'a',
          reference: (note: 'n', asset: 'a', version: 'v', length: null),
        ),
      ),
      throwsA(isA<CloudNoteException>()),
    );
  });
}
