import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_guide.dart';

/// 使用指南在资源包里的目录（与 pubspec 的 assets 条目一致）。
const String kAiGuideAssetDir = 'assets/ai_guide/';

/// 指南只有中文与英文两份：中文界面读中文，其余语言（英 / 日 / 俄）读
/// 英文版，由模型按界面语言作答。
String aiGuideLanguage(String localeName) =>
    localeName.startsWith('zh') ? 'zh' : 'en';

/// 读取指南的资源包；测试可替换为只含几篇文章的假资源包。
final aiGuideBundleProvider = Provider<AssetBundle>((Ref ref) => rootBundle);

/// 某种语言（`zh` / `en`）的全部文章。经资源清单枚举目录，新文章随构建
/// 自动出现，不需要另外维护目录文件。
final aiGuideCatalogProvider = FutureProvider.family<AiGuideCatalog, String>((
  Ref ref,
  String language,
) {
  return loadAiGuideCatalog(ref.watch(aiGuideBundleProvider), language);
});

Future<AiGuideCatalog> loadAiGuideCatalog(
  AssetBundle bundle,
  String language,
) async {
  final manifest = await AssetManifest.loadFromAssetBundle(bundle);
  final prefix = '$kAiGuideAssetDir$language/';
  final paths = [
    for (final path in manifest.listAssets())
      if (path.startsWith(prefix) && path.endsWith('.md')) path,
  ];
  final articles = await Future.wait([
    for (final path in paths)
      bundle.loadString(path).then(AiGuideArticle.parse),
  ]);
  return AiGuideCatalog(articles.whereType<AiGuideArticle>());
}
