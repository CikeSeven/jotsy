import 'cloud_backup_models.dart';

/// WebDAV / S3 服务的预设：选中后预填地址、区域与寻址方式，名称与填写说明
/// 由界面按 [id] 本地化。
///
/// - [url] 是可直接使用的默认地址（坚果云、Koofr 等固定地址，或带默认区域的
///   对象存储端点）；为 null 时地址因账号而异，只把 [urlTemplate] 作为输入
///   提示，让用户照抄服务商页面上的地址；
/// - [virtualHostOnly] 的服务只支持虚拟主机寻址，界面锁定“路径风格”开关。
///
/// 已停用或收费改版的服务（Box、Icedrive 的 WebDAV）不收录；端点依据各家
/// 2025–2026 年的官方文档。
class CloudBackupPreset {
  const CloudBackupPreset({
    required this.id,
    required this.kind,
    this.url,
    this.urlTemplate,
    this.region,
    this.pathStyle = false,
    this.virtualHostOnly = false,
  });

  final String id;
  final CloudBackupKind kind;
  final String? url;
  final String? urlTemplate;
  final String? region;
  final bool pathStyle;
  final bool virtualHostOnly;

  /// 新建备份位置时的初始配置。
  Map<String, Object?> initialConfig() => switch (kind) {
    CloudBackupKind.webDav => <String, Object?>{
      'serverUrl': url ?? '',
      'username': '',
      'password': '',
      'remoteDirectory': '/jotsy/',
    },
    _ => <String, Object?>{
      'endpoint': url ?? '',
      'region': region ?? '',
      'bucket': '',
      'accessKeyId': '',
      'secretAccessKey': '',
      'prefix': 'jotsy/',
      'pathStyle': pathStyle,
    },
  };
}

/// 自定义（不套用任何预设）的 WebDAV 与 S3。
const customWebDavPreset = CloudBackupPreset(
  id: 'webdav',
  kind: CloudBackupKind.webDav,
  urlTemplate: 'https://nas.example.com:5006/webdav/',
);

const customS3Preset = CloudBackupPreset(
  id: 's3',
  kind: CloudBackupKind.s3,
  urlTemplate: 'https://s3.example.com',
);

const webDavPresets = <CloudBackupPreset>[
  CloudBackupPreset(
    id: 'jianguoyun',
    kind: CloudBackupKind.webDav,
    url: 'https://dav.jianguoyun.com/dav/',
  ),
  CloudBackupPreset(
    id: '123pan',
    kind: CloudBackupKind.webDav,
    urlTemplate: 'https://webdav-xxxx.pd1.123pan.cn/webdav',
  ),
  CloudBackupPreset(
    id: 'openlist',
    kind: CloudBackupKind.webDav,
    urlTemplate: 'http://192.168.1.2:5244/dav/',
  ),
  CloudBackupPreset(
    id: 'clouddrive2',
    kind: CloudBackupKind.webDav,
    urlTemplate: 'http://192.168.1.2:19798/dav',
  ),
  CloudBackupPreset(
    id: 'nextcloud',
    kind: CloudBackupKind.webDav,
    urlTemplate: 'https://cloud.example.com/remote.php/dav/files/USER/',
  ),
  CloudBackupPreset(
    id: 'owncloud',
    kind: CloudBackupKind.webDav,
    urlTemplate: 'https://cloud.example.com/remote.php/webdav/',
  ),
  CloudBackupPreset(
    id: 'seafile',
    kind: CloudBackupKind.webDav,
    urlTemplate: 'https://seafile.example.com/seafdav/',
  ),
  CloudBackupPreset(
    id: 'synology',
    kind: CloudBackupKind.webDav,
    urlTemplate: 'https://192.168.1.2:5006/',
  ),
  CloudBackupPreset(
    id: 'qnap',
    kind: CloudBackupKind.webDav,
    urlTemplate: 'https://192.168.1.2/Public/',
  ),
  CloudBackupPreset(
    id: 'koofr',
    kind: CloudBackupKind.webDav,
    url: 'https://app.koofr.net/dav/Koofr/',
  ),
  CloudBackupPreset(
    id: 'pcloud',
    kind: CloudBackupKind.webDav,
    url: 'https://webdav.pcloud.com/',
  ),
  CloudBackupPreset(
    id: 'pcloudEu',
    kind: CloudBackupKind.webDav,
    url: 'https://ewebdav.pcloud.com/',
  ),
  CloudBackupPreset(
    id: 'infinicloud',
    kind: CloudBackupKind.webDav,
    urlTemplate: 'https://NODE.teracloud.jp/dav/',
  ),
  CloudBackupPreset(
    id: 'hetzner',
    kind: CloudBackupKind.webDav,
    urlTemplate: 'https://USER.your-storagebox.de/',
  ),
  CloudBackupPreset(
    id: 'kdrive',
    kind: CloudBackupKind.webDav,
    urlTemplate: 'https://DRIVE_ID.connect.kdrive.infomaniak.com/',
  ),
  CloudBackupPreset(
    id: 'yandex',
    kind: CloudBackupKind.webDav,
    url: 'https://webdav.yandex.ru/',
  ),
  CloudBackupPreset(
    id: 'mailru',
    kind: CloudBackupKind.webDav,
    url: 'https://webdav.cloud.mail.ru/',
  ),
];

const s3Presets = <CloudBackupPreset>[
  CloudBackupPreset(
    id: 'aliyunOss',
    kind: CloudBackupKind.s3,
    url: 'https://s3.oss-cn-hangzhou.aliyuncs.com',
    urlTemplate: 'https://s3.oss-REGION.aliyuncs.com',
    region: 'cn-hangzhou',
    virtualHostOnly: true,
  ),
  CloudBackupPreset(
    id: 'tencentCos',
    kind: CloudBackupKind.s3,
    url: 'https://cos.ap-guangzhou.myqcloud.com',
    urlTemplate: 'https://cos.REGION.myqcloud.com',
    region: 'ap-guangzhou',
    virtualHostOnly: true,
  ),
  CloudBackupPreset(
    id: 'qiniuKodo',
    kind: CloudBackupKind.s3,
    url: 'https://s3.cn-east-1.qiniucs.com',
    urlTemplate: 'https://s3.REGION.qiniucs.com',
    region: 'cn-east-1',
  ),
  CloudBackupPreset(
    id: 'huaweiObs',
    kind: CloudBackupKind.s3,
    url: 'https://obs.cn-north-4.myhuaweicloud.com',
    urlTemplate: 'https://obs.REGION.myhuaweicloud.com',
    region: 'cn-north-4',
    virtualHostOnly: true,
  ),
  CloudBackupPreset(
    id: 'volcengineTos',
    kind: CloudBackupKind.s3,
    url: 'https://tos-s3-cn-beijing.volces.com',
    urlTemplate: 'https://tos-s3-REGION.volces.com',
    region: 'cn-beijing',
    virtualHostOnly: true,
  ),
  CloudBackupPreset(
    id: 'baiduBos',
    kind: CloudBackupKind.s3,
    url: 'https://s3.bj.bcebos.com',
    urlTemplate: 'https://s3.REGION.bcebos.com',
    region: 'bj',
  ),
  CloudBackupPreset(
    id: 'jdcloudOss',
    kind: CloudBackupKind.s3,
    url: 'https://s3.cn-north-1.jdcloud-oss.com',
    urlTemplate: 'https://s3.REGION.jdcloud-oss.com',
    region: 'cn-north-1',
  ),
  CloudBackupPreset(
    id: 'awsS3',
    kind: CloudBackupKind.s3,
    url: 'https://s3.us-east-1.amazonaws.com',
    urlTemplate: 'https://s3.REGION.amazonaws.com',
    region: 'us-east-1',
  ),
  CloudBackupPreset(
    id: 'awsS3China',
    kind: CloudBackupKind.s3,
    url: 'https://s3.cn-north-1.amazonaws.com.cn',
    urlTemplate: 'https://s3.REGION.amazonaws.com.cn',
    region: 'cn-north-1',
  ),
  CloudBackupPreset(
    id: 'cloudflareR2',
    kind: CloudBackupKind.s3,
    urlTemplate: 'https://ACCOUNT_ID.r2.cloudflarestorage.com',
    region: 'auto',
  ),
  CloudBackupPreset(
    id: 'backblazeB2',
    kind: CloudBackupKind.s3,
    urlTemplate: 'https://s3.us-west-004.backblazeb2.com',
  ),
  CloudBackupPreset(
    id: 'wasabi',
    kind: CloudBackupKind.s3,
    url: 'https://s3.us-east-1.wasabisys.com',
    urlTemplate: 'https://s3.REGION.wasabisys.com',
    region: 'us-east-1',
  ),
  CloudBackupPreset(
    id: 'digitalOceanSpaces',
    kind: CloudBackupKind.s3,
    url: 'https://nyc3.digitaloceanspaces.com',
    urlTemplate: 'https://REGION.digitaloceanspaces.com',
    // Spaces 的签名区域固定填 us-east-1，与端点里的数据中心无关。
    region: 'us-east-1',
  ),
  CloudBackupPreset(
    id: 'scaleway',
    kind: CloudBackupKind.s3,
    url: 'https://s3.fr-par.scw.cloud',
    urlTemplate: 'https://s3.REGION.scw.cloud',
    region: 'fr-par',
  ),
  CloudBackupPreset(
    id: 'storj',
    kind: CloudBackupKind.s3,
    url: 'https://gateway.storjshare.io',
    region: 'us-east-1',
    pathStyle: true,
  ),
  CloudBackupPreset(
    id: 'idriveE2',
    kind: CloudBackupKind.s3,
    urlTemplate: 'https://s3.REGION.idrivee2.com',
    pathStyle: true,
  ),
  CloudBackupPreset(
    id: 'akamaiLinode',
    kind: CloudBackupKind.s3,
    url: 'https://us-east-1.linodeobjects.com',
    urlTemplate: 'https://CLUSTER.linodeobjects.com',
    region: 'us-east-1',
  ),
  CloudBackupPreset(
    id: 'oracleOci',
    kind: CloudBackupKind.s3,
    urlTemplate:
        'https://NAMESPACE.compat.objectstorage.REGION.oraclecloud.com',
    pathStyle: true,
  ),
  CloudBackupPreset(
    id: 'googleCloudStorage',
    kind: CloudBackupKind.s3,
    url: 'https://storage.googleapis.com',
    region: 'auto',
    pathStyle: true,
  ),
  CloudBackupPreset(
    id: 'minio',
    kind: CloudBackupKind.s3,
    urlTemplate: 'http://192.168.1.2:9000',
    region: 'us-east-1',
    pathStyle: true,
  ),
];

CloudBackupPreset? cloudBackupPresetById(String? id) {
  if (id == null) return null;
  for (final preset in <CloudBackupPreset>[
    customWebDavPreset,
    customS3Preset,
    ...webDavPresets,
    ...s3Presets,
  ]) {
    if (preset.id == id) return preset;
  }
  return null;
}
