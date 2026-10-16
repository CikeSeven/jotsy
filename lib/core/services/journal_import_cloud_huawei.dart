import 'dart:convert';
import 'dart:math';

import 'package:html/dom.dart' as dom;

import 'journal_import_cloud.dart';
import 'journal_import_cloud_html.dart';
import 'journal_import_cloud_http.dart';

/// 华为备忘录（云空间 cloud.huawei.com）的只读客户端，协议依据参考实现
/// （笔记互迁 `providers/huawei.py`、`huawei_transport.py`、
/// `huawei_files.py`、`huawei_groups.py`）：
///
/// - 备忘录接口 `POST /notepad/<名称>`，请求体附 `traceId`（
///   `03133_02_<秒>_<8 位 1~9 数字>`），成功为 `Result.code == "0"`；
///   分组 `notetag/query`、目录 `simplenote/query`（单次请求即完整目录）、
///   详情 `note/query`（`rspInfo.data` 与其中 `content.data5` 都是 JSON
///   字符串，笔记 ID 用 `rspInfo.guid`）；
/// - 非下载请求带 `CSRFToken` 头：优先用上一次响应头轮换下来的值（先做
///   encodeURIComponent，并写回 `shareToken` Cookie），否则用 `shareToken`
///   Cookie，再否则用 `CSRFToken` Cookie；
/// - 正文 `html_content` 为 `<note><element type="Text|Bullet|Attachment">`
///   序列：Bullet 首字符 1/0 表示已完成/未完成，Attachment 的路径文件名
///   对应附件 `usage`；编辑器把标题作为第一段写入正文，与标题相同则去掉；
/// - 附件需账号使用新版文件代理（`getAboutGet` 为 `dataVersion=2.0`，
///   `getCommonParam` 给出版本号），每篇笔记下载前先 `preProcess`，再经
///   `GET /proxy/v1/download/<整段编码的路由>?version=` 下载原始字节。
class HuaweiCloudProvider implements CloudNoteProvider {
  HuaweiCloudProvider(
    this.http, {
    Future<void> Function(Duration)? wait,
    Random? random,
  }) : _api = CloudNoteTransport(
         origin,
         http,
         headers: const {
           'Referer': 'https://cloud.huawei.com/home',
           'Origin': 'https://cloud.huawei.com',
         },
         wait: wait,
       ),
       _random = random ?? Random.secure();

  static const String origin = 'https://cloud.huawei.com';
  static const String _host = 'cloud.huawei.com';

  final CloudNoteHttp http;
  final CloudNoteTransport _api;
  final Random _random;

  /// 最近一次响应头轮换下来的 CSRF 令牌（已编码）。
  String? _csrf;
  String? _fileVersion;
  String? _preparedNote;

  String _traceId() =>
      '03133_02_${DateTime.now().millisecondsSinceEpoch ~/ 1000}_'
      '${List.generate(8, (_) => 1 + _random.nextInt(9)).join()}';

  /// 非下载请求。`/notepad` 只在请求体带 traceId（另加 no-cache）；
  /// `/html` 与 `/proxyserver` 用 `x-hw-trace-id` 头，`/html` 的请求体
  /// 另带一个 traceId。随后按 CSRF 令牌规则附带并学习新令牌。
  Future<Map<String, Object?>> _post(
    String path,
    Map<String, Object?> body, {
    bool traceInBody = false,
  }) async {
    final notepad = path.startsWith('/notepad/');
    final rotated = _csrf;
    if (rotated != null) http.setCookie('shareToken', rotated, _host);
    final token =
        rotated ?? http.cookie('shareToken') ?? http.cookie('CSRFToken');
    final before = http.cookie('shareToken');
    final response = await _api.request(
      'POST',
      path,
      headers: {
        'Content-Type': 'application/json;charset=utf-8',
        if (notepad) 'Cache-Control': 'no-cache',
        if (!notepad) 'x-hw-trace-id': _traceId(),
        'CSRFToken': ?token,
      },
      body: utf8.encode(
        jsonEncode({...body, if (traceInBody) 'traceId': _traceId()}),
      ),
    );
    final header = response.headers['csrftoken'];
    if (header != null && header.isNotEmpty) {
      _csrf = Uri.encodeComponent(header);
      http.setCookie('shareToken', _csrf!, _host);
    } else if (http.cookie('shareToken') case final current?
        when current != before) {
      _csrf = current;
    }
    return decodeCloudJson(response.text);
  }

  /// 备忘录接口：`Result.code` 为字符串 `"0"` 且带 `rspInfo` 对象。
  Future<Map<String, Object?>> _notepad(
    String name,
    Map<String, Object?> body,
  ) async {
    final payload = await _post('/notepad/$name', body, traceInBody: true);
    final result = payload['Result'];
    if (result is! Map || result['code'] != '0' || payload['rspInfo'] is! Map) {
      throw CloudNoteException(CloudNoteFailure.rejected, 'huawei $name');
    }
    return payload;
  }

  @override
  Future<String> probe() async {
    var uid = http.cookie('userId');
    if (uid == null || uid.isEmpty) {
      // 不少会话登录后没有 userId Cookie，官方网页改从账号参数接口取。
      final param = await _post(
        '/html/getCommonParam',
        const {},
        traceInBody: true,
      );
      final login = param['isLogin'];
      if (param['code'] != 0 || (login != 1 && login != '1')) {
        throw const CloudNoteException(CloudNoteFailure.sessionExpired);
      }
      uid = param['userid'] is String ? param['userid'] as String : null;
      if (uid == null || uid.isEmpty) {
        throw const CloudNoteException(CloudNoteFailure.sessionExpired);
      }
    }
    await _notepad('notetag/query', const {'index': 0});
    return 'huawei:$uid';
  }

  @override
  Future<List<CloudNote>> fetchNotes(CloudProgress onProgress) async {
    final folders = _folders(
      await _notepad('notetag/query', const {'index': 0}),
    );
    final listing = await _notepad('simplenote/query', const {
      'index': 0,
      'status': 0,
      'guids': '',
    });
    final list = (listing['rspInfo'] as Map)['noteList'];
    if (list is! List) {
      throw const CloudNoteException(
        CloudNoteFailure.protocolChanged,
        'huawei list',
      );
    }
    final rows = <({String guid, String kind})>[];
    final seen = <String>{};
    for (final row in list) {
      final guid = row is Map ? row['guid'] : null;
      if (guid is! String || guid.isEmpty || !seen.add(guid)) {
        throw const CloudNoteException(CloudNoteFailure.protocolChanged);
      }
      final kind = '${(row as Map)['kind'] ?? 'note'}';
      // 只有 note 的格式已核实；newnote/task 等专有类型不读取。
      if (kind == 'note') rows.add((guid: guid, kind: kind));
    }
    onProgress(0, rows.length);

    final notes = <CloudNote>[];
    for (final (index, row) in rows.indexed) {
      final detail = await _notepad('note/query', {
        'ctagNoteInfo': '${listing['ctagNoteInfo'] ?? ''}',
        'startCursor': '${listing['startCursor'] ?? ''}',
        'guid': row.guid,
        'kind': row.kind,
      });
      final info = (detail['rspInfo'] as Map).cast<String, Object?>();
      if (info['guid'] != row.guid) {
        throw const CloudNoteException(
          CloudNoteFailure.protocolChanged,
          'huawei detail',
        );
      }
      final note = _parseDetail(info, folders);
      if (note != null) notes.add(note);
      onProgress(index + 1, rows.length);
    }
    return notes;
  }

  /// 分组：`rspInfo.noteList[].data` 是 JSON 字符串，新版包在 `content`
  /// 里；只取未删除的普通分组（`type == 2`）。
  static Map<String, String> _folders(Map<String, Object?> payload) {
    final folders = <String, String>{};
    final rows = (payload['rspInfo'] as Map)['noteList'];
    for (final row in rows is List ? rows : const []) {
      final raw = row is Map ? row['data'] : null;
      if (raw is! String) continue;
      Object? tag;
      try {
        tag = jsonDecode(raw);
      } on FormatException {
        continue;
      }
      if (tag is Map && tag['content'] is Map) tag = tag['content'];
      if (tag is! Map || tag['uuid'] == null || tag['name'] is! String) {
        continue;
      }
      if (tag['type'] == 2 && (tag['delete_flag'] ?? 0) == 0) {
        folders['${tag['uuid']}'] = tag['name'] as String;
      }
    }
    return folders;
  }

  CloudNote? _parseDetail(
    Map<String, Object?> info,
    Map<String, String> folders,
  ) {
    final Object? data;
    try {
      data = info['data'] is String ? jsonDecode(info['data'] as String) : null;
    } on FormatException {
      return null;
    }
    final content = data is Map ? data['content'] : null;
    if (content is! Map) return null;
    final html = content['html_content'];
    if (html is! String || (content['delete_flag'] ?? 0) != 0) return null;
    final created = _time(content['created']);
    if (created == null) return null;

    var title = content['title'] is String
        ? (content['title'] as String).split('\n').first
        : '';
    final rawTitle = content['data5'];
    if (rawTitle is String && rawTitle.isNotEmpty) {
      try {
        final edited = jsonDecode(rawTitle);
        if (edited is Map &&
            edited['data2'] == 'edit' &&
            edited['data1'] is String) {
          title = edited['data1'] as String;
        }
      } on FormatException {
        // 标题数据损坏时沿用目录标题。
      }
    }

    final guid = info['guid'] as String;
    final idPattern = RegExp(r'^[A-Za-z0-9_$-]{1,150}$');
    final attachments = <CloudAttachment>[];
    for (final item in (info['attachments'] as List?) ?? const []) {
      if (item is! Map ||
          item['usage'] is! String ||
          !idPattern.hasMatch('${item['assetId']}') ||
          !idPattern.hasMatch('${item['versionId']}') ||
          !idPattern.hasMatch(guid)) {
        continue;
      }
      attachments.add(
        CloudAttachment(
          id: '${item['assetId']}',
          name: item['usage'] as String,
          reference: (
            note: guid,
            asset: '${item['assetId']}',
            version: '${item['versionId']}',
            length: item['resourceLength'] is int
                ? item['resourceLength'] as int
                : null,
          ),
        ),
      );
    }
    final byName = {for (final item in attachments) item.name: item.id};
    final folder = content['tag_id'];
    return CloudNote(
      id: guid,
      title: title,
      createdAt: created,
      updatedAt: _time(content['modified']),
      folder: folder == null ? null : folders['$folder'],
      attachments: attachments,
      writeBody: (writer, resolve) => writeCloudHtml(
        writer,
        html,
        resolve,
        prepare: (root) => _normalize(root, byName, title),
      ),
    );
  }

  /// 把 `<element>` 序列改写成通用 HTML：Text → `<p>`（只有空 hw_font 的
  /// 段落是空行），Bullet → 待办 `<li data-checked>`，Attachment → 图片，
  /// 其他类型按文字段落保留；与标题相同的第一段去掉。
  static void _normalize(
    dom.Element root,
    Map<String, String> attachments,
    String title,
  ) {
    final elements = root.getElementsByTagName('element');
    for (final (index, element) in elements.indexed) {
      final type = element.attributes['type'] ?? 'Text';
      final dom.Element replacement;
      switch (type) {
        case 'Bullet':
          final marker = element.nodes.firstOrNull;
          final text = marker is dom.Text ? marker.data : '';
          final checked = text.startsWith('1');
          if (marker is dom.Text &&
              (text.startsWith('1') || text.startsWith('0'))) {
            marker.data = text.substring(1);
          }
          replacement = dom.Element.tag('li')
            ..attributes['data-checked'] = '$checked';
          element.reparentChildren(replacement);
        case 'Attachment':
          final name = element.text.trim().split('/').last;
          final id = attachments[name];
          replacement = id == null
              ? dom.Element.tag('span')
              : (dom.Element.tag('img')..attributes['src'] = id);
        default:
          replacement = dom.Element.tag('p');
          final empty =
              element.text.trim().isEmpty &&
              element.getElementsByTagName('br').isEmpty;
          if (empty) {
            replacement.append(dom.Element.tag('br'));
          } else {
            element.reparentChildren(replacement);
          }
          if (index == 0 &&
              title.trim().isNotEmpty &&
              replacement.text.trim() == title.trim()) {
            element.remove();
            continue;
          }
      }
      element.replaceWith(replacement);
    }
  }

  @override
  Future<List<int>> download(CloudAttachment attachment) async {
    final reference =
        attachment.reference!
            as ({String note, String asset, String version, int? length});
    final version = _fileVersion ??= await _fileProxyVersion();
    if (_preparedNote != reference.note) {
      _preparedNote = null;
      final prepared = await _post(
        '/proxyserver/driveFileProxy/preProcess',
        const {
          'needToSignUrl': '',
          'httpMethod': 'GET',
          'generateSignFlag': false,
        },
      );
      if (prepared['code'] != '0') {
        throw const CloudNoteException(
          CloudNoteFailure.rejected,
          'huawei preProcess',
        );
      }
      _preparedNote = reference.note;
    }
    final route =
        '/v2/dataSync/callback/v1/1001/kind/note/record/'
        '${Uri.encodeComponent(reference.note)}/assets/'
        '${Uri.encodeComponent(reference.asset)}/revisions/'
        '${Uri.encodeComponent(reference.version)}';
    try {
      final response = await _api.requestUrl(
        'GET',
        Uri.parse(
          '$origin/proxy/v1/download/${Uri.encodeComponent(route)}'
          '?version=${Uri.encodeQueryComponent(version)}',
        ),
        headers: {'x-hw-trace-id': _traceId(), 'version': version},
      );
      final bytes = response.bytes;
      if (bytes.isEmpty ||
          (reference.length != null && bytes.length != reference.length)) {
        throw const CloudNoteException(
          CloudNoteFailure.rejected,
          'huawei file size',
        );
      }
      return bytes;
    } on CloudNoteException {
      _preparedNote = null;
      rethrow;
    }
  }

  /// 新版文件代理的版本号；账号未启用新版附件协议时无法下载附件。
  Future<String> _fileProxyVersion() async {
    final about = await _post('/html/getAboutGet', const {
      'moduleType': 'notepad',
    }, traceInBody: true);
    final param = await _post(
      '/html/getCommonParam',
      const {},
      traceInBody: true,
    );
    final version = param['fileProxyGrayStrategyVersionValue'];
    if (about['code'] != 0 ||
        about['dataSwitch'] != 1 ||
        about['dataVersion'] != 'dataVersion=2.0' ||
        param['code'] != 0 ||
        version is! String) {
      throw const CloudNoteException(
        CloudNoteFailure.rejected,
        'huawei file proxy',
      );
    }
    return version;
  }

  static DateTime? _time(Object? value) => value is num && value > 0
      ? DateTime.fromMillisecondsSinceEpoch(value.round())
      : null;
}
