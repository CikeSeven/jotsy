import 'journal_import_block_writer.dart';
import 'journal_import_cloud.dart';
import 'journal_import_cloud_http.dart';
import 'journal_import_markdown.dart';
import 'journal_import_models.dart';
import 'journal_import_support.dart';

/// 锤子便签（欢喜云 yun.smartisan.com）的只读客户端。官方没有导出功能，
/// 协议依据网页版便签与三份独立的开源导出脚本（phone-cloud-data-export
/// `smartisan-notes/1-capture.js`、smartisan-notes-export、
/// Smartisan-notes-downloader），三者字段口径一致：
///
/// - 接口都是 `GET /apps/note/index.php?r=<动作>`，带
///   `X-Requested-With: XMLHttpRequest`，只靠 Cookie 鉴权；响应
///   `{code, data}`，`code` 为 1 是出错（`errInfo` 里带具体错误码），未登录
///   为 1701（也可能出现在 `errInfo` 的键里）；
/// - `account/login` 检查登录态；`folder/getList` 取分类（数组，或包在
///   `noteFolder` / `list` 里）；`v2/getList?page&page_size` 分页取全部便签
///   （`data.note.list`、`data.note.page_count`，页码从 1 开始），正文内嵌
///   在条目里，分页边界可能重复，按 `sync_id` 去重；
/// - `folder_type` 为 3 是回收站，不导入；`folderId` 为空或 `"0"` 是未分类，
///   指向已不存在的分类时同样按未分类；
/// - 只有修改时间 `modify_time`（毫秒），接口不返回创建时间，发表时间只能
///   取修改时间；
/// - `title` 不是独立字段，是服务端截取正文第一行生成的（只有图片时为
///   “图片便签”），导入时不作标题，免得第一行重复出现；
/// - 正文 `detail` 是纯文本（`markdown` 为 1 的便签按 Markdown 解释），
///   图片是内联的自定义标记 `<image w=宽 h=高 describe=说明 name=文件名>`，
///   文件名为 `Notes_<时间>.jpeg` 或不带扩展名的哈希，文件在
///   `/apps/note/notesimage/<文件名>`，同样要登录态。
class SmartisanCloudProvider implements CloudNoteProvider {
  SmartisanCloudProvider(this.http, {Future<void> Function(Duration)? wait})
    : _api = CloudNoteTransport(
        origin,
        http,
        headers: const {'X-Requested-With': 'XMLHttpRequest'},
        wait: wait,
      );

  static const String origin = 'https://yun.smartisan.com';
  static const String _endpoint = '/apps/note/index.php';
  static const String _imagePath = '/apps/note/notesimage/';

  /// 网页版默认每页 3000 条。
  static const int _pageSize = 3000;

  final CloudNoteHttp http;
  final CloudNoteTransport _api;

  @override
  final CloudReadIssues issues = CloudReadIssues();

  Future<Object?> _call(
    String route, {
    Map<String, String> query = const {},
  }) async {
    final payload = await _api.json(
      'GET',
      _endpoint,
      query: {'r': route, ...query},
    );
    throwIfSmartisanError(payload, route);
    return payload['data'];
  }

  @override
  Future<String> probe() async {
    final account = await _call('account/login');
    // 未登录时 data 为空；登录后是账号信息，取不到账号 ID 时只确认已登录。
    if (account == null ||
        account == false ||
        account == '' ||
        (account is Map && account.isEmpty) ||
        (account is List && account.isEmpty)) {
      throw const CloudNoteException(CloudNoteFailure.sessionExpired);
    }
    final uid = account is Map
        ? journalId(account['uid']) ??
              journalId(account['user_id']) ??
              journalId(account['id'])
        : null;
    return uid == null ? 'smartisan' : 'smartisan:$uid';
  }

  @override
  Future<List<CloudNote>> fetchNotes(CloudProgress onProgress) async {
    final folders = decodeSmartisanFolders(await _call('folder/getList'));
    final notes = <CloudNote>[];
    final seen = <String>{};
    var read = 0;
    int? pageCount;
    for (var page = 1; pageCount == null || page <= pageCount; page++) {
      if (page > 10000) {
        throw const CloudNoteException(CloudNoteFailure.protocolChanged);
      }
      final data = await _call(
        'v2/getList',
        query: {'page': '$page', 'page_size': '$_pageSize'},
      );
      final note = data is Map ? data['note'] : null;
      if (note is! Map || note['list'] is! List) {
        throw const CloudNoteException(
          CloudNoteFailure.protocolChanged,
          'smartisan page',
        );
      }
      final rows = note['list'] as List;
      // 没有分页信息时只有这一页；页数在翻页中途变化说明列表被改动，结果
      // 可能漏掉便签，停止读取。
      final pages = note.containsKey('page_count')
          ? journalNumber(note['page_count'])
          : 1;
      if (pages == null || pages < 0 || pages != pages.truncate()) {
        throw const CloudNoteException(
          CloudNoteFailure.protocolChanged,
          'smartisan page count',
        );
      }
      final total = journalNumber(note['total'])?.toInt();
      if (pageCount != null && pages != pageCount) {
        throw const CloudNoteException(
          CloudNoteFailure.protocolChanged,
          'smartisan page count',
        );
      }
      pageCount = pages.toInt();
      // 旧版接口把分类放在便签列表的 data.folder 里。
      if (data is Map && data['folder'] is List) {
        for (final MapEntry(:key, :value) in decodeSmartisanFolders(
          data['folder'],
        ).entries) {
          folders.putIfAbsent(key, () => value);
        }
      }
      for (final row in rows) {
        final id = row is Map ? journalId(row['sync_id']) : null;
        if (id == null) {
          throw const CloudNoteException(
            CloudNoteFailure.protocolChanged,
            'smartisan entry',
          );
        }
        // 分页边界的重复条目只取第一次出现的。
        if (!seen.add(id)) continue;
        final parsed = _parseEntry(
          id,
          (row as Map).cast<String, Object?>(),
          folders,
        );
        if (parsed != null) notes.add(parsed);
      }
      read += rows.length;
      // total 含回收站，只用于显示进度。
      onProgress(read, total != null && total >= read ? total : null);
    }
    return notes;
  }

  /// 回收站里的便签返回 null，不计入问题；上锁且读不到正文、缺少正文或
  /// 修改时间的条目记入 [issues] 并返回 null。
  CloudNote? _parseEntry(
    String id,
    Map<String, Object?> entry,
    Map<String, String> folders,
  ) {
    if (journalId(entry['folder_type']) == '3') return null;
    final detail = entry['detail'];
    final updated = _time(entry['modify_time']);
    // 上锁的便签：服务端按正文生成标题，正文是明文时照常导入；读不到正文
    // 才按加密跳过，不把空便签当成导入成功。
    if (_flag(entry['is_locked']) &&
        (detail is! String || detail.trim().isEmpty)) {
      issues.skip(JournalSkipReason.encrypted);
      return null;
    }
    if (detail is! String || updated == null) {
      issues.skip(JournalSkipReason.unreadable);
      return null;
    }
    final body = detail;
    final images = smartisanImageNames(body);
    final folderId = journalId(entry['folderId']);
    final markdown = _flag(entry['markdown']);
    return CloudNote(
      id: id,
      title: '',
      createdAt: updated,
      updatedAt: updated,
      folder: folderId == null || folderId == '0' ? null : folders[folderId],
      attachments: [
        for (final name in images) CloudAttachment(id: name, name: name),
      ],
      writeBody: (writer, resolve) =>
          writeSmartisanBody(writer, body, resolve, markdown: markdown),
    );
  }

  @override
  Future<List<int>> download(CloudAttachment attachment) async {
    // 文件名整体编码成一个路径段，不能借 `/`、`..` 走出图片目录。
    final response = await _api.request(
      'GET',
      '$_imagePath${Uri.encodeComponent(attachment.id)}',
    );
    final type = (response.headers['content-type'] ?? '').toLowerCase();
    // 未登录或文件不存在时返回的是 JSON 错误或网页，不能当成图片保存。错误
    // 响应不一定带 JSON 的类型头，正文以 `{` 开头时同样按 JSON 检查（图片
    // 文件头不会是 `{`）。
    final bytes = response.bytes;
    var first = 0;
    while (first < bytes.length &&
        const [9, 10, 13, 32].contains(bytes[first])) {
      first++;
    }
    if (type.contains('json') ||
        (first < bytes.length && bytes[first] == 0x7B)) {
      try {
        throwIfSmartisanError(decodeCloudJson(response.text), 'image');
      } on CloudNoteException catch (error) {
        if (error.failure == CloudNoteFailure.sessionExpired) rethrow;
      }
      throw const CloudNoteException(
        CloudNoteFailure.rejected,
        'smartisan image body',
      );
    }
    if (type.startsWith('text/') || response.bytes.isEmpty) {
      throw const CloudNoteException(
        CloudNoteFailure.rejected,
        'smartisan image body',
      );
    }
    return response.bytes;
  }

  /// 毫秒时间戳；早期分类等字段用秒，小于 1e11 的数值按秒换算。
  static DateTime? _time(Object? value) {
    final number = journalNumber(value);
    if (number == null || number <= 0) return null;
    return journalEpochTime(number < 1e11 ? number * 1000 : number);
  }

  static bool _flag(Object? value) =>
      value == true || journalNumber(value) == 1;
}

/// 业务错误：`code` 为 1701、或 `errInfo` 里带 1701 是登录失效；`code` 为 1
/// 或带 `errInfo` 的其他错误是被拒绝。其余视为成功（与网页版前端一致）。
void throwIfSmartisanError(Map<String, Object?> payload, String route) {
  final code = journalId(payload['code']);
  final errors = payload['errInfo'];
  final errorCodes = errors is Map
      ? errors.keys.map((key) => '$key').toSet()
      : const <String>{};
  if (code == '1701' || errorCodes.contains('1701')) {
    throw const CloudNoteException(CloudNoteFailure.sessionExpired);
  }
  if (code == '1' || errorCodes.isNotEmpty) {
    throw CloudNoteException(CloudNoteFailure.rejected, 'smartisan $route');
  }
}

/// 分类列表 → `sync_id` 到名称。接受数组，或包在 `noteFolder` / `list` 里的
/// 数组；其他结构视为协议变化，免得所有便签都丢了所在分类。
Map<String, String> decodeSmartisanFolders(Object? data) {
  final Object? rows = switch (data) {
    final List list => list,
    final Map map when map['noteFolder'] is List => map['noteFolder'],
    final Map map when map['list'] is List => map['list'],
    null => const <Object?>[],
    _ => null,
  };
  if (rows is! List) {
    throw const CloudNoteException(
      CloudNoteFailure.protocolChanged,
      'smartisan folders',
    );
  }
  return {
    for (final row in rows)
      if (row is Map)
        if ((journalId(row['sync_id']), journalString(row['title'])) case (
          final String id,
          final String title,
        ))
          id: title,
  };
}

/// 图片标记：`<image w=95 h=53 describe= name=Notes_1700000000000.jpeg>`。
/// 说明可以为空、也可能含空格；文件名不含空白与 `>`。
final RegExp _imageTag = RegExp(r'<image\b[^>\n]*?\bname=([^\s>]+)[^>\n]*>');

/// 正文里引用的图片文件名（按出现顺序去重）。
List<String> smartisanImageNames(String detail) => [
  ...{for (final match in _imageTag.allMatches(detail)) match.group(1)!},
];

/// 写出正文：图片标记换成独占一行的图片，其余文字逐行写入（`markdown` 为
/// 1 时按 Markdown 解释）。图片与文字同在一行时拆成前后两行；只有图片的
/// 行不再多出空行，便签里的空行照原样保留。
void writeSmartisanBody(
  JournalBlockWriter writer,
  String detail,
  CloudEmbedResolver resolve, {
  bool markdown = false,
}) {
  final text = detail.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (markdown) {
    // 换成 Markdown 图片占位，由转换器在原位置嵌入；编号对应文件名，
    // 文件名本身不进 Markdown，免得特殊字符改变语法。
    final names = <String>[];
    final source = text.replaceAllMapped(_imageTag, (match) {
      names.add(match.group(1)!);
      return '![]($_imagePlaceholder${names.length - 1})';
    });
    JournalMarkdownConverter(
      writer,
      resolveEmbed: (src) {
        if (!src.startsWith(_imagePlaceholder)) return null;
        final index = int.tryParse(src.substring(_imagePlaceholder.length));
        return index == null || index >= names.length
            ? null
            : resolve(names[index]);
      },
    ).append(source);
    return;
  }
  for (final line in text.split('\n')) {
    var start = 0;
    var hasImage = false;
    for (final match in _imageTag.allMatches(line)) {
      hasImage = true;
      final before = line.substring(start, match.start);
      if (before.trim().isNotEmpty) {
        writer
          ..text(before)
          ..endLine();
      }
      final data = resolve(match.group(1)!);
      if (data != null) writer.embed(data);
      start = match.end;
    }
    final rest = line.substring(start);
    if (!hasImage || rest.trim().isNotEmpty) {
      writer
        ..text(rest)
        ..endLine();
    }
  }
}

const String _imagePlaceholder = 'smartisan-image:';
