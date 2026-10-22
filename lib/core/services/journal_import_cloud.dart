import 'journal_import_cloud_http.dart';
import 'journal_import_block_writer.dart';
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

  /// 所在分组（文件夹）名称，记为所在日记本（[JournalImportEntry.notebooks]），
  /// 落成日记本还是标签由 [JournalImportFolderMode] 决定。
  final String? folder;
  final List<CloudAttachment> attachments;
  final void Function(JournalBlockWriter writer, CloudEmbedResolver resolve)
  writeBody;
}

/// 读取进度：已处理 [done] 篇，[total] 未知时为 null。
typedef CloudProgress = void Function(int done, int? total);

/// 一次读取中没能完整导入的笔记，由平台在 [CloudNoteProvider.fetchNotes]
/// 里记下，导入预览据此逐项说明，免得笔记悄悄少了没人发现。
class CloudReadIssues extends JournalImportIssues {}

/// 一个平台的只读云端客户端（协议依据参考实现「笔记互迁」的 providers）。
abstract interface class CloudNoteProvider {
  /// 真实的权限检查：读取账号信息，未登录时抛出
  /// [CloudNoteFailure.sessionExpired]；返回不透明的账号标识。
  Future<String> probe();

  /// 读取全部笔记（不含回收站），分页与详情请求由平台实现；整篇跳过的
  /// 笔记与只读到摘要的笔记记在 [issues] 中。
  Future<List<CloudNote>> fetchNotes(CloudProgress onProgress);

  /// [fetchNotes] 没能完整导入的笔记；[fetchCloudJournal] 每次读取前清零。
  CloudReadIssues get issues;

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
  provider.issues.reset();
  final notes = await provider.fetchNotes(onProgress ?? (_, _) {});
  final ids = <String>{};
  for (final note in notes) {
    if (note.id.trim().isEmpty || !ids.add(note.id)) {
      throw const CloudNoteException(
        CloudNoteFailure.protocolChanged,
        'note id',
      );
    }
  }
  final entries = <JournalImportEntry>[];
  for (final (index, note) in notes.indexed) {
    final embeds = <String, Map<String, Object?>>{};
    final attempted = <String>{};
    for (final attachment in note.attachments) {
      if (!attempted.add(attachment.id)) continue;
      try {
        final bytes = await provider.download(attachment);
        if (bytes.isEmpty) {
          media.missingCount++;
          continue;
        }
        embeds[attachment.id] = media.embedBytes(
          bytes,
          name: attachment.name,
          mime: attachment.mime,
        );
      } on CloudNoteException catch (error) {
        if (isFatalCloudFailure(error.failure)) rethrow;
        media.missingCount++;
      }
    }
    final used = <String>{};
    final writer = JournalBlockWriter();
    note.writeBody(writer, (id) {
      final data = embeds[id];
      if (data != null) used.add(id);
      if (data == null && attempted.add(id)) media.missingCount++;
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
        notebooks: [
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
    skippedNotes: provider.issues.skipped,
    summaryOnlyCount: provider.issues.summaryOnly,
    partialContentCount: provider.issues.partialContent,
  );
}

/// 会让整次读取不完整的失败（登录失效、限流、断网、账号不支持），一律中止
/// 读取；其他失败（单个文件被拒、服务端错误等）只影响当前这一项。
bool isFatalCloudFailure(CloudNoteFailure failure) => switch (failure) {
  CloudNoteFailure.sessionExpired ||
  CloudNoteFailure.rateLimited ||
  CloudNoteFailure.network ||
  CloudNoteFailure.protocolChanged ||
  CloudNoteFailure.unsupportedAccount => true,
  _ => false,
};
