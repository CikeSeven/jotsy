import 'package:meta/meta.dart';

/// 语义化版本号：`主.次.修订[-预发布][+构建号]`，可带前缀 `v`。
@immutable
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(
    this.major,
    this.minor,
    this.patch, {
    this.preRelease = '',
    this.build,
  });

  final int major;
  final int minor;
  final int patch;

  /// 预发布标识（`beta.1`），正式版为空。
  final String preRelease;

  /// 构建号（Android versionCode）；tag 可省略构建号，此时为 null。
  final int? build;

  static final RegExp _pattern = RegExp(
    r'^[vV]?(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:-([0-9A-Za-z.-]+))?(?:\+(\d+))?$',
  );

  static AppVersion? tryParse(String? raw) {
    final match = _pattern.firstMatch(raw?.trim() ?? '');
    if (match == null) {
      return null;
    }
    int part(int group) => int.parse(match.group(group) ?? '0');
    final build = match.group(5);
    return AppVersion(
      part(1),
      part(2),
      part(3),
      preRelease: match.group(4) ?? '',
      build: build == null ? null : int.parse(build),
    );
  }

  /// 不含构建号的版本名，如 `0.6.1`、`0.7.0-beta.1`。
  String get name =>
      '$major.$minor.$patch${preRelease.isEmpty ? '' : '-$preRelease'}';

  /// 比较规则：先比主/次/修订；同号时正式版高于预发布；最后比构建号——
  /// 只有两边都带构建号才比较。发布 tag 常省略构建号（`v0.6.0` 对应
  /// `0.6.0+17`），把缺失当 0 会把同一版本误判为旧版或新版。
  @override
  int compareTo(AppVersion other) {
    for (final (a, b) in <(int, int)>[
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      if (a != b) {
        return a.compareTo(b);
      }
    }
    final preCmp = _comparePreRelease(preRelease, other.preRelease);
    if (preCmp != 0) {
      return preCmp;
    }
    final build = this.build;
    final otherBuild = other.build;
    if (build == null || otherBuild == null) {
      return 0;
    }
    return build.compareTo(otherBuild);
  }

  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  static int _comparePreRelease(String a, String b) {
    if (a == b) {
      return 0;
    }
    if (a.isEmpty) {
      return 1;
    }
    if (b.isEmpty) {
      return -1;
    }
    final left = a.split('.');
    final right = b.split('.');
    for (var i = 0; i < left.length && i < right.length; i++) {
      final l = int.tryParse(left[i]);
      final r = int.tryParse(right[i]);
      final cmp = switch ((l, r)) {
        (final int x, final int y) => x.compareTo(y),
        (int(), null) => -1,
        (null, int()) => 1,
        _ => left[i].compareTo(right[i]),
      };
      if (cmp != 0) {
        return cmp;
      }
    }
    return left.length.compareTo(right.length);
  }

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch &&
      other.preRelease == preRelease &&
      other.build == build;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease, build);

  @override
  String toString() => build == null ? name : '$name+$build';
}
