import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:meta/meta.dart';
import 'package:pointycastle/export.dart' show RSAPublicKey;

import 'journal_import_cloud.dart';
import 'journal_import_cloud_envelope.dart';
import 'journal_import_cloud_html.dart';
import 'journal_import_cloud_http.dart';

/// vivo 笔记（云服务网页版 pc.vivo.com.cn）的只读客户端，协议依据参考
/// 实现（笔记互迁 `providers/vivo.py`、`vivo_wire.py`）：
///
/// - 接口 `/note-api/…`，成功为 `code == 0` 且带 `data`；目录与正文请求
///   体为 `{"jvq_param": <VivoEnvelope 加密的 JSON>}`，响应在
///   `jvq_response` 中同样加密；
/// - 账号 `GET account/getUserCookie` 取 openId 与 vivotoken，之后的请求
///   带 `token`/`openId`/`source: 1` 头；`account/getUserInfo` 给出 userId；
/// - 分组 `noteBook/getList`；目录 `note/getAllNote/v2`（每页 50，以
///   `chunkLowTime` 作下一页游标，条数须与 `statistics/note` 一致）；正文
///   `note/getContent/v2`；含附件时 `note/getIncludeItem/v2` 列出资源；
/// - 只读普通笔记（`type == 1`），`deleted == 1` 才是有效笔记（与其他平台
///   相反），加密笔记跳过；
/// - 正文是带 `vnote-*` 自定义标签的 HTML：`vnote-todo > todo-item[done]`
///   待办、`vnote-image/audio/video/doc` 附件（按 guid 或文件名对应资源）；
/// - 附件经 `getStsToken.do` 取得令牌，从 `clouddisk-*.vivo.com.cn` 的
///   `/api/file/webdisk/source/<resourceKey>` 下载原件（不带账号 Cookie），
///   大小须与记录一致。
class VivoCloudProvider implements CloudNoteProvider {
  VivoCloudProvider(
    this.http, {
    Future<void> Function(Duration)? wait,
    this.envelopeKey,
  }) : _api = CloudNoteTransport(origin, http, wait: wait),
       _wait = wait;

  static const String origin = 'https://pc.vivo.com.cn';

  final CloudNoteHttp http;
  final CloudNoteTransport _api;
  final Future<void> Function(Duration)? _wait;

  /// 只供测试替换厂商公钥（测试持有对应私钥以模拟服务端）。
  @visibleForTesting
  final RSAPublicKey? envelopeKey;

  late final VivoEnvelope _envelope = VivoEnvelope(publicKey: envelopeKey);
  Map<String, String> _session = const {};
  String? _userId;
  String? _sts;

  Future<Object?> _call(
    String method,
    String path, {
    Object? data,
    bool encrypted = false,
  }) async {
    final request = data == null
        ? null
        : encrypted
        ? {'jvq_param': _envelope.encrypt(jsonEncode(data))}
        : data;
    var payload = await _api.json(
      method,
      '/note-api$path',
      headers: _session,
      jsonBody: request,
    );
    final wrapped = payload['jvq_response'];
    if (wrapped is String && wrapped.isNotEmpty) {
      payload = decodeCloudJson(_envelope.decrypt(wrapped));
    }
    if (payload['code'] != 0 || !payload.containsKey('data')) {
      throw CloudNoteException(CloudNoteFailure.rejected, 'vivo $path');
    }
    return payload['data'];
  }

  @override
  Future<String> probe() async {
    _session = const {};
    final session = await _call('GET', '/account/getUserCookie');
    final openId = session is Map
        ? session['vivo_account_cookie_iqoo_openid']
        : null;
    final token = session is Map
        ? session['vivo_account_cookie_iqoo_vivotoken']
        : null;
    if (openId is! String ||
        openId.isEmpty ||
        token is! String ||
        token.isEmpty) {
      throw const CloudNoteException(CloudNoteFailure.sessionExpired);
    }
    _session = {'token': token, 'openId': openId, 'source': '1'};
    final user = await _call(
      'POST',
      '/account/getUserInfo',
      data: {'openId': openId},
    );
    final id = user is Map ? user['userId'] : null;
    if (id == null || '$id'.isEmpty) {
      throw const CloudNoteException(CloudNoteFailure.sessionExpired);
    }
    _userId = '$id';
    await _statistics();
    return 'vivo:$id';
  }

  Future<int> _statistics() async {
    final stats = await _call(
      'POST',
      '/statistics/note',
      data: const {'type': 0, 'encryptType': null},
    );
    final total = stats is Map ? stats['totalNotes'] : null;
    if (total is! int || total < 0) {
      throw const CloudNoteException(
        CloudNoteFailure.protocolChanged,
        'vivo statistics',
      );
    }
    return total;
  }

  @override
  Future<List<CloudNote>> fetchNotes(CloudProgress onProgress) async {
    if (_userId == null) await probe();
    final total = await _statistics();
    final books = await _call(
      'POST',
      '/noteBook/getList',
      data: const {'maxEntries': 100000},
    );
    if (books is! List) {
      throw const CloudNoteException(
        CloudNoteFailure.protocolChanged,
        'vivo books',
      );
    }
    final folders = <String, String>{
      for (final book in books)
        if (book is Map && book['guid'] is String)
          book['guid'] as String: '${book['nameNew'] ?? book['name'] ?? ''}',
    };

    final rows = <Map<String, Object?>>[];
    final seen = <String>{};
    int? cursor;
    for (var page = 1; ; page++) {
      if (page > 10000) {
        throw const CloudNoteException(CloudNoteFailure.protocolChanged);
      }
      final data = await _call(
        'POST',
        '/note/getAllNote/v2',
        data: {
          'maxEntries': 50,
          'pageNum': page,
          'sortField': 0,
          'syncProtocolVersion': 200,
          if (page > 1) 'beforeTimeMs': cursor,
        },
        encrypted: true,
      );
      final batch = data is Map ? data['notes'] : null;
      if (batch is! List) {
        throw const CloudNoteException(
          CloudNoteFailure.protocolChanged,
          'vivo list',
        );
      }
      for (final row in batch) {
        final id = row is Map ? row['guid'] : null;
        if (id is! String || id.isEmpty || !seen.add(id)) {
          throw const CloudNoteException(
            CloudNoteFailure.protocolChanged,
            'vivo duplicate',
          );
        }
        rows.add((row as Map).cast<String, Object?>());
      }
      onProgress(rows.length, total);
      if (batch.length < 50) break;
      final next = (data as Map)['chunkLowTime'];
      if (next is! int || next == cursor) {
        throw const CloudNoteException(
          CloudNoteFailure.protocolChanged,
          'vivo cursor',
        );
      }
      cursor = next;
    }
    if (rows.length != total) {
      throw const CloudNoteException(
        CloudNoteFailure.protocolChanged,
        'vivo count',
      );
    }

    final notes = <CloudNote>[];
    for (final (index, row) in rows.indexed) {
      final note = await _readNote(row, folders);
      if (note != null) notes.add(note);
      onProgress(index + 1, rows.length);
    }
    return notes;
  }

  Future<CloudNote?> _readNote(
    Map<String, Object?> row,
    Map<String, String> folders,
  ) async {
    final guid = row['guid'] as String;
    if (!const [null, 0].contains(row['encryptType']) ||
        row['deleted'] != 1 ||
        row['type'] != 1) {
      return null;
    }
    if (row['userId'] == null || '${row['userId']}' != _userId) {
      throw const CloudNoteException(CloudNoteFailure.sessionExpired);
    }
    final created = _time(row['createTime']);
    if (created == null) return null;
    final body = await _call(
      'POST',
      '/note/getContent/v2',
      data: {'guid': guid},
      encrypted: true,
    );
    if (body is! String) return null;

    final attachments = <CloudAttachment>[];
    if (row['resources'] != null ||
        body.contains('vnote-') ||
        body.contains('<img')) {
      final detail = await _call(
        'POST',
        '/note/getIncludeItem/v2',
        data: {'guid': guid, 'syncProtocolVersion': 200},
        encrypted: true,
      );
      if (detail is! Map || detail['guid'] != guid) {
        throw const CloudNoteException(
          CloudNoteFailure.protocolChanged,
          'vivo resources',
        );
      }
      for (final resource in (detail['resources'] as List?) ?? const []) {
        if (resource is! Map ||
            resource['guid'] is! String ||
            resource['noteGuid'] != guid ||
            '${resource['userId']}' != _userId) {
          continue;
        }
        final mime = resource['mime'] is String
            ? (resource['mime'] as String).trim()
            : '';
        var name = '${resource['name'] ?? resource['guid']}';
        // `mime` 有时只是扩展名（如 `m4a`），文件名没有扩展名时补上。
        if (!mime.contains('/') &&
            RegExp(r'^[A-Za-z0-9]{1,6}$').hasMatch(mime) &&
            !RegExp(r'\.[A-Za-z0-9]{1,6}$').hasMatch(name)) {
          name = '$name.${mime.toLowerCase()}';
        }
        attachments.add(
          CloudAttachment(
            id: resource['guid'] as String,
            name: name,
            mime: mime.contains('/') ? mime : null,
            reference: resource.cast<String, Object?>(),
          ),
        );
      }
    }
    return CloudNote(
      id: guid,
      title: row['title'] is String ? row['title'] as String : '',
      createdAt: created,
      updatedAt: _time(row['updateTime']),
      folder: folders[row['noteBookGuid']],
      attachments: attachments,
      writeBody: (writer, resolve) => writeCloudHtml(
        writer,
        body,
        resolve,
        prepare: (root) => _normalize(root, attachments),
      ),
    );
  }

  /// 把 `vnote-*` 标签改写成通用 HTML；对应不上资源的附件标签移除，其他
  /// 专有标签按文字保留。
  static void _normalize(dom.Element root, List<CloudAttachment> attachments) {
    for (final node in root.querySelectorAll('*').toList()) {
      final tag = node.localName ?? '';
      if (!tag.startsWith('vnote-')) continue;
      switch (tag) {
        case 'vnote-todo':
          final list = dom.Element.tag('ul');
          for (final item in node.children.toList()) {
            if (item.localName != 'todo-item') continue;
            final li = dom.Element.tag('li')
              ..attributes['data-checked'] =
                  '${item.attributes['done'] == 'true'}';
            item.reparentChildren(li);
            list.append(li);
          }
          node.replaceWith(list);
        case 'vnote-divider':
          node.replaceWith(dom.Element.tag('hr'));
        case 'vnote-image' ||
            'vnote-audio' ||
            'vnote-audio2' ||
            'vnote-video' ||
            'vnote-doc':
          final guid = node.attributes['guid'];
          final filename = node.attributes['filename'] ?? '';
          final matching = attachments.where(
            (item) =>
                item.id == guid ||
                (filename.isNotEmpty && filename.contains(item.id)) ||
                item.name == filename,
          );
          node.replaceWith(
            matching.length == 1
                ? (dom.Element.tag('img')
                    ..attributes['src'] = matching.single.id)
                : dom.Element.tag('span'),
          );
        default:
          final span = dom.Element.tag('span');
          node.reparentChildren(span);
          node.replaceWith(span);
      }
    }
  }

  @override
  Future<List<int>> download(CloudAttachment attachment) async {
    final resource = attachment.reference! as Map<String, Object?>;
    _sts ??= await _stsToken();
    final domain = Uri.tryParse('${resource['domainAddr'] ?? ''}');
    final host = domain?.host.toLowerCase() ?? '';
    final key = resource['resourceKey'];
    final safe =
        domain != null &&
        (domain.scheme == 'https' || domain.scheme == 'http') &&
        host.startsWith('clouddisk-') &&
        host.endsWith('.vivo.com.cn') &&
        domain.userInfo.isEmpty &&
        !domain.hasPort &&
        (domain.path.isEmpty || domain.path == '/') &&
        !domain.hasQuery &&
        !domain.hasFragment &&
        key is String &&
        key.isNotEmpty;
    if (!safe) {
      throw const CloudNoteException(CloudNoteFailure.rejected, 'vivo host');
    }
    final response =
        await CloudNoteTransport('https://$host', http, wait: _wait).requestUrl(
          'GET',
          Uri.parse(
            'https://$host/api/file/webdisk/source/${Uri.encodeComponent(key)}'
            '?stsToken=${Uri.encodeQueryComponent(_sts!)}',
          ),
          withCookies: false,
        );
    final type = response.headers['content-type'] ?? '';
    final size = resource['resourceSize'];
    if (type.startsWith('application/json') ||
        type.startsWith('text/html') ||
        response.bytes.isEmpty ||
        (size is int && size > 0 && response.bytes.length != size)) {
      throw const CloudNoteException(
        CloudNoteFailure.rejected,
        'vivo file body',
      );
    }
    return response.bytes;
  }

  Future<String> _stsToken() async {
    final token = await _api.json(
      'POST',
      '/clouddisk-api/api/suite/web/meta/getStsToken.do',
      headers: _session,
      jsonBody: const {'tokenType': 1},
    );
    final data = token['data'];
    final value = data is Map ? data['stsToken'] : null;
    if (token['code'] != 0 || value is! String || value.isEmpty) {
      throw const CloudNoteException(CloudNoteFailure.rejected, 'vivo sts');
    }
    return value;
  }

  static DateTime? _time(Object? value) => value is num && value > 0
      ? DateTime.fromMillisecondsSinceEpoch(value.round())
      : null;
}
