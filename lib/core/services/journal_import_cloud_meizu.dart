import 'dart:convert';
import 'dart:math';

import 'journal_import_cloud.dart';
import 'journal_import_cloud_blocks.dart';
import 'journal_import_cloud_http.dart';
import 'journal_import_models.dart';

/// 魅族笔记（Flyme 云服务 notes.flyme.cn）的只读客户端，协议依据参考实现
/// （笔记互迁 `providers/meizu.py`、`meizu_files.py`、`meizu_groups.py`）：
///
/// - 接口都是 `POST /c/browser/note/<名称>`（参数在查询串、正文为空），
///   带 `X-Requested-With: XMLHttpRequest`，只靠 Cookie 鉴权；响应
///   `{returnCode, returnValue}`，401/302 为登录失效；
/// - `gettags` 同时给出账号 `userId` 与分组（去掉系统分组 -1/-2/-3）；
///   `getnotegroups?start&length=200&groupUuid=-1` 分页取全部笔记，正文
///   内嵌在条目里，加密笔记跳过；
/// - 正文 `body` 是区块树的 JSON 字符串：0 段落、1/2 待办、60 标题、
///   50/51 有序/无序列表容器、53 列表项、3/4/5 图片/录音/文件；行内样式
///   `span` 是 JSON 字符串，区间按 UTF-16 偏移（见 [decodeMeizuSpans]）；
/// - 附件按名称在 `files` 中取地址（相对路径或 flyme.cn/meizu.com 的
///   https 地址），带 Cookie 下载。
class MeizuCloudProvider implements CloudNoteProvider {
  MeizuCloudProvider(this.http, {Future<void> Function(Duration)? wait})
    : _api = CloudNoteTransport(origin, http, wait: wait),
      _wait = wait;

  static const String origin = 'https://notes.flyme.cn';

  final CloudNoteHttp http;
  final CloudNoteTransport _api;
  final Future<void> Function(Duration)? _wait;

  @override
  final CloudReadIssues issues = CloudReadIssues();

  Future<Map<String, Object?>> _call(
    String name, {
    Map<String, String> query = const {},
  }) async {
    final payload = await _api.json(
      'POST',
      '/c/browser/note/$name',
      query: query,
      headers: const {
        'X-Requested-With': 'XMLHttpRequest',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
    );
    final code = payload['returnCode'];
    if (code == 401 || code == 302) {
      throw const CloudNoteException(CloudNoteFailure.sessionExpired);
    }
    final value = payload['returnValue'];
    if (code != 200 || value is! Map) {
      throw CloudNoteException(CloudNoteFailure.rejected, 'meizu $name');
    }
    return value.cast<String, Object?>();
  }

  Future<({String uid, Map<String, String> folders})> _tags() async {
    final value = await _call('gettags');
    final uid = value['userId'];
    if ((uid is! String && uid is! int) ||
        '$uid'.isEmpty ||
        value['data'] is! List) {
      throw const CloudNoteException(CloudNoteFailure.sessionExpired);
    }
    return (
      uid: '$uid',
      folders: {
        for (final row in value['data'] as List)
          if (row is Map &&
              row['id'] is String &&
              row['name'] is String &&
              !const {'-1', '-2', '-3'}.contains(row['id']))
            row['id'] as String: row['name'] as String,
      },
    );
  }

  @override
  Future<String> probe() async => 'meizu:${(await _tags()).uid}';

  @override
  Future<List<CloudNote>> fetchNotes(CloudProgress onProgress) async {
    final (:uid, :folders) = await _tags();
    final notes = <CloudNote>[];
    final seen = <String>{};
    var offset = 0;
    int? total;
    for (var page = 0; ; page++) {
      if (page >= 10000) {
        throw const CloudNoteException(CloudNoteFailure.protocolChanged);
      }
      final value = await _call(
        'getnotegroups',
        query: {'start': '$offset', 'length': '200', 'groupUuid': '-1'},
      );
      final rows = value['content'];
      final count = value['count'];
      if (rows is! List || count is! int || count < 0) {
        throw const CloudNoteException(
          CloudNoteFailure.protocolChanged,
          'meizu page',
        );
      }
      if (total != null && count != total) {
        throw const CloudNoteException(
          CloudNoteFailure.protocolChanged,
          'meizu count',
        );
      }
      total = count;
      for (final row in rows) {
        final id = row is Map ? row['uuid'] : null;
        if (id is! String || id.isEmpty || !seen.add(id)) {
          throw const CloudNoteException(
            CloudNoteFailure.protocolChanged,
            'meizu entry',
          );
        }
        final owner = (row as Map)['userId'];
        if (owner != null && owner != 0 && owner != '0' && '$owner' != uid) {
          throw const CloudNoteException(CloudNoteFailure.sessionExpired);
        }
        final note = _parseEntry(row.cast<String, Object?>(), folders);
        if (note != null) notes.add(note);
      }
      offset += rows.length;
      onProgress(offset, total);
      if (offset == total) break;
      if (rows.isEmpty || offset > total) {
        throw const CloudNoteException(
          CloudNoteFailure.protocolChanged,
          'meizu paging',
        );
      }
    }
    return notes;
  }

  /// 加密笔记与缺少正文或创建时间的条目记入 [issues] 并返回 null。
  CloudNote? _parseEntry(
    Map<String, Object?> entry,
    Map<String, String> folders,
  ) {
    final encrypt = entry['encrypt'];
    if (encrypt != null && encrypt != 0 && encrypt != '0') {
      issues.skip(JournalSkipReason.encrypted);
      return null;
    }
    final rawBody = entry['body'];
    final created = _time(entry['createTime']);
    if (rawBody is! String || created == null) {
      issues.skip(JournalSkipReason.unreadable);
      return null;
    }
    final files = entry['files'] is Map
        ? (entry['files'] as Map).cast<Object?, Object?>()
        : const <Object?, Object?>{};
    final names = <String>[];
    final blocks = decodeMeizuBody(rawBody, onAttachment: names.add);
    final attachments = <CloudAttachment>[];
    for (final name in {...names, ...files.keys.whereType<String>()}) {
      attachments.add(
        CloudAttachment(id: name, name: name, reference: files[name]),
      );
    }
    final group = entry['groupStatus'];
    return CloudNote(
      id: entry['uuid'] as String,
      title: entry['title'] is String ? entry['title'] as String : '',
      createdAt: created,
      updatedAt: _time(entry['modifyTime']),
      folder: group is String ? folders[group] : null,
      attachments: attachments,
      writeBody: (writer, resolve) => writeCloudBlocks(writer, blocks, resolve),
    );
  }

  @override
  Future<List<int>> download(CloudAttachment attachment) async {
    final raw = attachment.reference;
    if (raw is! String || raw.isEmpty) {
      throw const CloudNoteException(CloudNoteFailure.rejected, 'meizu url');
    }
    final Uri url;
    if (raw.startsWith('/') && !raw.startsWith('//')) {
      url = Uri.parse('$origin$raw');
    } else {
      final parsed = Uri.tryParse(raw);
      final host = parsed?.host.toLowerCase() ?? '';
      final safe =
          parsed != null &&
          parsed.scheme == 'https' &&
          (host == 'flyme.cn' ||
              host.endsWith('.flyme.cn') ||
              host == 'meizu.com' ||
              host.endsWith('.meizu.com')) &&
          !parsed.hasPort &&
          parsed.userInfo.isEmpty &&
          !parsed.hasFragment;
      if (!safe) {
        throw const CloudNoteException(CloudNoteFailure.rejected, 'meizu url');
      }
      url = parsed;
    }
    final response = await CloudNoteTransport(
      'https://${url.host}',
      http,
      wait: _wait,
    ).requestUrl('GET', url);
    final type = response.headers['content-type'] ?? '';
    if (type.startsWith('text/html') ||
        type.startsWith('application/json') ||
        response.bytes.isEmpty) {
      throw const CloudNoteException(
        CloudNoteFailure.rejected,
        'meizu file body',
      );
    }
    return response.bytes;
  }

  static DateTime? _time(Object? value) => value is num && value > 0
      ? DateTime.fromMillisecondsSinceEpoch(value.round())
      : null;
}

/// 解析魅族正文区块树。图片、录音、文件区块经 [onAttachment] 报告附件
/// 名称，并在正文中占一个附件块。
///
/// 参考实现是迁移工具，遇到未知区块、过深嵌套或不合法的样式区间就整篇
/// 拒绝（原笔记还在云端）；导入时整篇放弃等于丢掉这篇，所以这里尽量保留：
/// 未知区块留下文字（有子区块的照常展开），嵌套超过 6 层按 6 层，样式
/// 区间不合法时保留不带样式的文字，正文不是区块 JSON 时按纯文本逐行导入。
List<CloudBlock> decodeMeizuBody(
  String body, {
  required void Function(String name) onAttachment,
}) {
  Object? decoded;
  try {
    decoded = body.isEmpty ? const <Object?>[] : jsonDecode(body);
  } on FormatException {
    return [
      for (final line in body.split('\n'))
        CloudBlock.paragraph([if (line.isNotEmpty) CloudSpan(line)]),
    ];
  }
  final blocks = <CloudBlock>[];

  void visit(Object? items, int level, bool? ordered) {
    if (items is! List) return;
    for (final item in items) {
      if (item is! Map) continue;
      final state = item['state'];
      final text = item['text'] is String ? item['text'] as String : '';
      List<CloudSpan> spans() {
        try {
          return decodeMeizuSpans(text, item['span']);
        } on FormatException {
          return [if (text.isNotEmpty) CloudSpan(text)];
        }
      }

      switch (state) {
        case 50 || 51:
          visit(
            item['children'],
            min(level + (ordered == null ? 0 : 1), 6),
            state == 50,
          );
        case 53:
          visit(item['children'], level, ordered);
        case 0 || 1 || 2 || 60:
          final kind = switch (state) {
            60 => CloudBlockKind.heading,
            1 || 2 => CloudBlockKind.todo,
            _ when ordered != null => CloudBlockKind.list,
            _ => CloudBlockKind.paragraph,
          };
          final headingLevel = item['level'] is int ? item['level'] as int : 1;
          blocks.add(
            CloudBlock(
              kind,
              spans: spans(),
              level: state == 60 ? headingLevel.clamp(1, 6) : level,
              ordered: ordered ?? false,
              checked: state == 2,
            ),
          );
        case 3 || 4 || 5:
          final name = item['name'];
          if (name is! String || name.isEmpty) continue;
          onAttachment(name);
          blocks.add(CloudBlock(CloudBlockKind.attachment, attachmentId: name));
        default:
          if (text.isNotEmpty) blocks.add(CloudBlock.paragraph(spans()));
          visit(item['children'], level, ordered);
      }
    }
  }

  visit(decoded, 1, null);
  return blocks;
}

/// 按魅族 `span` 区间（UTF-16 偏移，起含止不含）切分文字：1 粗体（param
/// 为 0/2/3 时是段落对齐，忽略）、7 斜体、6 下划线、18 删除线、19 高亮、
/// 17 链接（param 为地址）；其他样式丢弃。区间越界、落在代理对中间或
/// 起止颠倒时抛出 [FormatException]。
List<CloudSpan> decodeMeizuSpans(String text, Object? raw) {
  final Object? ranges = switch (raw) {
    null || '' => const <Object?>[],
    final String json => jsonDecode(json),
    final List list => list,
    _ => throw const FormatException('meizu span'),
  };
  if (ranges is! List) throw const FormatException('meizu span');

  bool boundary(int offset) =>
      offset >= 0 &&
      offset <= text.length &&
      !(offset > 0 &&
          offset < text.length &&
          _isHigh(text.codeUnitAt(offset - 1)) &&
          _isLow(text.codeUnitAt(offset)));

  final kept = <({int start, int end, String flag, String? link})>[];
  for (final range in ranges) {
    if (range is! Map ||
        range['span'] is! int ||
        range['start'] is! int ||
        range['end'] is! int) {
      throw const FormatException('meizu range');
    }
    final start = range['start'] as int;
    final end = range['end'] as int;
    if (!boundary(start) || !boundary(end) || end < start) {
      throw const FormatException('meizu range bounds');
    }
    final param = range['param'];
    final flag = switch (range['span']) {
      1 when !const {0, 2, 3}.contains(param) => 'bold',
      7 => 'italic',
      6 => 'underline',
      18 => 'strike',
      19 => 'highlight',
      17 when param is String => 'link',
      _ => null,
    };
    if (flag != null) {
      kept.add((
        start: start,
        end: end,
        flag: flag,
        link: flag == 'link' ? param as String : null,
      ));
    }
  }
  if (text.isEmpty) return const <CloudSpan>[];
  final cuts = <int>{0, text.length};
  for (final range in kept) {
    cuts
      ..add(range.start)
      ..add(range.end);
  }
  final points = cuts.toList()..sort();
  final spans = <CloudSpan>[];
  for (var i = 0; i + 1 < points.length; i++) {
    final left = points[i];
    final active = kept.where(
      (range) => range.start <= left && left < range.end,
    );
    bool has(String flag) => active.any((range) => range.flag == flag);
    spans.add(
      CloudSpan(
        text.substring(left, points[i + 1]),
        bold: has('bold'),
        italic: has('italic'),
        underline: has('underline'),
        strike: has('strike'),
        highlight: has('highlight'),
        link: active
            .where((range) => range.flag == 'link')
            .map((range) => range.link)
            .firstOrNull,
      ),
    );
  }
  return spans;
}

bool _isHigh(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
bool _isLow(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;
