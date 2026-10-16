import 'journal_import_cloud.dart';
import 'journal_import_cloud_blocks.dart';
import 'journal_import_cloud_http.dart';
import 'journal_import_cloud_wps_format.dart';

/// WPS 便签（note.wps.cn）的只读客户端，协议依据参考实现（笔记互迁
/// `providers/wps.py`、`wps_files.py`）：
///
/// - 账号 `GET https://account.wps.cn/api/v3/mine?attrs=profile` 取
///   `userid`，之后的便签请求都带 `X-user-key: <userid>` 与
///   `Origin`/`Referer: https://note.wps.cn`；
/// - `POST /notesvr/get/web-config` 给出 `aesPassword`，用于解密标题、摘要、
///   正文与 S3 凭据（见 [WpsCodec]）；
/// - 分组 `get/notegroup`；笔记分首页、各分组、提醒三类范围分页读取（每页
///   50，少于 50 即结束），按 `noteId` 去重；
/// - 正文 `get/notebody`：`bodyType` 0 内联，1 为 S3 对象中的长正文（原始
///   密文字节）；`valid == 2` 在回收站，跳过；格式见 [decodeWpsBody]；
/// - 图片/录音的对象键为 32 位十六进制，经 `/s3/requestdownload` 取得临时
///   凭据后用 SigV4 签名直接从 S3 下载（不带账号 Cookie）。
class WpsCloudProvider implements CloudNoteProvider {
  WpsCloudProvider(
    this.http, {
    Future<void> Function(Duration)? wait,
    DateTime Function()? clock,
  }) : _notes = CloudNoteTransport(
         noteOrigin,
         http,
         headers: const {
           'Origin': 'https://note.wps.cn',
           'Referer': 'https://note.wps.cn/',
         },
         wait: wait,
       ),
       _account = CloudNoteTransport(accountOrigin, http, wait: wait),
       _wait = wait,
       _clock = clock ?? DateTime.now;

  static const String noteOrigin = 'https://note-api.wps.cn';
  static const String accountOrigin = 'https://account.wps.cn';
  static const int _pageSize = 50;

  final CloudNoteHttp http;
  final CloudNoteTransport _notes;
  final CloudNoteTransport _account;
  final Future<void> Function(Duration)? _wait;
  final DateTime Function() _clock;

  String? _uid;
  WpsCodec? _codec;
  WpsStorage? _storage;

  Future<Map<String, Object?>> _call(
    String method,
    String path, {
    Object? body,
  }) async {
    final payload = await _notes.json(
      method,
      path,
      headers: {'X-user-key': ?_uid},
      jsonBody: body,
    );
    if (payload['result'] == 'userNotLogin') {
      throw const CloudNoteException(CloudNoteFailure.sessionExpired);
    }
    final error = payload['errorCode'];
    if (error != null && error != 0 && error != '' && error != false) {
      throw CloudNoteException(CloudNoteFailure.rejected, 'wps $path');
    }
    return payload;
  }

  @override
  Future<String> probe() async {
    final mine = await _account.json(
      'GET',
      '/api/v3/mine',
      query: const {'attrs': 'profile'},
    );
    final uid = mine['userid'];
    if ((uid is! String && uid is! int) || '$uid'.isEmpty) {
      throw const CloudNoteException(CloudNoteFailure.sessionExpired);
    }
    _uid = '$uid';
    final config = await _call(
      'POST',
      '/notesvr/get/web-config',
      body: const {'test': 'test'},
    );
    final password = config['aesPassword'];
    if (password is! String || password.isEmpty) {
      throw const CloudNoteException(
        CloudNoteFailure.protocolChanged,
        'wps web-config',
      );
    }
    try {
      _codec = WpsCodec(password);
    } on Object {
      throw const CloudNoteException(
        CloudNoteFailure.protocolChanged,
        'wps password',
      );
    }
    return 'wps:$uid';
  }

  @override
  Future<List<CloudNote>> fetchNotes(CloudProgress onProgress) async {
    if (_codec == null) await probe();
    final uid = _uid!;
    final groups = await _call(
      'POST',
      '/notesvr/get/notegroup',
      body: const {'lastRequestTime': 0, 'excludeInValid': true},
    );
    final folders = <String, String>{
      for (final group in (groups['noteGroups'] as List?) ?? const [])
        if (group is Map &&
            group['groupId'] != null &&
            '${group['groupId']}'.isNotEmpty &&
            (group['valid'] is! int || group['valid'] == 1))
          '${group['groupId']}': '${group['groupName'] ?? ''}',
    };

    final rows = <String, Map<String, Object?>>{};
    Future<void> scope(
      Future<Map<String, Object?>> Function(int offset) page,
    ) async {
      final seen = <String>{};
      for (var offset = 0, count = 0; ; count++) {
        if (count >= 10000) {
          throw const CloudNoteException(CloudNoteFailure.protocolChanged);
        }
        final notes = (await page(offset))['webNotes'];
        if (notes is! List) {
          throw const CloudNoteException(
            CloudNoteFailure.protocolChanged,
            'wps page',
          );
        }
        for (final row in notes) {
          final id = row is Map ? row['noteId'] : null;
          if (id == null || !seen.add('$id')) {
            throw const CloudNoteException(
              CloudNoteFailure.protocolChanged,
              'wps note id',
            );
          }
          rows.putIfAbsent('$id', () => (row as Map).cast<String, Object?>());
        }
        onProgress(rows.length, null);
        if (notes.length < _pageSize) return;
        offset += notes.length;
      }
    }

    await scope(
      (offset) => _call(
        'GET',
        '/notesvr/v2/user/${Uri.encodeComponent(uid)}/home/startindex/'
            '$offset/rows/$_pageSize/notes',
      ),
    );
    for (final group in folders.keys) {
      await scope(
        (offset) => _call(
          'POST',
          '/notesvr/web/getnotes/group',
          body: {
            'uid': uid,
            'rows': _pageSize,
            'startIndex': offset,
            'groupId': group,
          },
        ),
      );
    }
    await scope(
      (offset) => _call(
        'POST',
        '/notesvr/web/getnotes/remind',
        body: {
          'uid': uid,
          'rows': _pageSize,
          'startIndex': offset,
          'remindStartTime': -62135596800000,
          'remindEndTime': 253402300800000,
        },
      ),
    );

    final notes = <CloudNote>[];
    for (final (index, MapEntry(key: id, value: row)) in rows.entries.indexed) {
      final detail = await _call(
        'POST',
        '/notesvr/get/notebody',
        body: {
          'noteIds': [id],
        },
      );
      final bodies = detail['noteBodies'];
      if (bodies is! List ||
          bodies.length != 1 ||
          bodies.single is! Map ||
          '${(bodies.single as Map)['noteId']}' != id) {
        throw const CloudNoteException(
          CloudNoteFailure.protocolChanged,
          'wps detail',
        );
      }
      final note = await _parseNote(
        id,
        row,
        (bodies.single as Map).cast<String, Object?>(),
        folders,
      );
      if (note != null) notes.add(note);
      onProgress(index + 1, rows.length);
    }
    return notes;
  }

  Future<CloudNote?> _parseNote(
    String id,
    Map<String, Object?> row,
    Map<String, Object?> detail,
    Map<String, String> folders,
  ) async {
    if (detail['valid'] == 2) return null;
    final codec = _codec!;
    final created = _time(row['createTime']);
    if (created == null) return null;
    final String body;
    try {
      final raw = detail['body'] is String ? detail['body'] as String : '';
      switch (detail['bodyType']) {
        case 0:
          body = codec.decrypt(raw);
        case 1:
          body = await _longBody(codec.decrypt(raw));
        default:
          return null;
      }
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
    final media = <WpsMedia>[];
    final List<CloudBlock> blocks;
    try {
      blocks = decodeWpsBody(body, onMedia: media.add);
    } on FormatException {
      return null;
    }
    String field(String name) {
      try {
        return row[name] is String ? codec.decrypt(row[name] as String) : '';
      } on Object {
        return '';
      }
    }

    final title = field('title').trim().isNotEmpty
        ? field('title')
        : field('summary').split('\n').first;
    return CloudNote(
      id: id,
      title: title,
      createdAt: created,
      updatedAt: _time(detail['contentUpdateTime']),
      folder: folders['${row['groupId'] ?? ''}'],
      attachments: [
        for (final item in media)
          CloudAttachment(
            id: wpsMediaId(item.key),
            name: item.key.split('/').last,
            reference: item.key,
          ),
      ],
      writeBody: (writer, resolve) => writeCloudBlocks(writer, blocks, resolve),
    );
  }

  /// 长正文：对象键须在本账号前缀下且为 `<32 位十六进制>.encrypted`，对象
  /// 内容是原始密文字节。
  Future<String> _longBody(String key) async {
    final storage = await _ensureStorage();
    if (!key.startsWith(storage.keyPrefix) ||
        !RegExp(
          r'^[0-9a-f]{32}\.encrypted$',
        ).hasMatch(key.substring(storage.keyPrefix.length))) {
      throw const FormatException('wps long body key');
    }
    final bytes = await _object(storage, key);
    return _codec!.decryptBytes(bytes);
  }

  Future<WpsStorage> _ensureStorage() async => _storage ??= WpsStorage.parse(
    await _notes.json(
      'POST',
      '/s3/requestdownload',
      headers: {'X-user-key': ?_uid},
      jsonBody: const <String, Object?>{},
    ),
    _codec!,
  );

  Future<List<int>> _object(WpsStorage storage, String key) async {
    final url = storage.objectUrl(key);
    final response =
        await CloudNoteTransport(
          'https://${url.host}',
          http,
          wait: _wait,
        ).requestUrl(
          'GET',
          url,
          headers: storage.sign(url, _clock()),
          withCookies: false,
        );
    if (response.bytes.isEmpty) {
      throw const CloudNoteException(CloudNoteFailure.rejected, 'wps object');
    }
    return response.bytes;
  }

  @override
  Future<List<int>> download(CloudAttachment attachment) async {
    final key = attachment.reference;
    if (key is! String || !RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(key)) {
      throw const CloudNoteException(CloudNoteFailure.rejected, 'wps key');
    }
    final storage = await _ensureStorage();
    return _object(storage, '${storage.keyPrefix}$key');
  }

  static DateTime? _time(Object? value) => value is num && value > 0
      ? DateTime.fromMillisecondsSinceEpoch(value.round())
      : null;
}
