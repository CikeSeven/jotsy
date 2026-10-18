import 'journal_import_cloud_http.dart';
import 'journal_import_delta_writer.dart';
import 'journal_import_media.dart';
import 'journal_import_models.dart';

/// 云端笔记中的一个附件。[id] 是正文里引用它的标识；[reference] 是平台
/// 下载它所需的原始数据（文件 ID、签名参数等），只由对应平台解释。
class CloudAttachment {
  const CloudAttachment({
    required this.id,
    required this.name,
    this.mime,
    this.reference,
  });

  final String id;
  final String name;
  final String? mime;
  final Object? reference;
}

/// 根据附件 [CloudAttachment.id] 返回已暂存媒体的嵌入数据；附件未下载到
/// 时返回 null，该引用被丢弃。
typedef CloudEmbedResolver = Map<String, Object?>? Function(String id);

/// 从云端读到的一篇笔记。正文在附件全部下载后才由 [writeBody] 转换，转换
/// 本身是同步的内存操作。
class CloudNote {
  const CloudNote({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.writeBody,
    this.updatedAt,
    this.folder,
    this.attachments = const <CloudAttachment>[],
  });

  /// 平台内稳定的笔记 ID，作为导入稳定键。
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime? updatedAt;

  /// 所在分组（文件夹）名称，导入为标签。
  final String? folder;
  final List<CloudAttachment> attachments;
  final void Function(JournalDeltaWriter writer, CloudEmbedResolver resolve)
  writeBody;
}

/// 读取进度：已处理 [done] 篇，[total] 未知时为 null。
typedef CloudProgress = void Function(int done, int? total);

/// 一个平台的只读云端客户端（协议依据参考实现「笔记互迁」的 providers）。
abstract interface class CloudNoteProvider {
  /// 真实的权限检查：读取账号信息，未登录时抛出
  /// [CloudNoteFailure.sessionExpired]；返回不透明的账号标识。
  Future<String> probe();

  /// 读取全部笔记（不含回收站），分页与详情请求由平台实现。
  Future<List<CloudNote>> fetchNotes(CloudProgress onProgress);

  /// 下载附件原始字节。
  Future<List<int>> download(CloudAttachment attachment);
}

/// 平台的登录与接口参数。
class CloudNotePlatform {
  const CloudNotePlatform({
    required this.source,
    required this.loginUrl,
    required this.cookieOrigins,
    required this.create,
  });

  final JournalImportSource source;

  /// 在网页视图中打开的官方登录页。
  final String loginUrl;

  /// 需要从网页视图读取 Cookie 的接口源，读到的 Cookie 只发往对应主机。
  final List<String> cookieOrigins;

  /// 用带登录 Cookie 的 HTTP 客户端创建平台客户端。
  final CloudNoteProvider Function(CloudNoteHttp http) create;
}

/// 读取全部云端笔记，下载附件到暂存区，转换为导入条目。
///
/// 附件下载失败（链接过期、文件已删除）只计入缺失，不中断整次导入；登录
/// 失效、协议变化等会让结果不完整的错误直接抛出，不写入任何数据。正文
/// 没有引用的附件按平台给出的顺序追加在末尾。
Future<JournalImportParseResult> fetchCloudJournal(
  CloudNoteProvider provider,
  JournalMediaStager media, {
  CloudProgress? onProgress,
}) async {
  final notes = await provider.fetchNotes(onProgress ?? (_, _) {});
  final entries = <JournalImportEntry>[];
  for (final (index, note) in notes.indexed) {
    final embeds = <String, Map<String, Object?>>{};
    for (final attachment in note.attachments) {
      if (embeds.containsKey(attachment.id)) continue;
      try {
        final bytes = await provider.download(attachment);
        embeds[attachment.id] = media.embedBytes(
          bytes,
          name: attachment.name,
          mime: attachment.mime,
        );
      } on CloudNoteException catch (error) {
        if (_fatal(error.failure)) rethrow;
        media.missingCount++;
      }
    }
    final used = <String>{};
    final writer = JournalDeltaWriter();
    note.writeBody(writer, (id) {
      final data = embeds[id];
      if (data != null) used.add(id);
      return data;
    });
    for (final attachment in note.attachments) {
      final data = embeds[attachment.id];
      if (data != null && used.add(attachment.id)) writer.embed(data);
    }
    final content = writer.build();
    entries.add(
      JournalImportEntry(
        sourceKey: note.id,
        title: note.title.trim(),
        contentJson: content.contentJson,
        contentText: content.contentText,
        createdAt: note.createdAt,
        updatedAt: note.updatedAt,
        tags: [
          if (note.folder?.trim() case final folder? when folder.isNotEmpty)
            folder,
        ],
      ),
    );
    onProgress?.call(index + 1, notes.length);
  }
  return JournalImportParseResult(
    entries: entries,
    missingMediaCount: media.missingCount,
  );
}

bool _fatal(CloudNoteFailure failure) => switch (failure) {
  CloudNoteFailure.sessionExpired ||
  CloudNoteFailure.rateLimited ||
  CloudNoteFailure.network ||
  CloudNoteFailure.unsupportedAccount => true,
  _ => false,
};
