import 'dart:math';

import 'package:crypto/crypto.dart';

import 'journal_import_cloud.dart';
import 'journal_import_cloud_honor_html.dart';
import 'journal_import_cloud_html.dart';
import 'journal_import_cloud_http.dart';
import 'journal_import_models.dart';

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
/// - 正文是带 `h_n` 类名的私有 HTML（段落与对齐、标题、待办、列表、分隔线、
///   图片、上传的文档/音频/视频、录音，行内粗斜体、颜色、高亮、字号与链接），
///   标记说明与改写见 journal_import_cloud_honor_html.dart；
/// - 附件记录逐条校验，不合规的一条按缺失计入、不影响其他附件；图片的原图
///   与预览图成对存放：下载 `_original` 原图，附件 ID 用预览图的 uuid（即
///   正文里的 `hid`）；上传文件用卡片上的原文件名，视频封面不单独导入；
///   文件服务地址来自 `config/web`，下载后按记录的大小与 SHA-256 校验。
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

  @override
  final CloudReadIssues issues = CloudReadIssues();

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

  /// 回收站中的笔记返回 null；上锁的、手写与证件等专有类型、结构认不
  /// 出来的记入 [issues] 并返回 null。
  CloudNote? _parseEntry(
    Map<String, Object?> entry,
    Map<String, String> folders,
  ) {
    CloudNote? skip(JournalSkipReason reason) {
      issues.skip(reason);
      return null;
    }

    if ((entry['delete_flag'] ?? 0) != 0) return null;
    if ((entry['lock_status'] ?? 0) != 0) {
      return skip(JournalSkipReason.encrypted);
    }
    if (entry['type'] != 2) return skip(JournalSkipReason.unsupported);
    final html = entry['html_content'];
    if (html is! String) return skip(JournalSkipReason.unreadable);
    final created = _time(entry['create_time']);
    if (created == null) return skip(JournalSkipReason.unreadable);
    final index = indexHonorHtml(html);
    return CloudNote(
      id: '${entry['uuid']}',
      title: entry['title'] is String ? entry['title'] as String : '',
      createdAt: created,
      updatedAt: _time(entry['modify_time']),
      folder: folders[entry['folder_uuid']],
      attachments: _attachments(entry, index),
      writeBody: (writer, resolve) => writeCloudHtml(
        writer,
        html,
        resolve,
        prepare: (root) => normalizeHonorHtml(root, posters: index.posters),
        imageId: (image) => image.attributes['src'],
      ),
    );
  }

  /// 附件记录逐条校验并配对原图/预览图。不合规的记录（归属不符、文件名
  /// 含路径、大小或摘要缺失）仍列出但不带下载参数，下载时按缺失计入；只作
  /// 视频封面的图片不导入；上传文件改用正文卡片上的原文件名，媒体类型也
  /// 按它判断。
  static List<CloudAttachment> _attachments(
    Map<String, Object?> entry,
    HonorHtmlIndex index,
  ) {
    final rows = entry['attachments'];
    final container = entry['unstruct_guid'];
    if (rows is! List || rows.isEmpty) return const [];
    final validContainer =
        container is String &&
        RegExp(r'^[A-Za-z0-9$-]{1,80}$').hasMatch(container);
    final records = <Map<String, Object?>>[];
    final invalid = <String>[];
    final seen = <String>{};
    for (final row in rows) {
      final uuid = row is Map ? row['uuid'] : null;
      if (uuid is! String || uuid.isEmpty || !seen.add(uuid)) continue;
      if (validContainer && _validRecord(row as Map, entry['uuid'])) {
        records.add(row.cast<String, Object?>());
      } else if (!index.posters.contains(uuid)) {
        invalid.add(uuid);
      }
    }
    final result = <CloudAttachment>[
      for (final id in invalid)
        CloudAttachment(id: id, name: index.names[id] ?? id),
    ];
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
      if (index.posters.contains(id)) continue;
      handled.add(row);
      result.add(
        CloudAttachment(
          id: id,
          name: index.names[id] ?? selected['filename'] as String,
          mime: mime.isEmpty ? null : mime,
          reference: (
            container: container as String,
            filename: selected['filename'] as String,
            size: selected['size'] as int,
            hash: (selected['hash'] as String).toLowerCase(),
          ),
        ),
      );
    }
    return result;
  }

  /// 能安全下载的附件记录：属于这篇笔记，文件名是单层文件名（拼进
  /// `cloudPath` 时不能越出笔记目录），大小在 200 MB 内且带 SHA-256。
  static bool _validRecord(Map row, Object? noteId) {
    final filename = row['filename'];
    final size = row['size'];
    final hash = row['hash'];
    return row['parent_uuid'] == noteId &&
        filename is String &&
        filename.isNotEmpty &&
        filename.length <= 255 &&
        filename != '.' &&
        filename != '..' &&
        !RegExp(r'[/\\\x00-\x1F]').hasMatch(filename) &&
        size is int &&
        size > 0 &&
        size <= 209715200 &&
        hash is String &&
        RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(hash);
  }

  @override
  Future<List<int>> download(CloudAttachment attachment) async {
    final reference = attachment.reference;
    if (reference
        is! ({String container, String filename, int size, String hash})) {
      throw const CloudNoteException(
        CloudNoteFailure.rejected,
        'honor attachment record',
      );
    }
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
