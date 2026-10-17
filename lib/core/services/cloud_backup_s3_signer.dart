import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// AWS Signature Version 4 签名（S3 兼容对象存储共用）。
///
/// 关键约束：签名用的规范路径/查询串与实际发出的 URL 必须逐字节一致。
/// Dart 的 [Uri] 对 `+ = @ :` 等字符不做百分号编码，与 AWS 规范不同，所以
/// 请求地址由 [S3SignedRequest.uri] 按同一份编码结果拼出，不经 Uri 重新编码。
class S3Signer {
  const S3Signer({
    required this.accessKeyId,
    required this.secretAccessKey,
    required this.region,
  });

  final String accessKeyId;
  final String secretAccessKey;
  final String region;

  /// SHA-256(空串)，GET/DELETE 等无请求体请求的载荷摘要。
  static final String emptyPayloadHash = sha256Hex(const <int>[]);

  static String sha256Hex(List<int> bytes) => sha256.convert(bytes).toString();

  /// 为一次请求签名。[pathSegments] 是未编码的路径段（含桶名与否由调用方
  /// 决定），[query] 是未编码的查询参数，值为空串时按 `key=` 规范化。
  S3SignedRequest sign({
    required String method,
    required String scheme,
    required String host,
    required int? port,
    required List<String> pathSegments,
    Map<String, String> query = const <String, String>{},
    required String payloadHash,
    required DateTime now,
  }) {
    final utc = now.toUtc();
    String two(int value) => value.toString().padLeft(2, '0');
    final date = '${utc.year}${two(utc.month)}${two(utc.day)}';
    final stamp =
        '${date}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
    final hostHeader = port == null ? host : '$host:$port';
    final canonicalPath = pathSegments.isEmpty
        ? '/'
        : '/${pathSegments.map(awsUriEncode).join('/')}';
    final sortedKeys = query.keys.toList()..sort();
    final canonicalQuery = [
      for (final key in sortedKeys)
        '${awsUriEncode(key)}=${awsUriEncode(query[key]!)}',
    ].join('&');
    const signedHeaders = 'host;x-amz-content-sha256;x-amz-date';
    final canonicalRequest = [
      method,
      canonicalPath,
      canonicalQuery,
      'host:$hostHeader',
      'x-amz-content-sha256:$payloadHash',
      'x-amz-date:$stamp',
      '',
      signedHeaders,
      payloadHash,
    ].join('\n');
    final scope = '$date/$region/s3/aws4_request';
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      stamp,
      scope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
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
    ).convert(utf8.encode(stringToSign)).toString();
    final url =
        '$scheme://$hostHeader$canonicalPath'
        '${canonicalQuery.isEmpty ? '' : '?$canonicalQuery'}';
    return S3SignedRequest(Uri.parse(url), <String, String>{
      'x-amz-content-sha256': payloadHash,
      'x-amz-date': stamp,
      HttpHeaders.authorizationHeader:
          'AWS4-HMAC-SHA256 Credential=$accessKeyId/$scope, '
          'SignedHeaders=$signedHeaders, Signature=$signature',
    });
  }

  /// AWS 规范的 URI 编码：只保留 `A-Za-z0-9-._~`，其余按 UTF-8 字节编码为
  /// 大写 `%XX`。
  static String awsUriEncode(String value) {
    final buffer = StringBuffer();
    for (final byte in utf8.encode(value)) {
      final isUnreserved =
          (byte >= 0x41 && byte <= 0x5A) ||
          (byte >= 0x61 && byte <= 0x7A) ||
          (byte >= 0x30 && byte <= 0x39) ||
          byte == 0x2D ||
          byte == 0x2E ||
          byte == 0x5F ||
          byte == 0x7E;
      if (isUnreserved) {
        buffer.writeCharCode(byte);
      } else {
        buffer
          ..write('%')
          ..write(byte.toRadixString(16).toUpperCase().padLeft(2, '0'));
      }
    }
    return buffer.toString();
  }
}

class S3SignedRequest {
  const S3SignedRequest(this.uri, this.headers);

  final Uri uri;
  final Map<String, String> headers;
}

/// 流式计算文件 `[start, end)` 区间的 SHA-256（十六进制）。
Future<String> sha256OfFileRange(File file, {int start = 0, int? end}) async {
  final digest = await sha256.bind(file.openRead(start, end)).first;
  return digest.toString();
}
