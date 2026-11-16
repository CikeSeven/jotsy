import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../models/explore_media_gallery_filter.dart';
import '../models/explore_view_data.dart';
import 'explore_media_stats.dart';

/// 媒体画廊的图片索引：把当前筛选下全部带图日记的图片来源（带所在日记与
/// 发表时间）分批读出、去重，向页面提供加载、结束与错误状态。
///
/// - [loadMore] 一次跑完整份索引：每批 [batchSize] 篇候选日记（数据库先排除
///   纯文字日记），正文较大时在 worker 里解析，每批提交后通知一次，页面
///   首批到了就显示、之后的批次接在末尾。只读来源与日期，不解码图片：
///   快速滚动条要知道总量与每段的日期，才不必“滚到底再加载”。
/// - 按发表时间分页（画廊按发表日期分组）；一批失败时停在原处，已提交的
///   批次保留，[loadMore] 从失败那一批重试。
/// - [configure] 换筛选时清空并从头加载：在途的旧一轮按代号 [generation]
///   丢弃，不会把旧筛选的结果接到新列表后面。
/// - dispose 后忽略在途结果，不再查询，也不通知已销毁的监听者。
class ExploreMediaGalleryController extends ChangeNotifier {
  ExploreMediaGalleryController({required this._database});

  /// 每批读取的候选日记篇数。
  @visibleForTesting
  static const int batchSize = 120;

  final AppDatabase _database;
  final List<ExploreMediaItem> _mediaItems = <ExploreMediaItem>[];
  final Set<String> _seenSources = <String>{};

  late final List<ExploreMediaItem> items = UnmodifiableListView(_mediaItems);
  ExploreMediaGalleryFilter _filter = const ExploreMediaGalleryFilter();
  int _generation = 0;
  int _nextOffset = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _hasError = false;
  bool _disposed = false;

  ExploreMediaGalleryFilter get filter => _filter;

  /// 每换一次筛选加一：页面据此丢掉按旧列表算的分组缓存。
  int get generation => _generation;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  bool get hasError => _hasError;

  /// 换成 [filter] 并从头加载；与当前筛选相同时什么也不做。
  void configure(ExploreMediaGalleryFilter filter) {
    if (_disposed || filter == _filter) {
      return;
    }
    _filter = filter;
    _generation += 1;
    _mediaItems.clear();
    _seenSources.clear();
    _nextOffset = 0;
    _hasMore = true;
    _hasError = false;
    // 在途的旧一轮回来时代号已变、直接丢弃，这里先放行新的一轮。
    _isLoading = false;
    notifyListeners();
    unawaited(loadMore());
  }

  /// 从当前位置起把剩下的批次全部读完（已在读或已读完时什么也不做）。
  Future<void> loadMore() async {
    if (_disposed || _isLoading || !_hasMore) {
      return;
    }
    final generation = _generation;
    final filter = _filter;
    bool stale() => _disposed || generation != _generation;
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      while (_hasMore) {
        final rows = await _database.getGalleryMediaPage(
          limit: batchSize,
          offset: _nextOffset,
          scope: filter.scope,
          newestFirst: filter.newestFirst,
          from: filter.from,
          to: filter.to,
        );
        if (stale()) {
          return;
        }
        final batch = await ExploreMediaStats.galleryItems(rows);
        if (stale()) {
          return;
        }
        // 一篇日记的图片在同一批里处理完再推进游标，单篇图片再多也不会
        // 在下一批被跳过。
        _nextOffset += rows.length;
        _hasMore = rows.length == batchSize;
        for (final item in batch) {
          if (_seenSources.add(item.source)) {
            _mediaItems.add(item);
          }
        }
        if (_hasMore) {
          notifyListeners();
        }
      }
    } catch (_) {
      if (stale()) {
        return;
      }
      _hasError = true;
    }
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
