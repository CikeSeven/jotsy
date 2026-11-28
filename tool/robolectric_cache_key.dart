/// 计算 CI 中 Robolectric Android SDK jar 的缓存键与预取 SDK 列表。
///
/// 输入：
/// - `android/app/build.gradle.kts`（提取 `org.robolectric:robolectric:<version>`）
/// - `android/app/src/test` 目录（扫描 `.kt`/`.java` 中的 `@Config` SDK 声明与
///   `robolectric.properties`）
///
/// 输出：
/// - 标准输出及可选 `--output <path>`（用于追加到 `GITHUB_OUTPUT`）：
///   `version=<版本号>`、`sdks=<空格分隔的整数 API 级别>`、`key_suffix=<缓存键后缀>`。
///
/// 副作用：仅在传入 `--output` 时向指定文件追加输出行。
library;

import 'dart:convert';
import 'dart:io';

/// 解析后的 Robolectric 缓存键信息。
final class RobolectricCacheSpec {
  const RobolectricCacheSpec({
    required this.version,
    required this.sdks,
    required this.keySuffix,
  });

  final String version;
  final List<int> sdks;
  final String keySuffix;

  String toGitHubOutput() =>
      'version=$version\n'
      'sdks=${sdks.join(' ')}\n'
      'key_suffix=$keySuffix\n';
}

void main(List<String> arguments) {
  var gradlePath = 'android/app/build.gradle.kts';
  var testDirPath = 'android/app/src/test';
  String? outputPath;

  for (var i = 0; i < arguments.length; i++) {
    final arg = arguments[i];
    String nextValue() {
      if (i + 1 >= arguments.length) {
        throw FormatException('Missing value for $arg');
      }
      return arguments[++i];
    }

    switch (arg) {
      case '--gradle':
        gradlePath = nextValue();
      case '--test-dir':
        testDirPath = nextValue();
      case '--output':
        outputPath = nextValue();
      default:
        stderr.writeln(
          'Usage: robolectric_cache_key.dart '
          '[--gradle <path>] [--test-dir <path>] [--output <path>]',
        );
        exitCode = 64;
        return;
    }
  }

  final spec = resolveRobolectricCacheSpec(
    gradleFile: File(gradlePath),
    testDir: Directory(testDirPath),
  );
  final rendered = spec.toGitHubOutput();
  stdout.write(rendered);
  if (outputPath != null) {
    File(outputPath).writeAsStringSync(rendered, mode: FileMode.append);
  }
}

/// 从本地文件系统中读取 Gradle 配置与 Android 单元测试目录并生成缓存规格。
RobolectricCacheSpec resolveRobolectricCacheSpec({
  required File gradleFile,
  required Directory testDir,
}) {
  if (!gradleFile.existsSync()) {
    throw FormatException('Gradle file not found: ${gradleFile.path}');
  }
  if (!testDir.existsSync()) {
    throw FormatException('Android test directory not found: ${testDir.path}');
  }

  final testSources = <String, String>{};
  final propertiesFiles = <String, String>{};
  final files = testDir.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  final prefix = testDir.path.endsWith(Platform.pathSeparator)
      ? testDir.path
      : '${testDir.path}${Platform.pathSeparator}';
  for (final file in files) {
    final relative = file.path.startsWith(prefix)
        ? file.path.substring(prefix.length).replaceAll('\\', '/')
        : file.path.replaceAll('\\', '/');
    if (relative.endsWith('.kt') || relative.endsWith('.java')) {
      testSources[relative] = file.readAsStringSync();
    } else if (relative == 'robolectric.properties' ||
        relative.endsWith('/robolectric.properties')) {
      propertiesFiles[relative] = file.readAsStringSync();
    }
  }

  return computeRobolectricCacheSpec(
    gradleContent: gradleFile.readAsStringSync(),
    testSources: testSources,
    propertiesFiles: propertiesFiles,
  );
}

/// 纯函数：根据 Gradle 脚本与测试源码内容计算 Robolectric 缓存键规格。
RobolectricCacheSpec computeRobolectricCacheSpec({
  required String gradleContent,
  required Map<String, String> testSources,
  Map<String, String> propertiesFiles = const <String, String>{},
}) {
  final version = parseRobolectricVersion(gradleContent);
  final numericSdks = <int>{};
  final extraTokens = <String>{};

  final sortedSourcePaths = testSources.keys.toList()..sort();
  for (final path in sortedSourcePaths) {
    final cleaned = _stripCommentsAndStrings(
      testSources[path]!,
      stripStrings: true,
    );
    final configs = _extractConfigBodies(cleaned);
    var fileHasExplicitSdk = false;
    for (final body in configs) {
      final parsed = _parseConfigSdkBody(body);
      if (parsed.hasSdkConfig) {
        fileHasExplicitSdk = true;
      }
      numericSdks.addAll(parsed.numericSdks);
      extraTokens.addAll(parsed.extraTokens);
    }
    if (!fileHasExplicitSdk && cleaned.contains('RobolectricTestRunner')) {
      extraTokens.add('default-sdk');
    }
  }

  final sortedPropPaths = propertiesFiles.keys.toList()..sort();
  for (final path in sortedPropPaths) {
    final normalized = const LineSplitter()
        .convert(propertiesFiles[path]!)
        .map((line) => line.trim())
        .where(
          (line) =>
              line.isNotEmpty && !line.startsWith('#') && !line.startsWith('!'),
        )
        .join('\n');
    if (normalized.isNotEmpty) {
      extraTokens.add('props:$path=$normalized');
    }
  }

  final sortedSdks = numericSdks.toList()..sort();
  final suffixParts = <String>[];
  if (sortedSdks.isNotEmpty) {
    suffixParts.add('sdk-${sortedSdks.join('-')}');
  }
  if (extraTokens.isNotEmpty) {
    final sortedExtra = extraTokens.toList()..sort();
    suffixParts.add('extra-${_fnv1a64Hex(sortedExtra.join('\n'))}');
  }
  final keySuffix = suffixParts.isEmpty ? 'none' : suffixParts.join('-');

  return RobolectricCacheSpec(
    version: version,
    sdks: sortedSdks,
    keySuffix: keySuffix,
  );
}

/// 从 `build.gradle.kts` 中解析唯一的 Robolectric 版本号。
String parseRobolectricVersion(String gradleContent) {
  final cleaned = _stripCommentsAndStrings(gradleContent, stripStrings: false);
  final matches = RegExp(
    r'''["']org\.robolectric:robolectric:([0-9A-Za-z._-]+)["']''',
  ).allMatches(cleaned);
  final versions = matches.map((m) => m.group(1)!).toSet();
  if (versions.isEmpty) {
    throw const FormatException(
      'Could not find org.robolectric:robolectric:<version> in build.gradle.kts',
    );
  }
  if (versions.length > 1) {
    throw FormatException(
      'Found multiple Robolectric versions: ${versions.join(', ')}',
    );
  }
  return versions.single;
}

class _ParsedConfigSdk {
  const _ParsedConfigSdk({
    required this.hasSdkConfig,
    required this.numericSdks,
    required this.extraTokens,
  });

  final bool hasSdkConfig;
  final Set<int> numericSdks;
  final Set<String> extraTokens;
}

_ParsedConfigSdk _parseConfigSdkBody(String body) {
  var hasSdkConfig = false;
  final numericSdks = <int>{};
  final extraTokens = <String>{};

  final sdkMatch = RegExp(
    r'(?<![A-Za-z0-9_])sdk\s*=\s*(?:\[([^\]]*)\]|\{([^}]*)\}|([^,)]+))',
  ).firstMatch(body);
  if (sdkMatch != null) {
    hasSdkConfig = true;
    final raw = (sdkMatch.group(1) ?? sdkMatch.group(2) ?? sdkMatch.group(3)!)
        .trim();
    for (final part in raw.split(',')) {
      final token = part.trim();
      if (token.isEmpty) continue;
      final parsed = int.tryParse(token);
      if (parsed != null && parsed > 0) {
        numericSdks.add(parsed);
      } else {
        extraTokens.add('sdk:$token');
      }
    }
  }

  int? minValue;
  int? maxValue;
  final minMatch = RegExp(
    r'(?<![A-Za-z0-9_])minSdk\s*=\s*([^,)]+)',
  ).firstMatch(body);
  if (minMatch != null) {
    hasSdkConfig = true;
    final token = minMatch.group(1)!.trim();
    extraTokens.add('minSdk:$token');
    final parsed = int.tryParse(token);
    if (parsed != null && parsed > 0) {
      minValue = parsed;
      numericSdks.add(parsed);
    }
  }

  final maxMatch = RegExp(
    r'(?<![A-Za-z0-9_])maxSdk\s*=\s*([^,)]+)',
  ).firstMatch(body);
  if (maxMatch != null) {
    hasSdkConfig = true;
    final token = maxMatch.group(1)!.trim();
    extraTokens.add('maxSdk:$token');
    final parsed = int.tryParse(token);
    if (parsed != null && parsed > 0) {
      maxValue = parsed;
      numericSdks.add(parsed);
    }
  }

  // minSdk 与 maxSdk 均为整数且范围合理时补全区间，便于冷缓存预取完整集合。
  if (minValue != null &&
      maxValue != null &&
      minValue <= maxValue &&
      maxValue - minValue <= 30) {
    for (var api = minValue; api <= maxValue; api++) {
      numericSdks.add(api);
    }
  }

  return _ParsedConfigSdk(
    hasSdkConfig: hasSdkConfig,
    numericSdks: numericSdks,
    extraTokens: extraTokens,
  );
}

List<String> _extractConfigBodies(String source) {
  final bodies = <String>[];
  final pattern = RegExp(r'@Config\s*\(');
  for (final match in pattern.allMatches(source)) {
    var depth = 1;
    final start = match.end;
    var index = start;
    while (index < source.length && depth > 0) {
      final char = source[index];
      if (char == '(') {
        depth++;
      } else if (char == ')') {
        depth--;
      }
      index++;
    }
    if (depth == 0) {
      bodies.add(source.substring(start, index - 1));
    }
  }
  return bodies;
}

/// 剥离行注释、块注释（支持 Kotlin 嵌套块注释）；[stripStrings] 为 true 时同时
/// 清空字符串与字符字面量内容，避免注释或测试文案干扰 `@Config` 解析。
String _stripCommentsAndStrings(String source, {required bool stripStrings}) {
  final out = StringBuffer();
  var i = 0;
  final n = source.length;
  while (i < n) {
    final c = source[i];
    final next = i + 1 < n ? source[i + 1] : '';
    if (c == '/' && next == '/') {
      i += 2;
      while (i < n && source[i] != '\n') {
        i++;
      }
      out.write(' ');
      continue;
    }
    if (c == '/' && next == '*') {
      i += 2;
      var depth = 1;
      while (i < n && depth > 0) {
        if (i + 1 < n && source[i] == '/' && source[i + 1] == '*') {
          depth++;
          i += 2;
        } else if (i + 1 < n && source[i] == '*' && source[i + 1] == '/') {
          depth--;
          i += 2;
        } else {
          i++;
        }
      }
      out.write(' ');
      continue;
    }
    if (c == '"' && i + 2 < n && source[i + 1] == '"' && source[i + 2] == '"') {
      final start = i;
      i += 3;
      while (i + 2 < n &&
          !(source[i] == '"' && source[i + 1] == '"' && source[i + 2] == '"')) {
        i++;
      }
      if (i + 2 < n) {
        i += 3;
      } else {
        i = n;
      }
      out.write(stripStrings ? '""' : source.substring(start, i));
      continue;
    }
    if (c == '"' || c == "'") {
      final quote = c;
      final start = i;
      i++;
      while (i < n && source[i] != quote) {
        if (source[i] == '\\' && i + 1 < n) {
          i += 2;
        } else {
          i++;
        }
      }
      if (i < n) {
        i++;
      }
      out.write(stripStrings ? '$quote$quote' : source.substring(start, i));
      continue;
    }
    out.write(c);
    i++;
  }
  return out.toString();
}

String _fnv1a64Hex(String input) {
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final byte in utf8.encode(input)) {
    hash = ((hash ^ BigInt.from(byte)) * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
