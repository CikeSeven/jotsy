import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_cloud.dart';
import 'package:node_diary/core/services/journal_import_cloud_honor.dart';
import 'package:node_diary/core/services/journal_import_cloud_http.dart';
import 'package:node_diary/core/services/journal_import_delta_writer.dart';

import '../../support/fake_cloud_http.dart';

const _api = 'cloud.honor.com/portal';
const _note = '0123456789abcdef0123456789abcdef';
const _preview = r'1f2e3d4c$5b6a$4789$8a9b$0c1d2e3f4a5b';
const _original = '${_preview}_80_50_1720000000000_original.png';

/// 夹具 B-5 的正文：标题、各种行内格式、勾选图标式待办、单项列表、图片。
const _html =
    '<p class="Nb h_n" hlevel="2"><h-text><font hsize="16" class="La"><span>购物清单</span></font></h-text></p>'
    '<p class="Nb h_n"><h-text><font class="La"><span>加粗</span></font></h-text>'
    '<h-text><font class="Lb"><span>斜体</span></font></h-text>'
    '<h-text><font class="Lc Ld"><span>划线</span></font></h-text>'
    '<h-text><font hlink="https://example.com/note"><span>链接</span></font></h-text></p>'
    '<div class="Na h_n"><svg class="Sc"><path/></svg><h-text><font><span>已完成</span></font></h-text></div>'
    '<div class="Na h_n Sb"><h-text><font><span>未完成</span></font></h-text></div>'
    '<ol class="Nd Pa h_n" start="1"><li class="Nc h_n"><h-text><font><span>第一项</span></font></h-text></li></ol>'
    '<ul class="Nh Pf h_n"><li class="Nc h_n"><h-text><font><span>项目</span></font></h-text></li></ul>'
    '<div class="Nk h_n"><div class="Ni h_n" void="1" hid="$_preview"><img src="cid:$_preview"></div></div>'
    '<p class="Nb h_n"><h-text><font><span>结尾</span></font></h-text></p>';

Map<String, Object?> _attachment(String uuid, String filename) => {
  'uuid': uuid,
  'filename': filename,
  'mimetype': 'image/png',
  'parent_uuid': _note,
  'size': fakeJpeg.length,
  'hash': sha256.convert(fakeJpeg).toString(),
  'attach_type': 2,
};

void main() {
  late FakeCloudHttp http;
  late HonorCloudProvider provider;

  setUp(() {
    http = FakeCloudHttp(cookies: {'hc_CSRF_Token': 'csrf-1'});
    provider = HonorCloudProvider(http, wait: (_) async {});
    http.json('GET', '$_api/user/info', {
      'code': 0,
      'data': {'userId': 'synthetic-user'},
    });
    http.json('GET', '$_api/notepad/note/count', {
      'code': 0,
      'data': {'total': 1},
    });
  });

  test('probe needs the CSRF cookie and sends the HONOR headers', () async {
    expect(await provider.probe(), 'honor:synthetic-user');
    final request = http.requests.first;
    expect(request.headers['Csrftoken'], 'csrf-1');
    expect(request.headers['Device-Type'], '1');
    expect(request.headers['x-hn-traceId'], matches(RegExp(r'^[0-9a-f]{32}$')));

    final anonymous = HonorCloudProvider(FakeCloudHttp());
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

  test('reads folders and notes, pairs images and rewrites the body', () async {
    http.json('POST', '$_api/notepad/note/initDataBase/getFolderList', {
      'code': 0,
      'data': [
        {'uuid': 'bbbb', 'display_name': '工作', 'type': 1, 'delete_flag': 0},
        {'uuid': 'cccc', 'display_name': '已删分组', 'type': 1, 'delete_flag': 1},
      ],
    });
    http.on('POST', '$_api/notepad/note/util/getNoteList', (request) {
      expect(request.json, {
        'queryType': 1,
        'category': 'total',
        'searchContent': '',
      });
      return jsonResponse({
        'code': 0,
        'data': [
          {'uuid': _note},
        ],
      });
    });
    http.json('POST', '$_api/notepad/noteDetail', {
      'code': 0,
      'data': [
        {
          'uuid': _note,
          'type': 2,
          'title': '购物清单',
          'folder_uuid': 'bbbb',
          'create_time': 1720000000000,
          'modify_time': 1720000001000,
          'lock_status': 0,
          'delete_flag': 0,
          'unstruct_guid': '9b2d6c1e4f8a4b7c9d0e1f2a3b4c5d6e',
          'html_content': _html,
          'attachments': [
            _attachment(r'7a6b5c4d$3e2f$4a1b$9c8d$7e6f5a4b3c2d', _original),
            _attachment(_preview, '${_preview}_80_50_1720000000000.png'),
          ],
        },
      ],
    });

    final note = (await provider.fetchNotes((_, _) {})).single;

    expect(note.id, _note);
    expect(note.title, '购物清单');
    expect(note.folder, '工作');
    final attachment = note.attachments.single;
    expect(attachment.id, _preview);
    expect(attachment.name, _original);
    final writer = JournalDeltaWriter();
    note.writeBody(writer, (id) => id == _preview ? {'image': 'p.png'} : null);
    final content = writer.build();
    expect(content.contentText, '购物清单\n加粗斜体划线链接\n已完成\n未完成\n第一项\n项目\n\n结尾');
    final ops = (jsonDecode(content.contentJson) as List).cast<Map>();
    Map? attributesOf(String text) =>
        ops.firstWhere((op) => op['insert'] == text)['attributes'] as Map?;
    expect(attributesOf('斜体'), {'italic': true});
    expect(attributesOf('划线'), {'underline': true, 'strike': true});
    expect(attributesOf('链接'), {'link': 'https://example.com/note'});
    final lines = ops
        .where((op) => op['insert'] == '\n' && op['attributes'] != null)
        .map((op) => op['attributes'])
        .toList();
    expect(lines, [
      {'header': 2},
      {'list': 'checked'},
      {'list': 'unchecked'},
      {'list': 'ordered'},
      {'list': 'bullet'},
    ]);
    expect(content.contentJson, contains('p.png'));
  });

  test('a note list that disagrees with the count is rejected', () async {
    http.json('POST', '$_api/notepad/note/initDataBase/getFolderList', {
      'code': 0,
      'data': <Object?>[],
    });
    http.json('POST', '$_api/notepad/note/util/getNoteList', {
      'code': 0,
      'data': <Object?>[],
    });
    await expectLater(
      provider.fetchNotes((_, _) {}),
      throwsA(isA<CloudNoteException>()),
    );
  });

  test(
    'downloads originals from the configured host and checks digests',
    () async {
      http.json('GET', '$_api/config/web', {
        'code': 0,
        'data': {
          'viteDownloadDomain': 'https://fileproxy-drcn.cloud.honor.com',
        },
      });
      http.on(
        'GET',
        'fileproxy-drcn.cloud.honor.com/portal/notepad/file/singleFileDownstream',
        (request) {
          expect(
            request.url.queryParameters['cloudPath'],
            '/sync/notepad/box/$_original',
          );
          expect(request.headers['Csrftoken'], 'csrf-1');
          expect(request.headers['Origin'], 'https://cloud.honor.com');
          return bytesResponse(fakeJpeg);
        },
      );
      CloudAttachment attachment(String hash) => CloudAttachment(
        id: _preview,
        name: _original,
        reference: (
          container: 'box',
          filename: _original,
          size: fakeJpeg.length,
          hash: hash,
        ),
      );

      expect(
        await provider.download(
          attachment(sha256.convert(fakeJpeg).toString()),
        ),
        fakeJpeg,
      );
      await expectLater(
        provider.download(attachment('0' * 64)),
        throwsA(isA<CloudNoteException>()),
      );
    },
  );

  test('rejects file hosts outside HONOR domains', () async {
    for (final domain in [
      'https://evil.example',
      'http://fileproxy-drcn.cloud.honor.com',
      'https://fileproxy-drcn.cloud.honor.com:8443',
      'https://fileproxy-drcn.cloud.honor.com/path',
    ]) {
      final fresh = HonorCloudProvider(http, wait: (_) async {});
      http.json('GET', '$_api/config/web', {
        'code': 0,
        'data': {'viteDownloadDomain': domain},
      });
      await expectLater(
        fresh.download(
          const CloudAttachment(
            id: 'a',
            name: 'a',
            reference: (container: 'c', filename: 'f', size: 1, hash: 'h'),
          ),
        ),
        throwsA(isA<CloudNoteException>()),
        reason: domain,
      );
    }
  });
}
