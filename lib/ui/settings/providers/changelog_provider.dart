import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_service.dart';
import '../../../core/services/app_update_version.dart';
import '../../../core/services/release_notes_catalog.dart';
import '../models/changelog_entry.dart';

/// 更新日志页的数据：各版本（新的在前）与本机安装的版本。
@immutable
class Changelog {
  const Changelog({required this.entries, this.installed});

  final List<ChangelogEntry> entries;

  /// 本机安装的版本；读不出时为 null，此时不标“当前版本”。
  final AppVersion? installed;

  bool isInstalled(ChangelogEntry entry) {
    final installed = this.installed;
    return installed != null && entry.version.compareTo(installed) == 0;
  }
}

/// 读取更新说明的资源包；测试可替换为只含几份说明的假资源包。
final releaseNotesBundleProvider = Provider<AssetBundle>(
  (Ref ref) => rootBundle,
);

/// 更新日志，按界面语言（`zh` / `en`）读取。
///
/// 读取失败一律降级为空列表（页面显示空态）而不是抛出：说明随应用打包，
/// 读不出只可能是资源包本身有问题，重试也不会好，还能避免 FutureProvider
/// 对失败的自动重试反复读取。本机版本读不出时只是不标“当前版本”。离开页面
/// 即释放，下次进入重新读取（资源包会缓存文件内容）。
final changelogProvider = FutureProvider.autoDispose.family<Changelog, String>((
  Ref ref,
  String languageCode,
) async {
  var entries = const <ChangelogEntry>[];
  try {
    final notes = await loadBundledReleaseNotes(
      ref.watch(releaseNotesBundleProvider),
      languageCode: languageCode,
    );
    entries = List<ChangelogEntry>.unmodifiable(
      notes.map(ChangelogEntry.fromNotes),
    );
  } catch (error) {
    debugPrint('Changelog failed to load: $error');
  }
  AppVersion? installed;
  try {
    installed =
        (await ref.read(appUpdateServiceProvider).installedApp()).version;
  } catch (error) {
    debugPrint('Installed version unavailable for changelog: $error');
  }
  return Changelog(entries: entries, installed: installed);
});
