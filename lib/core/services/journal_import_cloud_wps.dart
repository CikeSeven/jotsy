import 'journal_import_cloud.dart';
import 'journal_import_cloud_blocks.dart';
import 'journal_import_cloud_http.dart';
import 'journal_import_cloud_wps_format.dart';
import 'journal_import_models.dart';

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
///   密文字节）；`valid == 2` 在回收站，跳过；格式见 [decodeWpsBody]；正文
///   读不出来（解密失败、长正文对象读不到、未知的存放方式）时改用目录里的
///   摘要作正文，计入 [CloudReadIssues.summaryOnly]，不丢掉整篇；
/// - 图片/录音的对象键为 32 位十六进制，经 `/s3/requestdownload` 取得临时
///   凭据后用 SigV4 签名直接从 S3 下载（不带账号 Cookie）；凭据过期被拒时
///   换一份重试一次。
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

  @override
  final CloudReadIssues issues = CloudReadIssues();

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
    if (created == null) {
      issues.skip(JournalSkipReason.unreadable);
      return null;
    }
    String field(String name) {
      try {
        return row[name] is String ? codec.decrypt(row[name] as String) : '';
      } on Object {
        return '';
      }
    }

    final media = <WpsMedia>[];
    final body = await _body(detail, codec);
    final List<CloudBlock> blocks;
    if (body != null) {
      blocks = decodeWpsBody(body, onMedia: media.add);
    } else {
      // 摘要是纯文本，不按正文语法解析（免得字面的 * ~ 被当成样式）。
      issues.summaryOnly++;
      blocks = [
        for (final line in field('summary').split('\n'))
          CloudBlock.paragraph([if (line.isNotEmpty) CloudSpan(line)]),
      ];
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
            name: item.name ?? item.key.split('/').last,
            reference: item.key,
          ),
      ],
      writeBody: (writer, resolve) => writeCloudBlocks(writer, blocks, resolve),
    );
  }

  /// 正文原文；读不出来时返回 null，由调用方改用摘要。登录失效、断网等
  /// 会让整次读取不完整的错误照常抛出。
  Future<String?> _body(Map<String, Object?> detail, WpsCodec codec) async {
    try {
      final raw = detail['body'] is String ? detail['body'] as String : '';
      return switch (detail['bodyType']) {
        0 => codec.decrypt(raw),
        1 => await _longBody(codec.decrypt(raw)),
        _ => null,
      };
    } on CloudNoteException catch (error) {
      if (isFatalCloudFailure(error.failure)) rethrow;
      return null;
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
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
    return _codec!.decryptBytes(await _s3Object((_) => key));
  }

  /// 读 S3 对象。临时凭据会过期（AWS 对过期令牌回 400 `ExpiredToken`，签名
  /// 不符回 403），大账号读到后面就会碰上：被拒时换一份凭据重试一次，仍被
  /// 拒才算这一项读不到。[keyOf] 按凭据给出的前缀拼出对象键。
  Future<List<int>> _s3Object(String Function(WpsStorage storage) keyOf) async {
    final storage = await _ensureStorage();
    try {
      return await _object(storage, keyOf(storage));
    } on CloudNoteException catch (error) {
      if (error.failure != CloudNoteFailure.rejected &&
          error.failure != CloudNoteFailure.forbidden) {
        rethrow;
      }
      _storage = null;
      final fresh = await _ensureStorage();
      return _object(fresh, keyOf(fresh));
    }
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
    return _s3Object((storage) => '${storage.keyPrefix}$key');
  }

  static DateTime? _time(Object? value) => value is num && value > 0
      ? DateTime.fromMillisecondsSinceEpoch(value.round())
      : null;
}
