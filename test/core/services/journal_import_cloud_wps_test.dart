import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_diary/core/services/journal_import_cloud.dart';
import 'package:node_diary/core/services/journal_import_cloud_blocks.dart';
import 'package:node_diary/core/services/journal_import_cloud_http.dart';
import 'package:node_diary/core/services/journal_import_cloud_wps.dart';
import 'package:node_diary/core/services/journal_import_cloud_wps_format.dart';
import 'package:node_diary/core/services/journal_import_delta_writer.dart';

import '../../support/fake_cloud_http.dart';

// 测试向量由 openssl 按协议生成（合成数据，非账号数据）。
const _aesPassword = 't14KMhfNluQ2tBz3CssxlAG4R3Cl06yAXwX1uoZSoWE%3D';
const _encEmpty = 'qSHBqk42OCXyA9yeFXF/SA==';
const _encSummary = 'Qeh8BvfNl5+zGllvfaKt2OenNH3+SiamjZ7jzfiHK0E=';
const _encLongSummary = 'p1z9n3BCfByDSQFm3Hv/O6cGFFRalap+w1aKU14rSr4=';
const _encLongKey =
    '4mpi4cShOmvatkEQif2XXH4abc0XMDW5qCiAcZufyYSwfEZ48xHnqsS6QWRfV7p2nhg+BaYoYp0IwTHkJP/LJQ==';
const _longObject = 'VzwlQK/Gefjiv77bp7+f7dkm+qD0dNOppVPOJ+BqKoA=';
const _encBody =
    'hUmVLCyRzoyVPEU9WXzpHKYCLOi16gSupWIhqcT15/1RS2oWam06tccLwBweYbbADH7VZJ2I4gItvzAj3m9aZpYO9ljVz8I9WOh98nSNUtrRLTcuo7HseqO+oGCoP67x/kX0+eDVS6fCbR+Syq88FwrI0sPvfuxTmMqvZv4jSqP2epdrJkd6I420BgosM7TWzeWPw+x+Vcj91GRke7e22JXfurOnh4j/VWZsTu8oqCIQfC5wkYN+HNsj87KVOVow87kw1lh+Cjyy04jliB+LzjN/rqtMUR1ZIlQJ9Vn5PNjXOHkce82q0NYZdRuCMCah';
const _storageConfig = {
  'region': 'cn-north-1',
  'bucket': 'synthetic-bucket',
  'keyPrefix': 'notes/u123/',
  'accessKeyId': 'gt9mC6H+JS6iDbvTSBz7HA==',
  'secretAccessKey': 'BasI8/GplcIg2FuRGP/HUA==',
  'sessionToken': '+R5n4mrnqhPOzoaTghSqLg==',
};

const _api = 'note-api.wps.cn';
const _s3 = 'synthetic-bucket.s3.cn-north-1.amazonaws.com.cn';

void main() {
  group('WPS format', () {
    test('derives the field key and decrypts fields', () {
      final codec = WpsCodec(_aesPassword);
      expect(codec.decrypt(_encEmpty), '');
      expect(codec.decrypt(''), '');
      expect(codec.decrypt(_encSummary), '购物清单\n牛奶');
      expect(codec.decryptBytes(base64.decode(_longObject)), '### 长正文\n第一段\n');
    });

    test('parses the line dialect with escapes and media lines', () {
      final media = <WpsMedia>[];
      final blocks = decodeWpsBody(
        WpsCodec(_aesPassword).decrypt(_encBody),
        onMedia: media.add,
      );
      String describe(CloudBlock block) => [
        block.kind.name,
        if (block.kind == CloudBlockKind.heading) 'h${block.level}',
        if (block.kind == CloudBlockKind.list) block.ordered ? 'ol' : 'ul',
        if (block.kind == CloudBlockKind.todo) block.checked ? 'x' : ' ',
        block.spans
            .map(
              (span) =>
                  '${span.text}${[if (span.bold) 'b', if (span.italic) 'i', if (span.underline) 'u'].join()}',
            )
            .join('|'),
      ].join(':');
      expect(blocks.map(describe), [
        'heading:h2:购物清单',
        'todo:x:牛奶b',
        'todo: :鸡蛋i| 和 |面包u',
        'list:ul:苹果',
        'list:ol:第一步',
        'list:ol:第二步',
        'attachment:',
        'attachment:',
        'paragraph:转义 |*|星号|*| 与 |~|波浪|~',
      ]);
      expect(media, [
        (key: '0123456789abcdef0123456789abcdef', audio: false, name: null),
        (key: 'fedcba9876543210fedcba9876543210', audio: true, name: null),
      ]);
      expect(
        blocks[6].attachmentId,
        '3eb1bd439947eb762998e566ccc2e099c791118b2f40579cc4f7da2b5061b7f9',
      );
    });

    test('keeps notes with unknown media lines and imports them as files', () {
      final media = <WpsMedia>[];
      final blocks = decodeWpsBody(
        '前\n![file](ab-cd){name:报告.pdf;size:12}\n![x](ef){foo}\n后',
        onMedia: media.add,
      );
      expect(blocks.map((block) => block.kind), [
        CloudBlockKind.paragraph,
        CloudBlockKind.attachment,
        CloudBlockKind.attachment,
        CloudBlockKind.paragraph,
      ]);
      expect(media, [
        (key: 'ab/cd', audio: false, name: '报告.pdf'),
        (key: 'ef', audio: false, name: null),
      ]);
      expect(blocks[1].attachmentId, wpsMediaId('ab/cd'));
    });

    test('signs S3 requests with AWS Signature V4', () {
      final storage = WpsStorage.parse(_storageConfig, WpsCodec(_aesPassword));
      final url = storage.objectUrl(
        'notes/u123/0123456789abcdef0123456789abcdef',
      );
      expect(url.host, _s3);
      final headers = storage.sign(url, DateTime.utc(2024, 7, 3, 9, 46, 40));
      expect(headers['x-amz-date'], '20240703T094640Z');
      expect(headers['x-amz-security-token'], 'SESSIONFIXTURE');
      // 期望值由 Python 标准库按 AWS 规范独立计算。
      expect(
        headers['Authorization'],
        'AWS4-HMAC-SHA256 Credential=AKIDFIXTURE/20240703/cn-north-1/s3/aws4_request, '
        'SignedHeaders=host;x-amz-content-sha256;x-amz-date;x-amz-security-token, '
        'Signature=f3aa46350fbe5c16b5e6b70e6c085caa49bafb63dc14ebfad776969313eed7e5',
      );
    });
  });

  group('WpsCloudProvider', () {
    late FakeCloudHttp http;
    late WpsCloudProvider provider;

    setUp(() {
      http = FakeCloudHttp();
      provider = WpsCloudProvider(
        http,
        wait: (_) async {},
        clock: () => DateTime.utc(2024, 7, 3, 9, 46, 40),
      );
      http.json('GET', 'account.wps.cn/api/v3/mine', {'userid': 123456789});
      http.json('POST', '$_api/notesvr/get/web-config', {
        'aesPassword': _aesPassword,
      });
    });

    test('probe reads the account and sends X-user-key afterwards', () async {
      expect(await provider.probe(), 'wps:123456789');
      final config = http.requests.last;
      expect(config.headers['X-user-key'], '123456789');
      expect(config.headers['Origin'], 'https://note.wps.cn');
      expect(config.json, {'test': 'test'});

      http.json('POST', '$_api/notesvr/get/web-config', {
        'result': 'userNotLogin',
      });
      await expectLater(
        WpsCloudProvider(http).probe(),
        throwsA(
          isA<CloudNoteException>().having(
            (error) => error.failure,
            'failure',
            CloudNoteFailure.sessionExpired,
          ),
        ),
      );
    });

    test(
      'lists every scope, dedupes and reads inline and long bodies',
      () async {
        http.json('POST', '$_api/notesvr/get/notegroup', {
          'noteGroups': [
            {'groupId': 'aaaa', 'groupName': '工作', 'valid': 1},
          ],
        });
        http.json(
          'GET',
          '$_api/notesvr/v2/user/123456789/home/startindex/0/rows/50/notes',
          {
            'webNotes': [
              {
                'noteId': 'n1',
                'title': _encEmpty,
                'summary': _encSummary,
                'groupId': '',
                'createTime': 1720000000000,
              },
              {
                'noteId': 'trash',
                'title': '',
                'summary': '',
                'createTime': 1720000000000,
              },
            ],
          },
        );
        http.on('POST', '$_api/notesvr/web/getnotes/group', (request) {
          expect(request.json, {
            'uid': '123456789',
            'rows': 50,
            'startIndex': 0,
            'groupId': 'aaaa',
          });
          return jsonResponse({
            'webNotes': [
              {
                'noteId': 'n2',
                'title': '',
                'summary': _encLongSummary,
                'groupId': 'aaaa',
                'createTime': 1720000000000,
              },
              {
                'noteId': 'n1',
                'title': _encEmpty,
                'summary': _encSummary,
                'createTime': 1720000000000,
              },
            ],
          });
        });
        http.json('POST', '$_api/notesvr/web/getnotes/remind', {
          'webNotes': [],
        });
        http.on('POST', '$_api/notesvr/get/notebody', (request) {
          final id = ((request.json! as Map)['noteIds'] as List).single;
          return jsonResponse({
            'noteBodies': [
              switch (id) {
                'n1' => {
                  'noteId': 'n1',
                  'bodyType': 0,
                  'valid': 1,
                  'contentUpdateTime': 1720000001000,
                  'body': _encBody,
                },
                'n2' => {
                  'noteId': 'n2',
                  'bodyType': 1,
                  'valid': 1,
                  'body': _encLongKey,
                },
                _ => {'noteId': id, 'bodyType': 0, 'valid': 2, 'body': ''},
              },
            ],
          });
        });
        http.json('POST', '$_api/s3/requestdownload', _storageConfig);
        http.on(
          'GET',
          '$_s3/notes/u123/0123456789abcdef0123456789abcdef.encrypted',
          (request) {
            expect(request.withCookies, isFalse);
            expect(
              request.headers['Authorization'],
              startsWith('AWS4-HMAC-SHA256'),
            );
            return bytesResponse(base64.decode(_longObject));
          },
        );

        final notes = await provider.fetchNotes((_, _) {});

        final [first, second] = notes;
        expect(first.id, 'n1');
        expect(first.title, '购物清单');
        expect(first.folder, isNull);
        expect(
          first.updatedAt,
          DateTime.fromMillisecondsSinceEpoch(1720000001000),
        );
        expect(first.attachments.map((item) => item.reference), [
          '0123456789abcdef0123456789abcdef',
          'fedcba9876543210fedcba9876543210',
        ]);
        expect(second.title, '长正文标题');
        expect(second.folder, '工作');
        final writer = JournalDeltaWriter();
        second.writeBody(writer, (_) => null);
        expect(writer.build().contentText, '长正文\n第一段');
      },
    );

    test('downloads 32-hex attachment keys from S3 only', () async {
      http.json('POST', '$_api/s3/requestdownload', _storageConfig);
      http.on(
        'GET',
        '$_s3/notes/u123/0123456789abcdef0123456789abcdef',
        (_) => bytesResponse(fakeJpeg),
      );
      await provider.probe();
      expect(
        await provider.download(
          const CloudAttachment(
            id: 'x',
            name: 'x',
            reference: '0123456789abcdef0123456789abcdef',
          ),
        ),
        fakeJpeg,
      );
      await expectLater(
        provider.download(
          const CloudAttachment(id: 'x', name: 'x', reference: 'abc/def'),
        ),
        throwsA(isA<CloudNoteException>()),
      );
    });
  });
}
