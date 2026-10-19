import 'dart:convert';

import 'journal_import_cloud.dart';
import 'journal_import_cloud_blocks.dart';
import 'journal_import_cloud_http.dart';
import 'journal_import_cloud_xiaomi_markup.dart';
import 'journal_import_models.dart';
import 'journal_import_support.dart';

/// 小米笔记（i.mi.com）的只读客户端，协议依据参考实现（笔记互迁
/// `providers/xiaomi.py`、`xiaomi_files.py`）：
///
/// - 只靠 Cookie 鉴权（登录后 i.mi.com 的 `userId`、`serviceToken` 等），
///   请求带桌面 UA 与 `Referer: https://i.mi.com/`，不跟随重定向；
/// - 列表 `GET /note/full/page?limit=200&ts=<毫秒>[&syncTag=<游标>]`，直到
///   `lastPage`；同一响应的 `folders` 是文件夹（`subject` 为名称）；
///   跳过 `deleted`/`purged` 与文件夹条目；游标停滞、ID 重复视为协议变化；
/// - 详情 `GET /note/note/<id>/`（结尾斜杠不可少），`extraInfo` 是 JSON
///   字符串（`title`），`setting.data` 是附件元数据，正文格式见
///   [parseXiaomiMarkup]（含旧版 `☺ ` 图片写法）；端到端加密、思维导图等
///   非普通笔记跳过；
/// - 附件 `GET /file/full?type=note_img&fileid=<id>` 返回 302，跳到
///   `*.xmssdn.micloud.mi.com` 的签名地址，再以不带 Cookie 的请求下载。
class XiaomiCloudProvider implements CloudNoteProvider {
  XiaomiCloudProvider(this.http, {Future<void> Function(Duration)? wait})
    : _api = CloudNoteTransport(origin, http, wait: wait),
      _wait = wait;

  static const String origin = 'https://i.mi.com';

  final CloudNoteHttp http;
  final CloudNoteTransport _api;
  final Future<void> Function(Duration)? _wait;

  @override
  final CloudReadIssues issues = CloudReadIssues();

  Future<Map<String, Object?>> _data(
    String path, {
    Map<String, String> query = const {},
  }) async {
    final payload = await _api.json('GET', path, query: query);
    final data = payload['data'];
    if (payload['code'] != 0 || data is! Map) {
      throw CloudNoteException(CloudNoteFailure.rejected, 'xiaomi code');
    }
    return data.cast<String, Object?>();
  }

  Future<Map<String, Object?>> _page(String? cursor) async {
    final data = await _data(
      '/note/full/page',
      query: {
        'limit': '200',
        'ts': '${DateTime.now().millisecondsSinceEpoch}',
        'syncTag': ?cursor,
      },
    );
    if (data['entries'] is! List || data['lastPage'] is! bool) {
      throw const CloudNoteException(
        CloudNoteFailure.protocolChanged,
        'xiaomi page',
      );
    }
    return data;
  }

  @override
  Future<String> probe() async {
    final uid = http.cookie('userId');
    if (uid == null || uid.isEmpty) {
      throw const CloudNoteException(CloudNoteFailure.sessionExpired);
    }
    await _page(null);
    return 'xiaomi:$uid';
  }

  @override
  Future<List<CloudNote>> fetchNotes(CloudProgress onProgress) async {
    final ids = <String>[];
    final seen = <String>{};
    final cursors = <String>{};
    final folders = <String, String>{};
    String? cursor;
    for (var page = 0; ; page++) {
      if (page >= 10000) {
        throw const CloudNoteException(CloudNoteFailure.protocolChanged);
      }
      final data = await _page(cursor);
      _collectFolders(data['folders'], folders);
      for (final entry in data['entries'] as List) {
        if (entry is! Map || entry['id'] == null) {
          throw const CloudNoteException(CloudNoteFailure.protocolChanged);
        }
        if (const {'deleted', 'purged'}.contains(entry['status']) ||
            entry['type'] == 'folder') {
          continue;
        }
        final id = _id(entry['id']);
        if (!seen.add(id)) {
          throw const CloudNoteException(
            CloudNoteFailure.protocolChanged,
            'xiaomi duplicate',
          );
        }
        ids.add(id);
      }
      onProgress(ids.length, null);
      if (data['lastPage'] == true) break;
      final next = data['syncTag'];
      if (next == null || !cursors.add(_id(next))) {
        throw const CloudNoteException(
          CloudNoteFailure.protocolChanged,
          'xiaomi cursor',
        );
      }
      cursor = _id(next);
    }

    final notes = <CloudNote>[];
    for (final (index, id) in ids.indexed) {
      final data = await _data('/note/note/${Uri.encodeComponent(id)}/');
      final entry = data['entry'];
      if (entry is Map && _id(entry['id']) == id) {
        final note = _parseEntry(entry.cast<String, Object?>(), folders);
        if (note != null) notes.add(note);
      } else {
        issues.skip(JournalSkipReason.unreadable);
      }
      onProgress(index + 1, ids.length);
    }
    // 账号开启端到端加密时，所有笔记都带 `encryptInfo`、无法读取；全部被
    // 跳过时提示“账号已加密”，而不是“没有日记”。
    if (notes.isEmpty &&
        (issues.skipped[JournalSkipReason.encrypted] ?? 0) > 0) {
      throw const CloudNoteException(CloudNoteFailure.unsupportedAccount);
    }
    return notes;
  }

  /// 有效文件夹（normal/alive，且不是“未分类” `0`）。
  static void _collectFolders(Object? rows, Map<String, String> folders) {
    if (rows is! List) return;
    for (final row in rows) {
      if (row is! Map || row['id'] == null || row['subject'] is! String) {
        continue;
      }
      final id = _id(row['id']);
      final status = row['status'] ?? 'normal';
      if (id == '0' || (status != 'normal' && status != 'alive')) continue;
      folders[id] = row['subject'] as String;
    }
  }

  /// 读不了的笔记记入 [issues] 并返回 null（端到端加密、思维导图等专有
  /// 类型、结构认不出来）。
  CloudNote? _parseEntry(
    Map<String, Object?> entry,
    Map<String, String> folders,
  ) {
    CloudNote? skip(JournalSkipReason reason) {
      issues.skip(reason);
      return null;
    }

    final content = entry['content'];
    if (content is! String) return skip(JournalSkipReason.unreadable);
    if (entry['encryptInfo'] case final info?
        when info != false && info != '' && info != 0) {
      return skip(JournalSkipReason.encrypted);
    }
    final Object? extra;
    try {
      final raw = entry['extraInfo'];
      extra = raw is String && raw.isNotEmpty ? jsonDecode(raw) : const {};
    } on FormatException {
      return skip(JournalSkipReason.unreadable);
    }
    if (extra is! Map) return skip(JournalSkipReason.unreadable);
    if ((extra['note_content_type'] ?? 'common') != 'common') {
      return skip(JournalSkipReason.unsupported);
    }
    final created = _time(entry['createDate']);
    if (created == null) return skip(JournalSkipReason.unreadable);

    final markup = parseXiaomiMarkup(content);
    final attachments = <CloudAttachment>[];
    final setting = entry['setting'];
    final metadata = setting is Map ? setting['data'] : null;
    for (final item in metadata is List ? metadata : const []) {
      if (item is! Map || item['fileId'] == null) continue;
      final id = _id(item['fileId']);
      final mime = item['mimeType'] is String
          ? item['mimeType'] as String
          : null;
      attachments.add(
        CloudAttachment(
          id: id,
          name: switch (item['fileName']) {
            final String name when name.trim().isNotEmpty => name,
            _ => '$id${_extensionFor(mime)}',
          },
          mime: mime,
        ),
      );
    }
    for (final reference in markup.media) {
      if (attachments.any((item) => item.id == reference.id)) continue;
      attachments.add(CloudAttachment(id: reference.id, name: reference.id));
    }
    final folderId = entry['folderId'] == null ? '0' : _id(entry['folderId']);
    return CloudNote(
      id: _id(entry['id']),
      title: extra['title'] is String ? extra['title'] as String : '',
      createdAt: created,
      updatedAt: _time(entry['modifyDate']),
      folder: folders[folderId],
      attachments: attachments,
      writeBody: (writer, resolve) =>
          writeCloudBlocks(writer, markup.blocks, resolve),
    );
  }

  @override
  Future<List<int>> download(CloudAttachment attachment) async {
    final first = await _api.request(
      'GET',
      '/file/full',
      query: {'type': 'note_img', 'fileid': attachment.id},
      returnRedirects: true,
    );
    final CloudNoteResponse response;
    if (first.statusCode >= 300 && first.statusCode < 400) {
      final target = Uri.parse(
        '$origin/file/full',
      ).resolve(first.headers['location'] ?? '');
      final safe =
          target.scheme == 'https' &&
          (target.host == 'xmssdn.micloud.mi.com' ||
              target.host.endsWith('.xmssdn.micloud.mi.com')) &&
          (!target.hasPort || target.port == 443) &&
          target.userInfo.isEmpty &&
          !target.hasFragment &&
          target.path.startsWith('/') &&
          !target.path.startsWith('//');
      if (!safe) {
        throw const CloudNoteException(
          CloudNoteFailure.rejected,
          'xiaomi file redirect',
        );
      }
      response = await CloudNoteTransport(
        'https://${target.host}',
        http,
        wait: _wait,
      ).requestUrl('GET', target, withCookies: false);
    } else {
      response = first;
    }
    final type = response.headers['content-type'] ?? '';
    if (type.startsWith('text/html') ||
        type.startsWith('application/json') ||
        response.bytes.isEmpty) {
      throw const CloudNoteException(
        CloudNoteFailure.rejected,
        'xiaomi file body',
      );
    }
    return response.bytes;
  }

  /// JSON 中的 ID 可能是数字；整数形式的浮点数按整数书写。
  static String _id(Object? value) => switch (value) {
    final double number when number == number.truncateToDouble() =>
      number.toInt().toString(),
    _ => '$value',
  };

  static DateTime? _time(Object? value) =>
      (journalNumber(value) ?? 0) > 0 ? journalEpochTime(value) : null;

  static String _extensionFor(String? mime) => switch (mime) {
    'image/jpeg' => '.jpg',
    'image/png' => '.png',
    'image/gif' => '.gif',
    'image/webp' => '.webp',
    'audio/mpeg' => '.mp3',
    'audio/aac' => '.aac',
    'audio/mp4' => '.m4a',
    'video/mp4' => '.mp4',
    _ => '',
  };
}
