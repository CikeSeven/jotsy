import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../../core/database/app_database.dart';
import '../models/explore_view_data.dart';
import 'explore_content_extractor.dart';

/// 将分页日记转换为去重后的媒体列表，向页面提供加载、结束与错误状态。
///
/// 数据库只读；每轮成功后一起提交游标和媒体，失败可从原位置重试。
/// dispose 后忽略在途结果，避免离开页面后继续查询或通知已销毁的监听者。
class ExploreMediaGalleryController extends ChangeNotifier {
  ExploreMediaGalleryController({required this._database});

  static const int _candidateBatchSize = 40;
  static const int _targetMediaAppendCount = 30;
  static const int _maxBatchRoundsPerLoad = 8;

  final AppDatabase _database;
  final ExploreContentExtractor _extractor = const ExploreContentExtractor();
  final List<ExploreMediaItem> _mediaItems = <ExploreMediaItem>[];
  final Set<String> _seenSources = <String>{};

  late final List<ExploreMediaItem> items = UnmodifiableListView(_mediaItems);
  int _nextOffset = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _hasError = false;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  bool get hasError => _hasError;

  Future<void> loadMore() async {
    if (_disposed || _isLoading || !_hasMore) {
      return;
    }
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      final localSources = Set<String>.from(_seenSources);
      final appended = <ExploreMediaItem>[];
      var localOffset = _nextOffset;
      var localHasMore = _hasMore;
      var rounds = 0;

      while (!_disposed &&
          appended.length < _targetMediaAppendCount &&
          localHasMore &&
          rounds < _maxBatchRoundsPerLoad) {
        rounds += 1;
        final diaries = await _database.getActiveDiariesPage(
          limit: _candidateBatchSize,
          offset: localOffset,
        );
        if (_disposed) {
          return;
        }
        localOffset += diaries.length;
        localHasMore = diaries.length == _candidateBatchSize;

        // 30 张只是批次目标，必须处理完已读取日记中的全部图片再推进游标，
        // 否则单篇包含大量图片时，超出目标的部分会在下一次分页被跳过。
        for (final diary in diaries) {
          for (final source in _extractor.resolveMediaSources(diary)) {
            if (!localSources.add(source)) {
              continue;
            }
            appended.add(
              ExploreMediaItem(
                source: source,
                diaryId: diary.diaryId,
                updatedAt: diary.updatedAt,
              ),
            );
          }
        }
      }

      if (_disposed) {
        return;
      }
      _hasMore = localHasMore;
      _nextOffset = localOffset;
      _mediaItems.addAll(appended);
      _seenSources.addAll(localSources);
    } catch (_) {
      if (_disposed) {
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
