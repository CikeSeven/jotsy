import 'package:html/dom.dart' as dom;
import 'package:meta/meta.dart';
import 'package:pointycastle/export.dart' show RSAPublicKey;

import 'journal_import_cloud.dart';
import 'journal_import_cloud_envelope.dart';
import 'journal_import_cloud_html.dart';
import 'journal_import_cloud_http.dart';
import 'journal_import_models.dart';

/// OPPO 笔记（云服务网页版 Connect v2）的只读客户端，协议依据参考实现
/// （笔记互迁 `providers/oppo.py`、`oppo_files.py`、`oppo_wire.py`）：
///
/// - 接口源 `https://owork-api-cn.oppo.com`，请求带登录后的 Cookie 与
///   `Referer: https://cloud.oppo.com/`；
/// - 账号 `GET /owork-server/web/account/v1/userInfo`（明文，`data.ssoId`）；
/// - 笔记接口都是 `POST /owork-server/web/note/v2/<名称>`，请求体与响应的
///   `data` 都套 [OppoEnvelope]（每个请求一把新的 AES 会话密钥）：
///   分组 `group-list-new`、列表 `list`（每页 50，`hasMore` 翻页，条数须与
///   `totalCount` 一致）、详情 `info`（`version` 为空串取完整正文）；
/// - 正文 `rawText` 是 tiptap 风格 HTML：待办为
///   `ul[data-type=taskList] > li[data-checked]`，图片为
///   `<img src attachid>`，高亮为 `span.highlight_color_<颜色>`，对齐、颜色
///   与字号是内联样式；附件对应 `attachments` 的项，文件经
///   `GET …/file-download/<文件 ID>` 下载（不套信封）。参考实现只验证过
///   图片（`type == 0`），录音、文件等其他类型同样按文件 ID 下载，下载不到
///   的计入缺失，正文没有引用的追加在末尾；
/// - 手写笔记是专有格式，不读取，只经 `paint_note/v2/list` 统计篇数提示跳过。
class OppoCloudProvider implements CloudNoteProvider {
  OppoCloudProvider(
    this.http, {
    Future<void> Function(Duration)? wait,
    this.envelopeKey,
  }) : _api = CloudNoteTransport(
         origin,
         http,
         headers: const {'Referer': 'https://cloud.oppo.com/'},
         wait: wait,
       );

  static const String origin = 'https://owork-api-cn.oppo.com';
  static const String _prefix = '/owork-server';

  final CloudNoteHttp http;
  final CloudNoteTransport _api;

  /// 只供测试替换厂商公钥（测试持有对应私钥以模拟服务端）。
  @visibleForTesting
  final RSAPublicKey? envelopeKey;

  @override
  final CloudReadIssues issues = CloudReadIssues();

  static Object? _data(Object? payload) {
    if (payload is! Map ||
        (payload['code'] != 0 && payload['code'] != '0') ||
        !payload.containsKey('data')) {
      throw const CloudNoteException(CloudNoteFailure.rejected, 'oppo code');
    }
    return payload['data'];
  }

  Future<Object?> _encrypted(
    String path,
    Object? data, {
    Map<String, String> query = const {},
  }) async {
    final envelope = OppoEnvelope(
      data ?? const <String, Object?>{},
      publicKey: envelopeKey,
    );
    final payload = await _api.json(
      'POST',
      '$_prefix$path',
      query: query,
      jsonBody: envelope.payload,
    );
    return _data(envelope.decrypt(_data(payload)));
  }

  @override
  Future<String> probe() async {
    final user = _data(
      await _api.json('GET', '$_prefix/web/account/v1/userInfo'),
    );
    final id = user is Map ? user['ssoId'] : null;
    if ((id is! String && id is! int) || '$id'.isEmpty) {
      throw const CloudNoteException(CloudNoteFailure.sessionExpired);
    }
    await _encrypted('/web/note/v2/group-list-new', null);
    return 'oppo:$id';
  }

  @override
  Future<List<CloudNote>> fetchNotes(CloudProgress onProgress) async {
    final groups = await _encrypted('/web/note/v2/group-list-new', null);
    if (groups is! List) {
      throw const CloudNoteException(
        CloudNoteFailure.protocolChanged,
        'oppo groups',
      );
    }
    // “全部笔记”视图的分组 GUID 为空串，不是真实分组。
    final folders = <String, String>{
      for (final group in groups)
        if (group is Map &&
            group['groupGuid'] is String &&
            (group['groupGuid'] as String).isNotEmpty)
          group['groupGuid'] as String: '${group['groupName'] ?? ''}',
    };

    final rows = <Map<String, Object?>>[];
    final seen = <String>{};
    int? total;
    for (var page = 1; ; page++) {
      if (page > 10000) {
        throw const CloudNoteException(CloudNoteFailure.protocolChanged);
      }
      final listing = await _encrypted('/web/note/v2/list', {
        'status': 0,
        'queryFields': <Object?>[],
        'pageNo': page,
        'pageSize': 50,
        'recordType': 'hypertext_item_info',
        'sortFieldList': [
          {'field': 'topTime', 'sortType': 'desc'},
          {'field': 'updateTime', 'sortType': 'desc'},
        ],
      });
      if (listing is! Map ||
          listing['records'] is! List ||
          listing['totalCount'] is! int ||
          listing['hasMore'] is! bool) {
        throw const CloudNoteException(
          CloudNoteFailure.protocolChanged,
          'oppo list',
        );
      }
      total ??= listing['totalCount'] as int;
      for (final row in listing['records'] as List) {
        final id = row is Map ? row['recordId'] : null;
        if (id is! String || id.isEmpty || !seen.add(id)) {
          throw const CloudNoteException(
            CloudNoteFailure.protocolChanged,
            'oppo duplicate',
          );
        }
        rows.add((row as Map).cast<String, Object?>());
      }
      onProgress(rows.length, total);
      if (listing['hasMore'] != true) break;
      if ((listing['records'] as List).isEmpty) {
        throw const CloudNoteException(
          CloudNoteFailure.protocolChanged,
          'oppo stalled',
        );
      }
    }
    if (rows.length != total) {
      throw const CloudNoteException(
        CloudNoteFailure.protocolChanged,
        'oppo count',
      );
    }
    issues.skip(JournalSkipReason.unsupported, await _handwrittenCount());

    final notes = <CloudNote>[];
    for (final (index, row) in rows.indexed) {
      final id = row['recordId'] as String;
      final detail = await _encrypted(
        '/web/note/v2/info',
        {'recordId': id, 'status': 0, 'version': ''},
        query: {'recordId': id, 'version': ''},
      );
      if (detail is Map && detail['recordId'] == id) {
        final note = _parseDetail(detail.cast<String, Object?>(), folders);
        if (note != null) notes.add(note);
      } else {
        issues.skip(JournalSkipReason.unreadable);
      }
      onProgress(index + 1, rows.length);
    }
    return notes;
  }

  /// 手写笔记是另一类记录，不在上面的列表里；按参考实现的统计请求取篇数，
  /// 只用于提示跳过了多少。统计失败不影响读取（登录失效等仍然中止）。
  Future<int> _handwrittenCount() async {
    try {
      final listing = await _encrypted('/web/paint_note/v2/list', {
        'status': 0,
        'pageNo': 1,
        'pageSize': 1,
        'recordType': 'paint_note_item_info',
        'queryFields': [
          {
            'field': 'sysVersion',
            'comparatorType': 'greater_than',
            'value': '0',
          },
        ],
        'sortFieldList': [
          {'field': 'sysVersion', 'sortType': 'desc'},
        ],
      });
      final count = listing is Map ? listing['totalCount'] : null;
      return count is int && count > 0 ? count : 0;
    } on CloudNoteException catch (error) {
      if (isFatalCloudFailure(error.failure)) rethrow;
      return 0;
    }
  }

  /// 回收站中的笔记返回 null；结构认不出来的记入 [issues] 并返回 null。
  CloudNote? _parseDetail(
    Map<String, Object?> detail,
    Map<String, String> folders,
  ) {
    if (detail['status'] != 0) return null;
    final html = detail['rawText'];
    if (html is! String) {
      issues.skip(JournalSkipReason.unreadable);
      return null;
    }
    final attachments = <CloudAttachment>[
      for (final item in (detail['attachments'] as List?) ?? const [])
        if (item is Map &&
            item['id'] != null &&
            item['url'] is String &&
            RegExp(r'^/?[A-Za-z0-9_-]{1,150}$').hasMatch(item['url'] as String))
          CloudAttachment(
            id: '${item['id']}',
            name: _attachmentName(item),
            mime: _string(item['mimeType']) ?? _string(item['mime']),
            reference: (item['url'] as String).replaceFirst('/', ''),
          ),
    ];
    final ids = {for (final item in attachments) item.id};
    final created = _time(detail['createTime']);
    if (created == null) {
      issues.skip(JournalSkipReason.unreadable);
      return null;
    }
    return CloudNote(
      id: detail['recordId'] as String,
      title: detail['rawTitle'] is String ? detail['rawTitle'] as String : '',
      createdAt: created,
      updatedAt: _time(detail['updateTime']),
      folder: folders[detail['groupGuid']],
      attachments: attachments,
      writeBody: (writer, resolve) => writeCloudHtml(
        writer,
        html.isEmpty ? '<p></p>' : html,
        resolve,
        prepare: _normalize,
        imageId: (image) {
          final attachId = image.attributes['attachid'];
          if (ids.contains(attachId)) return attachId;
          final src = image.attributes['src'];
          return ids.contains(src) ? src : null;
        },
      ),
    );
  }

  /// 附件的文件名：带扩展名的原文件名优先，否则用文件 ID（类型再按 MIME
  /// 与文件头判断）。
  static String _attachmentName(Map item) {
    for (final key in const ['fileName', 'name', 'title']) {
      final name = _string(item[key]);
      if (name != null && name.contains('.')) return name;
    }
    return (item['url'] as String).replaceFirst('/', '');
  }

  static String? _string(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  /// 高亮类 `highlight_color_<颜色>` 改写成背景色（与参考实现写入时用的
  /// 40% 不透明度一致），认不出的颜色名用统一的高亮色。
  static void _normalize(dom.Element root) {
    const prefix = 'highlight_color_';
    for (final node in root.querySelectorAll('[class*="$prefix"]')) {
      final name = node.classes
          .firstWhere((value) => value.startsWith(prefix), orElse: () => prefix)
          .substring(prefix.length);
      final rgb = _highlights[name] ?? '255, 193, 7';
      node.attributes['style'] = [
        node.attributes['style'] ?? '',
        'background-color: rgba($rgb, 0.4)',
      ].where((part) => part.isNotEmpty).join(';');
    }
  }

  static const Map<String, String> _highlights = {
    'yellow': '255, 226, 39',
    'orange': '255, 159, 64',
    'red': '255, 99, 99',
    'pink': '255, 128, 171',
    'purple': '179, 136, 255',
    'blue': '79, 166, 255',
    'cyan': '64, 200, 224',
    'green': '96, 200, 120',
  };

  @override
  Future<List<int>> download(CloudAttachment attachment) async {
    final response = await _api.request(
      'GET',
      '$_prefix/web/note/v2/file-download/${attachment.reference}',
    );
    final type = response.headers['content-type'] ?? '';
    if (type.startsWith('text/html') ||
        type.startsWith('application/json') ||
        response.bytes.isEmpty) {
      throw const CloudNoteException(
        CloudNoteFailure.rejected,
        'oppo file body',
      );
    }
    return response.bytes;
  }

  static DateTime? _time(Object? value) => value is num && value > 0
      ? DateTime.fromMillisecondsSinceEpoch(value.round())
      : null;
}
