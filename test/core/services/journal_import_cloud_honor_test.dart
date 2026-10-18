import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_cloud.dart';
import 'package:node_diary/core/services/journal_import_cloud_honor.dart';
import 'package:node_diary/core/services/journal_import_cloud_http.dart';
import 'package:node_diary/core/services/journal_import_delta_writer.dart';
import 'package:node_diary/core/services/journal_import_media.dart';
import 'package:node_diary/core/services/journal_import_style.dart';

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

/// 富格式正文，结构照荣耀网页版编辑器保存的标记：居中/靠右段落、分隔线
/// （`Nm` > `Nr` > svg）、文字色（含默认墨色 #191919）、字号档位、背景色
/// （CSS `#RRGGBBAA`）与 `Le` 高亮、上传的文档与视频卡片、录音卡片、居中
/// 图片。
const _richHtml =
    '<p class="Nb h_n Aj"><h-text><font hsize="16"><span>居中标题</span></font></h-text></p>'
    '<p class="Nb h_n Ak"><h-text><font hsize="16"><span>靠右</span></font></h-text></p>'
    '<div class="Nm h_n"><div class="Nr h_n"><svg height="7px" width="100%"><line id="line" x1="0" x2="99999" stroke="currentColor" stroke-width="1"></line></svg></div></div>'
    '<p class="Nb h_n Ai"><h-text><font hsize="16" hcolor="#FA2A2D"><span>红字</span></font></h-text>'
    '<h-text><font hsize="16" hcolor="#191919"><span>默认</span></font></h-text>'
    '<h-text><font hsize="24"><span>特大</span></font></h-text>'
    '<h-text><font hsize="14"><span>小字</span></font></h-text>'
    '<h-text><font hsize="18" hbgcolor="#FFBF0061"><span>黄底</span></font></h-text>'
    '<h-text><font hsize="16" class="Le"><span>高亮</span></font></h-text></p>'
    '<div class="Nx h_n" void="1" hid="file\$1" huploadfiletype="Document" huploadsize="8">'
    '<div spacer="1" style="height: 0px; position: absolute;"><br v="1"></div>'
    '<div><div class="upload-file"><div class="upload-title"><span class="first-title">季度</span>'
    '<span class="last-title">报告</span><span class="upload-type">.pdf</span></div>'
    '<span class="upload-size">8 B</span></div><div class="upload-icon"></div></div></div>'
    '<div class="N0 h_n" hid="voice\$1" vtype="1" vui="v2"></div>'
    '<div class="Nx h_n" void="1" hid="video\$1" huploadfiletype="Video" huploadsize="8" hposterid="poster\$1">'
    '<div class="video-poster-card" src="blob:poster" poster-cid="poster\$1"><div class="upload-file">'
    '<div class="upload-title"><span class="first-title">旅行</span><span class="upload-type">.mp4</span>'
    '</div></div></div></div>'
    '<div class="Nk h_n Aj"><div class="Ni h_n" void="1" hid="$_preview">'
    '<div spacer="1"><br v="1"></div><img src="cid:$_preview"></div></div>'
    '<p class="Nb h_n"><h-text><font hsize="16"><span>结尾</span></font></h-text></p>';

Map<String, Object?> _attachment(
  String uuid,
  String filename, [
  String mimetype = 'image/png',
]) => {
  'uuid': uuid,
  'filename': filename,
  'mimetype': mimetype,
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

  group('rich formats and attachments', () {
    late Directory temp;
    setUp(() async {
      temp = await Directory.systemTemp.createTemp('honor_');
      http.json('POST', '$_api/notepad/note/initDataBase/getFolderList', {
        'code': 0,
        'data': <Object?>[],
      });
      http.json('POST', '$_api/notepad/note/util/getNoteList', {
        'code': 0,
        'data': [
          {'uuid': _note},
        ],
      });
      http.json('POST', '$_api/notepad/noteDetail', {
        'code': 0,
        'data': [
          {
            'uuid': _note,
            'type': 2,
            'title': '富格式',
            'create_time': 1720000000000,
            'lock_status': 0,
            'delete_flag': 0,
            'unstruct_guid': 'box',
            'html_content': _richHtml,
            'attachments': [
              _attachment(
                r'file$1',
                r'file$1_1720000000000_import.pdf',
                'application/pdf',
              ),
              _attachment(r'voice$1', r'voice$1', 'audio/mp4'),
              _attachment(
                r'video$1',
                r'video$1_1720000000000.mp4',
                'video/mp4',
              ),
              _attachment(r'poster$1', r'poster$1_320_180.jpg', 'image/jpeg'),
              _attachment(r'7a6b5c4d$3e2f', _original),
              _attachment(_preview, '${_preview}_80_50_1720000000000.png'),
              // 文件名带路径的记录不能拼进下载路径，只按缺失计入。
              _attachment(r'bad$1', '../escape.pdf', 'application/pdf'),
            ],
          },
        ],
      });
      http.json('GET', '$_api/config/web', {
        'code': 0,
        'data': {
          'viteDownloadDomain': 'https://fileproxy-drcn.cloud.honor.com',
        },
      });
      http.on(
        'GET',
        'fileproxy-drcn.cloud.honor.com/portal/notepad/file/singleFileDownstream',
        (_) => bytesResponse(fakeJpeg),
      );
    });
    tearDown(() => temp.delete(recursive: true));

    test('lists files by their card names and skips video posters', () async {
      final note = (await provider.fetchNotes((_, _) {})).single;
      expect(note.attachments.map((item) => (item.id, item.name)), [
        (r'bad$1', r'bad$1'),
        (r'file$1', '季度报告.pdf'),
        (r'voice$1', r'voice$1'),
        (r'video$1', '旅行.mp4'),
        (_preview, _original),
      ]);
      expect(note.attachments.first.reference, isNull);
    });

    test('keeps alignment, dividers, colours, sizes and highlights', () async {
      final note = (await provider.fetchNotes((_, _) {})).single;
      final writer = JournalDeltaWriter();
      note.writeBody(
        writer,
        (id) => switch (id) {
          r'file$1' => {'attachment': 'f'},
          r'voice$1' => {'audio': 'a'},
          r'video$1' => {'video': 'v'},
          _preview => {'image': 'p.png'},
          _ => null,
        },
      );
      final ops = (jsonDecode(writer.build().contentJson) as List)
          .cast<Map<String, Object?>>();
      Map? attributesOf(String text) =>
          ops.firstWhere((op) => op['insert'] == text)['attributes'] as Map?;
      String describe(Map<String, Object?> op) {
        final insert = op['insert'];
        final attributes = op['attributes'];
        return insert is Map
            ? '[${insert.keys.single}]'
            : '${jsonEncode(insert)}${attributes == null ? '' : ' $attributes'}';
      }

      expect(ops.map(describe), [
        '"居中标题"',
        '"\\n" {align: center}',
        '"靠右"',
        '"\\n" {align: right}',
        '[divider]',
        '"\\n"',
        '"红字" {color: #FFFA2A2D}',
        '"默认"',
        '"特大" {size: huge}',
        '"小字" {size: small}',
        '"黄底" {background: #61FFBF00, size: large}',
        '"高亮" {background: $journalHighlightColor}',
        '"\\n"',
        '[attachment]',
        '"\\n"',
        '[audio]',
        '"\\n"',
        '[video]',
        '"\\n"',
        '[image]',
        '"\\n" {align: center}',
        '"结尾\\n"',
      ]);
      expect(attributesOf('默认'), isNull);
    });

    test(
      'imports documents, recordings and videos as their own kinds',
      () async {
        final result = await fetchCloudJournal(
          provider,
          JournalMediaStager(temp.path),
        );
        final ops = (jsonDecode(result.entries.single.contentJson) as List)
            .cast<Map<String, Object?>>();
        final embeds = [
          for (final op in ops)
            if (op['insert'] case final Map insert) insert.keys.single,
        ];
        // 视频封面不单独导入，路径不合规的记录计为缺失。
        expect(embeds, ['divider', 'attachment', 'audio', 'video', 'image']);
        expect(result.missingMediaCount, 1);
        final file = ops
            .map((op) => op['insert'])
            .whereType<Map>()
            .firstWhere((insert) => insert.containsKey('attachment'));
        expect(file['attachment'], contains('季度报告.pdf'));
      },
    );
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
