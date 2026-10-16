import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:html/dom.dart' as dom;

import 'journal_import_cloud.dart';
import 'journal_import_cloud_html.dart';
import 'journal_import_cloud_http.dart';

/// 荣耀笔记（新荣耀账号，cloud.honor.com）的只读客户端，协议依据参考实现
/// （笔记互迁 `providers/honor.py`、`honor_html.py`、`honor_files.py`、
/// `honor_groups.py`）：
///
/// - 接口 `/portal/…`，请求头 `Csrftoken`（取自 `hc_CSRF_Token` Cookie）、
///   `x-hn-traceId`（随机 32 位十六进制）、`Device-Type: 1`，成功为
///   `code == 0` 且带 `data`；
/// - 账号 `user/info`；分组 `getFolderList`；目录 `getNoteList`（一次取全，
///   条数须与 `note/count` 一致）；详情 `noteDetail`，只读普通笔记
///   （`type == 2`），跳过上锁与回收站中的笔记；
/// - 正文是带 `h_n` 类名的私有 HTML（`Nb` 段落/`hlevel` 标题、`Na` 待办、
///   `Nd`/`Nh` 有序/无序列表、`Nc` 列表项、`Nr` 分隔线、`Ni[hid]` 图片，
///   行内 `font` 的 `La`~`Le` 类与 `hbgcolor`/`hlink` 属性表示格式）；
/// - 图片的原图与预览图成对存放：下载 `_original` 原图，附件 ID 用预览图
///   的 uuid（即正文里的 `hid`）；文件服务地址来自 `config/web`，下载后按
///   记录的大小与 SHA-256 校验。
class HonorCloudProvider implements CloudNoteProvider {
  HonorCloudProvider(
    this.http, {
    Future<void> Function(Duration)? wait,
    Random? random,
  }) : _api = CloudNoteTransport(origin, http, wait: wait),
       _wait = wait,
       _random = random ?? Random.secure();

  static const String origin = 'https://cloud.honor.com';

  /// 未分组笔记所在的默认文件夹，不作为标签。
  static const String _defaultFolder = r'eda801b5$0e24$4835$9288$cad0a537274a';

  final CloudNoteHttp http;
  final CloudNoteTransport _api;
  final Future<void> Function(Duration)? _wait;
  final Random _random;
  CloudNoteTransport? _files;

  Map<String, String> _headers() {
    final csrf = http.cookie('hc_CSRF_Token');
    if (csrf == null || csrf.isEmpty) {
      throw const CloudNoteException(CloudNoteFailure.sessionExpired);
    }
    return {
      'Csrftoken': csrf,
      'x-hn-traceId': List.generate(
        32,
        (_) => _random.nextInt(16).toRadixString(16),
      ).join(),
      'Device-Type': '1',
    };
  }

  Future<Object?> _json(String method, String path, {Object? body}) async {
    final payload = await _api.json(
      method,
      '/portal/$path',
      headers: _headers(),
      jsonBody: body,
    );
    if (payload['code'] != 0 || !payload.containsKey('data')) {
      throw CloudNoteException(CloudNoteFailure.rejected, 'honor $path');
    }
    return payload['data'];
  }

  @override
  Future<String> probe() async {
    final user = await _json('GET', 'user/info');
    final id = user is Map ? user['userId'] : null;
    if ((id is! String && id is! int) || '$id'.isEmpty) {
      throw const CloudNoteException(CloudNoteFailure.sessionExpired);
    }
    await _json('GET', 'notepad/note/count');
    return 'honor:$id';
  }

  @override
  Future<List<CloudNote>> fetchNotes(CloudProgress onProgress) async {
    final rows = await _json('POST', 'notepad/note/initDataBase/getFolderList');
    final folders = <String, String>{
      for (final row in rows is List ? rows : const [])
        if (row is Map &&
            row['uuid'] is String &&
            row['uuid'] != _defaultFolder &&
            row['type'] == 1 &&
            (row['delete_flag'] ?? 0) == 0)
          row['uuid'] as String: '${row['display_name'] ?? ''}',
    };
    final count = await _json('GET', 'notepad/note/count');
    final list = await _json(
      'POST',
      'notepad/note/util/getNoteList',
      body: {'queryType': 1, 'category': 'total', 'searchContent': ''},
    );
    final total = count is Map ? count['total'] : null;
    final ids = [
      for (final row in list is List ? list : const [])
        if (row is Map && row['uuid'] is String) row['uuid'] as String,
    ];
    if (total is! int ||
        ids.toSet().length != ids.length ||
        ids.length != total) {
      throw const CloudNoteException(
        CloudNoteFailure.protocolChanged,
        'honor count',
      );
    }
    onProgress(0, ids.length);

    final notes = <CloudNote>[];
    for (final (index, id) in ids.indexed) {
      final detail = await _json(
        'POST',
        'notepad/noteDetail',
        body: {
          'noteIds': [id],
        },
      );
      if (detail is! List ||
          detail.length != 1 ||
          detail.single is! Map ||
          (detail.single as Map)['uuid'] != id) {
        throw const CloudNoteException(
          CloudNoteFailure.protocolChanged,
          'honor detail',
        );
      }
      final note = _parseEntry(
        (detail.single as Map).cast<String, Object?>(),
        folders,
      );
      if (note != null) notes.add(note);
      onProgress(index + 1, ids.length);
    }
    return notes;
  }

  /// 手写、证件等专有类型、上锁与回收站中的笔记返回 null。
  static CloudNote? _parseEntry(
    Map<String, Object?> entry,
    Map<String, String> folders,
  ) {
    final html = entry['html_content'];
    if (html is! String ||
        entry['type'] != 2 ||
        (entry['lock_status'] ?? 0) != 0 ||
        (entry['delete_flag'] ?? 0) != 0) {
      return null;
    }
    final created = _time(entry['create_time']);
    if (created == null) return null;
    return CloudNote(
      id: '${entry['uuid']}',
      title: entry['title'] is String ? entry['title'] as String : '',
      createdAt: created,
      updatedAt: _time(entry['modify_time']),
      folder: folders[entry['folder_uuid']],
      attachments: _attachments(entry),
      writeBody: (writer, resolve) => writeCloudHtml(
        writer,
        html,
        resolve,
        prepare: _normalize,
        imageId: (image) => image.attributes['src'],
      ),
    );
  }

  /// 附件记录校验与原图/预览图配对；任何一项不合规就不读取附件，正文
  /// 照常导入。
  static List<CloudAttachment> _attachments(Map<String, Object?> entry) {
    final rows = entry['attachments'];
    final container = entry['unstruct_guid'];
    if (rows is! List || rows.isEmpty) return const [];
    if (container is! String ||
        !RegExp(r'^[A-Za-z0-9$-]{1,80}$').hasMatch(container)) {
      return const [];
    }
    final records = <Map<String, Object?>>[];
    for (final row in rows) {
      if (row is! Map ||
          row['parent_uuid'] != entry['uuid'] ||
          row['uuid'] is! String ||
          (row['uuid'] as String).isEmpty ||
          row['filename'] is! String ||
          !RegExp(
            r'^[A-Za-z0-9$_.-]{1,200}$',
          ).hasMatch(row['filename'] as String) ||
          row['size'] is! int ||
          (row['size'] as int) <= 0 ||
          (row['size'] as int) > 209715200 ||
          row['hash'] is! String ||
          !RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(row['hash'] as String)) {
        return const [];
      }
      records.add(row.cast<String, Object?>());
    }
    if (records.map((row) => row['uuid']).toSet().length != records.length) {
      return const [];
    }
    final result = <CloudAttachment>[];
    final handled = <Map<String, Object?>>{};
    for (final row in records) {
      if (handled.contains(row)) continue;
      final name = row['filename'] as String;
      final mime = '${row['mimetype'] ?? ''}';
      var selected = row;
      var id = row['uuid'] as String;
      if (mime.startsWith('image/')) {
        final stem = name.split('_').first;
        final pair = records
            .where(
              (other) => (other['filename'] as String).split('_').first == stem,
            )
            .toList();
        if (pair.length > 1) {
          final originals = pair
              .where(
                (other) => (other['filename'] as String).contains('_original.'),
              )
              .toList();
          final previews = pair
              .where(
                (other) =>
                    !(other['filename'] as String).contains('_original.'),
              )
              .toList();
          if (originals.length != 1 || previews.length != 1) continue;
          selected = originals.single;
          id = previews.single['uuid'] as String;
          handled.addAll(pair);
        }
      }
      handled.add(row);
      result.add(
        CloudAttachment(
          id: id,
          name: selected['filename'] as String,
          mime: mime.isEmpty ? null : mime,
          reference: (
            container: container,
            filename: selected['filename'] as String,
            size: selected['size'] as int,
            hash: (selected['hash'] as String).toLowerCase(),
          ),
        ),
      );
    }
    return result;
  }

  /// 把荣耀私有标记改写成通用 HTML（参考实现 `honor_html.py` 的 normalize）。
  static void _normalize(dom.Element root) {
    for (final node in root.querySelectorAll('.h_n')) {
      final classes = node.classes;
      final dom.Element replacement;
      if (classes.contains('Nb')) {
        final level = int.tryParse(node.attributes['hlevel'] ?? '');
        replacement = dom.Element.tag(
          level != null && level >= 1 && level <= 6 ? 'h$level' : 'p',
        );
        node.reparentChildren(replacement);
      } else if (classes.contains('Na')) {
        final checked =
            classes.contains('Sc') || node.querySelector('.Sc') != null;
        replacement = dom.Element.tag('li')
          ..attributes['data-checked'] = '$checked';
        // 待办的勾选图标等装饰去掉，只保留文字片段。
        for (final text in node.querySelectorAll('h-text')) {
          replacement.append(text);
        }
      } else if (classes.contains('Nd') || classes.contains('Nh')) {
        replacement = dom.Element.tag(classes.contains('Nd') ? 'ol' : 'ul');
        node.reparentChildren(replacement);
      } else if (classes.contains('Nc')) {
        replacement = dom.Element.tag('li');
        node.reparentChildren(replacement);
      } else if (classes.contains('Nr')) {
        replacement = dom.Element.tag('hr');
      } else if (classes.contains('Ni')) {
        replacement = dom.Element.tag('img')
          ..attributes['src'] = node.attributes['hid'] ?? '';
      } else {
        continue;
      }
      node.replaceWith(replacement);
    }
    for (final font in root.getElementsByTagName('font').toList()) {
      final classes = font.classes;
      final style = [
        font.attributes['style'] ?? '',
        if (classes.contains('La')) 'font-weight:bold',
        if (classes.contains('Lb')) 'font-style:italic',
        if (classes.contains('Lc') || classes.contains('Ld'))
          'text-decoration:${[if (classes.contains('Lc')) 'underline', if (classes.contains('Ld')) 'line-through'].join(' ')}',
      ].where((part) => part.isNotEmpty).join(';');
      final link = font.attributes['hlink'];
      final replacement = dom.Element.tag(link == null ? 'span' : 'a');
      if (link != null) replacement.attributes['href'] = link;
      if (style.isNotEmpty) replacement.attributes['style'] = style;
      font.reparentChildren(replacement);
      font.replaceWith(replacement);
    }
  }

  @override
  Future<List<int>> download(CloudAttachment attachment) async {
    final reference =
        attachment.reference!
            as ({String container, String filename, int size, String hash});
    final files = _files ??= await _fileTransport();
    final response = await files.request(
      'GET',
      '/portal/notepad/file/singleFileDownstream',
      query: {
        'cloudPath':
            '/sync/notepad/${reference.container}/${reference.filename}',
      },
      headers: {
        'Csrftoken': _headers()['Csrftoken']!,
        'Origin': origin,
        'Device-Type': '1',
      },
    );
    final bytes = response.bytes;
    if (bytes.length != reference.size ||
        sha256.convert(bytes).toString() != reference.hash) {
      throw const CloudNoteException(
        CloudNoteFailure.rejected,
        'honor file digest',
      );
    }
    return bytes;
  }

  /// 文件服务地址（`config/web` 的 `viteDownloadDomain`），只接受荣耀域名下
  /// 不带端口、路径与查询的 https 地址。
  Future<CloudNoteTransport> _fileTransport() async {
    final config = await _json('GET', 'config/web');
    final raw = config is Map ? config['viteDownloadDomain'] : null;
    final url = raw is String ? Uri.tryParse(raw) : null;
    final host = url?.host.toLowerCase() ?? '';
    final safe =
        url != null &&
        url.scheme == 'https' &&
        (host == 'honor.com' ||
            host.endsWith('.honor.com') ||
            host == 'hihonor.com' ||
            host.endsWith('.hihonor.com')) &&
        !url.hasPort &&
        url.userInfo.isEmpty &&
        (url.path.isEmpty || url.path == '/') &&
        !url.hasQuery &&
        !url.hasFragment;
    if (!safe) {
      throw const CloudNoteException(
        CloudNoteFailure.rejected,
        'honor file host',
      );
    }
    return CloudNoteTransport(
      'https://$host',
      http,
      headers: const {'Referer': '$origin/'},
      wait: _wait,
    );
  }

  static DateTime? _time(Object? value) => value is num && value > 0
      ? DateTime.fromMillisecondsSinceEpoch(value.round())
      : null;
}
