import 'journal_import_cloud.dart';
import 'journal_import_cloud_honor.dart';
import 'journal_import_cloud_huawei.dart';
import 'journal_import_cloud_meizu.dart';
import 'journal_import_cloud_oppo.dart';
import 'journal_import_cloud_vivo.dart';
import 'journal_import_cloud_wps.dart';
import 'journal_import_cloud_xiaomi.dart';
import 'journal_import_models.dart';

/// 在应用内登录后从云端读取笔记的平台：官方登录页与需要读取登录 Cookie
/// 的接口源（参考实现「笔记互迁」`providers/base.py` 与 `factory.py`）。
///
/// 网页视图按地址返回 Cookie，丢失了域名与路径信息，所以路径受限的
/// Cookie 要按接口路径读取（如华为 `/notepad/` 下的 shareToken），文件
/// 服务另在其他主机时也要列出（荣耀 `config/web` 的 `viteDownloadDomain`，
/// 不带它的登录 Cookie 时文件服务回 401，整次读取会被当成登录失效）。
final Map<JournalImportSource, CloudNotePlatform> cloudNotePlatforms = {
  JournalImportSource.xiaomiNotes: CloudNotePlatform(
    source: JournalImportSource.xiaomiNotes,
    loginUrl: 'https://i.mi.com/note/h5',
    cookieOrigins: const ['https://i.mi.com/'],
    create: XiaomiCloudProvider.new,
  ),
  JournalImportSource.huaweiNotepad: CloudNotePlatform(
    source: JournalImportSource.huaweiNotepad,
    loginUrl: 'https://cloud.huawei.com/home',
    cookieOrigins: const [
      'https://cloud.huawei.com/',
      'https://cloud.huawei.com/notepad/',
      'https://cloud.huawei.com/html/',
      'https://cloud.huawei.com/proxyserver/',
      'https://cloud.huawei.com/proxy/',
    ],
    create: HuaweiCloudProvider.new,
  ),
  JournalImportSource.oppoNotes: CloudNotePlatform(
    source: JournalImportSource.oppoNotes,
    loginUrl: 'https://cloud.oppo.com/',
    cookieOrigins: const ['https://owork-api-cn.oppo.com/'],
    create: OppoCloudProvider.new,
  ),
  JournalImportSource.vivoNotes: CloudNotePlatform(
    source: JournalImportSource.vivoNotes,
    loginUrl: 'https://yun.vivo.com.cn/',
    cookieOrigins: const ['https://pc.vivo.com.cn/'],
    create: VivoCloudProvider.new,
  ),
  JournalImportSource.honorNotes: CloudNotePlatform(
    source: JournalImportSource.honorNotes,
    loginUrl: 'https://cloud.honor.com/',
    cookieOrigins: const [
      'https://cloud.honor.com/',
      'https://fileproxy-drcn.cloud.honor.com/',
    ],
    create: HonorCloudProvider.new,
  ),
  JournalImportSource.meizuNotes: CloudNotePlatform(
    source: JournalImportSource.meizuNotes,
    loginUrl: 'https://cloud.flyme.cn/browser/main.jsp',
    cookieOrigins: const ['https://notes.flyme.cn/'],
    create: MeizuCloudProvider.new,
  ),
  JournalImportSource.wpsNotes: CloudNotePlatform(
    source: JournalImportSource.wpsNotes,
    loginUrl: 'https://note.wps.cn/',
    cookieOrigins: const [
      'https://note-api.wps.cn/',
      'https://account.wps.cn/',
    ],
    create: WpsCloudProvider.new,
  ),
};
