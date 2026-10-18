import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'journal_import_cloud_blocks.dart';
import 'journal_import_cloud_envelope.dart';
import 'journal_import_cloud_http.dart';

/// WPS 便签的字段加解密：标题、摘要、正文与 S3 凭据都以 AES-128-CBC 加密
/// （固定 IV）。网页版先用固定引导串的 MD5 解出 `web-config` 返回的
/// `aesPassword`，再以该密码的 MD5 作为字段密钥（参考实现 `wps.py` 的
/// WpsCodec，常量来自官方网页脚本）。
class WpsCodec {
  WpsCodec(String aesPassword) {
    final password = utf8.decode(
      aesCbc(
        md5.convert(utf8.encode(_bootstrap)).bytes,
        _iv,
        base64.decode(Uri.decodeComponent(aesPassword)),
        false,
      ),
    );
    if (password.isEmpty) throw const FormatException('wps password');
    _key = md5.convert(utf8.encode(password)).bytes;
  }

  static const String _bootstrap = 'H9n&S@oGohGpV6d7*';
  static final List<int> _iv = ascii.encode('5150956153345366');

  late final List<int> _key;

  /// 解密 Base64 字段；空串原样返回。
  String decrypt(String value) =>
      value.isEmpty ? '' : decryptBytes(base64.decode(value));

  /// 解密对象存储里的原始密文字节（长正文）。
  String decryptBytes(List<int> bytes) =>
      utf8.decode(aesCbc(_key, _iv, bytes, false));
}

/// WPS 正文里的媒体行：对象键（`-` 换成 `/`）、是否录音、原文件名（行尾
/// `{…}` 参数里有 `name` 时）。
typedef WpsMedia = ({String key, bool audio, String? name});

/// 解析 WPS 便签正文（类 Markdown 的逐行语法，参考实现 `decode_body`）：
///
/// - 一行一块，末尾的一个空行忽略；
/// - `![](<键>){w:…;h:…}` 图片行、`![audio](<键>){…}` 录音行独占一块；其他
///   `![…](<键>){…}` 行（视频、文件等参考实现未覆盖的媒体）同样按对象键作为
///   附件导入，下载不到的计入缺失，不再整篇放弃；
/// - 行首依次识别 `- [ ] `/`- [x] ` 待办，`### `/`## ` 标题，`0. ` 有序与
///   `* ` 无序列表（没有嵌套）；
/// - 行内 `***`/`**`/`*` 为粗斜体/粗体/斜体，`~` 为下划线，`\X` 转义。
/// 媒体块的附件 ID 是对象键的 SHA-256。
List<CloudBlock> decodeWpsBody(
  String body, {
  required void Function(WpsMedia media) onMedia,
}) {
  final lines = body.split('\n');
  if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
  final blocks = <CloudBlock>[];
  final image = RegExp(r'^!\[.*\]\(([^)]*)\)\{w:[0-9]+;h:[0-9]+\}$');
  final other = RegExp(r'^!\[([^\]]*)\]\(([^)]*)\)\{([^}]*)\}$');
  for (var line in lines) {
    final imageLine = image.firstMatch(line);
    final otherLine = imageLine == null ? other.firstMatch(line) : null;
    if (imageLine != null || otherLine != null) {
      final key = (imageLine?.group(1) ?? otherLine!.group(2)!).replaceAll(
        '-',
        '/',
      );
      onMedia((
        key: key,
        audio: otherLine?.group(1) == 'audio',
        name: otherLine == null ? null : _mediaName(otherLine.group(3)!),
      ));
      blocks.add(
        CloudBlock(CloudBlockKind.attachment, attachmentId: wpsMediaId(key)),
      );
      continue;
    }
    var kind = CloudBlockKind.paragraph;
    var level = 1;
    var ordered = false;
    var checked = false;
    if (line.startsWith('- [ ] ') || line.startsWith('- [x] ')) {
      kind = CloudBlockKind.todo;
      checked = line.startsWith('- [x] ');
      line = line.substring(6);
    }
    if (line.startsWith('### ')) {
      kind = CloudBlockKind.heading;
      level = 3;
      line = line.substring(4);
    } else if (line.startsWith('## ')) {
      kind = CloudBlockKind.heading;
      level = 2;
      line = line.substring(3);
    } else if (line.startsWith('0. ')) {
      kind = CloudBlockKind.list;
      ordered = true;
      line = line.substring(3);
    } else if (line.startsWith('* ')) {
      kind = CloudBlockKind.list;
      line = line.substring(2);
    }
    blocks.add(
      CloudBlock(
        kind,
        spans: wpsInlineSpans(line),
        level: level,
        ordered: ordered,
        checked: checked,
      ),
    );
  }
  return blocks;
}

String wpsMediaId(String key) => sha256.convert(utf8.encode(key)).toString();

/// 媒体行参数 `{k:v;k:v}` 里的原文件名（`name` / `fileName` / `title`）。
String? _mediaName(String parameters) {
  for (final pair in parameters.split(';')) {
    final colon = pair.indexOf(':');
    if (colon <= 0) continue;
    final key = pair.substring(0, colon).trim().toLowerCase();
    final value = pair.substring(colon + 1).trim();
    if (const {'name', 'filename', 'title'}.contains(key) && value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

/// 行内标记（逐字对应参考实现 `inline_spans`）：标记必须与后面第一个相同
/// 的标记配对，内部递归解析并继承格式；没有配对的标记按字面保留。
List<CloudSpan> wpsInlineSpans(
  String text, {
  bool bold = false,
  bool italic = false,
  bool underline = false,
}) {
  final tokens = RegExp(r'\\.|\*{1,3}|~').allMatches(text).toList();
  final spans = <CloudSpan>[];
  CloudSpan span(String value) =>
      CloudSpan(value, bold: bold, italic: italic, underline: underline);
  var cursor = 0;
  var index = 0;
  while (index < tokens.length) {
    final token = tokens[index];
    if (token.start < cursor) {
      index++;
      continue;
    }
    if (token.start > cursor) {
      spans.add(span(text.substring(cursor, token.start)));
    }
    final mark = token.group(0)!;
    if (mark.startsWith(r'\')) {
      spans.add(span(mark.substring(1)));
      cursor = token.end;
      index++;
      continue;
    }
    var end = -1;
    for (var i = index + 1; i < tokens.length; i++) {
      if (tokens[i].group(0) == mark) {
        end = i;
        break;
      }
    }
    if (end < 0) {
      spans.add(span(mark));
      cursor = token.end;
      index++;
      continue;
    }
    spans.addAll(
      wpsInlineSpans(
        text.substring(token.end, tokens[end].start),
        bold: bold || mark == '***' || mark == '**',
        italic: italic || mark == '***' || mark == '*',
        underline: underline || mark == '~',
      ),
    );
    cursor = tokens[end].end;
    index = end + 1;
  }
  if (cursor < text.length) spans.add(span(text.substring(cursor)));
  return spans;
}

/// WPS 文件所在的 S3 存储（AWS 中国区）与临时凭据。
class WpsStorage {
  const WpsStorage({
    required this.region,
    required this.bucket,
    required this.keyPrefix,
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.sessionToken,
  });

  final String region;
  final String bucket;
  final String keyPrefix;
  final String accessKeyId;
  final String secretAccessKey;
  final String sessionToken;

  /// 对象地址（虚拟主机风格，与参考实现所用 boto3 的默认解析一致）。
  Uri objectUrl(String key) => Uri(
    scheme: 'https',
    host: '$bucket.s3.$region.amazonaws.com.cn',
    pathSegments: key.split('/'),
  );

  /// 对 GET [url] 做 AWS Signature V4 签名，返回需附加的请求头（Host 由
  /// HTTP 客户端按地址自动发送）。
  Map<String, String> sign(Uri url, DateTime now) {
    final utc = now.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    final date = '${utc.year}${two(utc.month)}${two(utc.day)}';
    final stamp =
        '${date}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
    const payload = 'UNSIGNED-PAYLOAD';
    const signed = 'host;x-amz-content-sha256;x-amz-date;x-amz-security-token';
    final canonicalPath = '/${url.pathSegments.map(_awsEncode).join('/')}';
    final canonical = [
      'GET',
      canonicalPath,
      '',
      'host:${url.host}',
      'x-amz-content-sha256:$payload',
      'x-amz-date:$stamp',
      'x-amz-security-token:$sessionToken',
      '',
      signed,
      payload,
    ].join('\n');
    final scope = '$date/$region/s3/aws4_request';
    final toSign = [
      'AWS4-HMAC-SHA256',
      stamp,
      scope,
      sha256.convert(utf8.encode(canonical)).toString(),
    ].join('\n');
    List<int> mac(List<int> key, String value) =>
        Hmac(sha256, key).convert(utf8.encode(value)).bytes;
    final signingKey = mac(
      mac(mac(mac(utf8.encode('AWS4$secretAccessKey'), date), region), 's3'),
      'aws4_request',
    );
    final signature = Hmac(
      sha256,
      signingKey,
    ).convert(utf8.encode(toSign)).toString();
    return {
      'x-amz-content-sha256': payload,
      'x-amz-date': stamp,
      'x-amz-security-token': sessionToken,
      'Authorization':
          'AWS4-HMAC-SHA256 Credential=$accessKeyId/$scope, '
          'SignedHeaders=$signed, Signature=$signature',
    };
  }

  /// AWS 规范的路径段编码：只保留 `A-Za-z0-9-._~`。
  static String _awsEncode(String segment) {
    final buffer = StringBuffer();
    for (final byte in utf8.encode(segment)) {
      final char = String.fromCharCode(byte);
      if (RegExp(r'[A-Za-z0-9\-._~]').hasMatch(char)) {
        buffer.write(char);
      } else {
        buffer.write(
          '%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}',
        );
      }
    }
    return buffer.toString();
  }

  /// 解析并校验 `/s3/requestdownload` 的响应（凭据字段已加密）。
  static WpsStorage parse(Map<String, Object?> config, WpsCodec codec) {
    final region = config['region'];
    final bucket = config['bucket'];
    final prefix = config['keyPrefix'];
    if (!const {'cn-north-1', 'cn-northwest-1'}.contains(region) ||
        bucket is! String ||
        !RegExp(r'^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$').hasMatch(bucket) ||
        prefix is! String ||
        !RegExp(r'^[A-Za-z0-9_/-]{0,200}$').hasMatch(prefix)) {
      throw const CloudNoteException(
        CloudNoteFailure.protocolChanged,
        'wps storage',
      );
    }
    String secret(String name) =>
        config[name] is String ? codec.decrypt(config[name] as String) : '';
    final values = [
      secret('accessKeyId'),
      secret('secretAccessKey'),
      secret('sessionToken'),
    ];
    if (values.any((value) => value.isEmpty)) {
      throw const CloudNoteException(CloudNoteFailure.sessionExpired);
    }
    return WpsStorage(
      region: region as String,
      bucket: bucket,
      keyPrefix: prefix,
      accessKeyId: values[0],
      secretAccessKey: values[1],
      sessionToken: values[2],
    );
  }
}
