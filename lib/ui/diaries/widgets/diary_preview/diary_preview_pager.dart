import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/services/app_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/container_transform/container_transform_route.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../../../widgets/route_entrance_waiter.dart';
import '../../controllers/diary_audio_player_controller.dart';
import '../../controllers/diary_video_player_controller.dart';
import '../../models/diary_preview_sequence.dart';
import '../../providers/diary_detail_provider.dart';
import '../../providers/diary_preview_style_provider.dart';
import '../diary_card/diary_card.dart' show diaryCardTransitionTag;
import 'diary_pager_view.dart';
import 'diary_preview_neighbors.dart';
import 'diary_preview_view.dart';

/// 预览页的左右翻页：按进入时所在列表的顺序（[DiaryPreviewSequence]）在
/// 一个路由里翻看多篇日记，每页是一个完整的 [DiaryPreviewView]。
///
/// 输入：顺序快照、最初点开的那篇及其入口数据与共享元素。输出：翻页器；删除
/// 仍由当前页以 `DiaryPreviewResult.deleted(id)` 结束整个路由。
///
/// 时序：
/// - 路由入场结束前只构建当前页，结束后才预构建两侧各一页，并（列表还有没
///   加载的部分时）一次取出同条件的全部 id 接在后面——打开时不同时排版三篇
///   正文；翻到离末尾 3 篇以内而还没接上时也会触发。入场是否结束只经
///   [RouteEntranceWaiter] 判断：推入后的第一帧路由是 offstage 的，路由动画
///   在那一帧被代理成“已完成”，直接读会误以为入场已结束，首帧就同时排版
///   三篇；
/// - 当前页与两侧页的详情由这里订阅并作为入口数据交给各页：Riverpod 会暂停
///   `TickerMode` 关闭的页里的订阅，翻过去时数据已经就绪；
/// - 翻页后暂停正在播放的录音与视频；当前页导出或分享长图期间暂停翻页。
///
/// 共享元素：只有最初那页沿用 `diaryCoverHeroTag`；翻到的其他页改用翻页器
/// 专用的标签——它们的卡片可能根本不在屏幕上。最初那页可能翻走后被回收又
/// 翻回来，列表封面的占位画面由这里在路由结束时释放。
///
/// 从卡片展开进来时（`ContainerTransformPageRoute`），翻页后把返回目标换成
/// 当前这一篇：返回时缩回它在列表里的卡片，卡片不在屏上时原地淡出。
class DiaryPreviewPager extends ConsumerStatefulWidget {
  const DiaryPreviewPager({
    super.key,
    required this.sequence,
    required this.diaryId,
    this.initialDetail,
    this.coverHero,
  });

  final DiaryPreviewSequence sequence;
  final String diaryId;
  final DiaryWithTags? initialDetail;
  final ImageViewerHero? coverHero;

  @override
  ConsumerState<DiaryPreviewPager> createState() => _DiaryPreviewPagerState();
}

class _DiaryPreviewPagerState extends ConsumerState<DiaryPreviewPager> {
  /// 翻到离末尾这么近时，若还没接上列表剩下的部分就立即去取。
  static const int _loadAheadPages = 3;

  late List<String> _ids;
  late final int _initialIndex;
  late int _current;

  /// 列表剩下的部分已接上（或本来就没有）。
  late bool _complete;
  bool _loadingRest = false;
  bool _entered = false;
  final RouteEntranceWaiter _entrance = RouteEntranceWaiter();

  /// 当前与两侧页的最新详情（翻页器订阅所得），优先于入口快照。
  final Map<String, DiaryWithTags> _details = <String, DiaryWithTags>{};
  final Set<String> _busy = <String>{};

  /// 每页上次交给翻页器的组件与它的输入（见 [_pageAt]）。
  final Map<int, _PageMemo> _pages = <int, _PageMemo>{};

  @override
  void initState() {
    super.initState();
    final ids = widget.sequence.ids;
    final index = ids.indexOf(widget.diaryId);
    if (index < 0) {
      // 入口给的顺序里没有这一篇（不应发生）：只看这一篇，不再接后续。
      _ids = <String>[widget.diaryId];
      _initialIndex = 0;
      _complete = true;
    } else {
      _ids = List<String>.of(ids);
      _initialIndex = index;
      _complete = widget.sequence.query == null;
    }
    _current = _initialIndex;
    _entrance.schedule(this, () {
      setState(() => _entered = true);
      unawaited(_loadRest());
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    // 返回飞行在本帧绘制前已结束，此时释放占位画面是安全的。
    widget.coverHero?.dispose();
    super.dispose();
  }

  /// 按列表的同一条件一次取出全部 id，只追加快照之后的部分，已有页的序号
  /// 不变。失败时停在已加载的部分。
  Future<void> _loadRest() async {
    final query = widget.sequence.query;
    if (_complete || _loadingRest || query == null) {
      return;
    }
    _loadingRest = true;
    try {
      final all = await ref
          .read(appDatabaseProvider)
          .getActiveDiaryIds(
            keyword: query.keyword,
            requiredTagIds: query.requiredTagIds,
            sortMode: query.sortMode,
            scope: query.scope,
            matchComments: query.matchComments,
            includeArchived: query.includeArchived,
            filter: query.filter,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _ids = widget.sequence.extendedWith(all);
        _complete = true;
      });
    } catch (_) {
      // 取不到就只在已加载的部分里翻，不打断阅读。
    } finally {
      _loadingRest = false;
    }
  }

  void _handlePageChanged(int index) {
    setState(() => _current = index);
    ContainerTransformPageRoute.setReturnTag(
      context,
      diaryCardTransitionTag(_ids[index]),
    );
    unawaited(DiaryAudioPlayerController.pauseActive());
    unawaited(DiaryVideoPlayerController.pauseActive());
    if (index >= _ids.length - _loadAheadPages) {
      unawaited(_loadRest());
    }
  }

  void _setBusy(String diaryId, bool busy) {
    if (!mounted || _busy.contains(diaryId) == busy) {
      return;
    }
    setState(() {
      if (busy) {
        _busy.add(diaryId);
      } else {
        _busy.remove(diaryId);
      }
    });
  }

  /// 订阅当前页与两侧页的详情；已有结果直接记下（正在 build，无需
  /// setState），之后的变化再刷新翻页器。
  void _watchNeighborhood() {
    for (var i = _current - 1; i <= _current + 1; i++) {
      if (i < 0 || i >= _ids.length) {
        continue;
      }
      final id = _ids[i];
      final provider = diaryDetailProvider(id);
      ref.listen<AsyncValue<DiaryWithTags?>>(provider, (_, next) {
        final value = next.asData?.value;
        if (value != null && !identical(_details[id], value) && mounted) {
          setState(() => _details[id] = value);
        }
      });
      final value = ref.read(provider).asData?.value;
      if (value != null) {
        _details[id] = value;
      }
    }
  }

  DiaryWithTags? _detailOf(String id) {
    return _details[id] ??
        (id == widget.diaryId ? widget.initialDetail : null) ??
        widget.sequence.seeds[id];
  }

  /// 第 [position] 页的组件。输入（这一篇、它的最新详情、是否入口页、
  /// 列表是否接全、总页数与两侧标题、语言）与上次相同时原样交回上次的
  /// 实例：翻页过半时 `onPageChanged` 让本组件 setState，翻页器用新的
  /// itemBuilder 重建缓存着的每一页；交回同一个实例时 Flutter 跳过这些页的
  /// 重建（原先每次翻页都要把左右三篇整页重建一遍，正落在翻页动画中途）。
  /// 只保留当前页附近的几项。
  Widget _pageAt(AppLocalizations l10n, DiaryPagerPosition position) {
    final index = position.index;
    final id = _ids[index];
    final detail = _detailOf(id);
    final initial = index == _initialIndex;
    final memo = _pages[index];
    final inputs = _PageInputs(
      id: id,
      detail: detail,
      initial: initial,
      hasMore: !_complete,
      count: position.count,
      previousTitle: index > 0 ? _detailOf(_ids[index - 1])?.diary.title : null,
      nextTitle: index < _ids.length - 1
          ? _detailOf(_ids[index + 1])?.diary.title
          : null,
      l10n: l10n,
    );
    if (memo != null && memo.inputs == inputs) {
      return memo.page;
    }
    final page = DiaryPreviewView(
      // 同时作为 PageStorage 的标识：翻回来时恢复这一篇的滚动位置。
      key: PageStorageKey<String>('diary_preview_page_$id'),
      diaryId: id,
      initialDetail: detail,
      coverHero: initial ? widget.coverHero : null,
      ownsCoverHero: false,
      coverHeroTag: initial
          ? null
          : ImageViewerHeroTag('diary_preview_pager_cover', id),
      paging: DiaryPreviewPaging.of(
        l10n,
        position,
        hasMore: !_complete,
        titleAt: (int index) => _detailOf(_ids[index])?.diary.title,
      ),
      onBusyChanged: (bool busy) => _setBusy(id, busy),
    );
    _pages
      ..[index] = _PageMemo(inputs, page)
      ..removeWhere((int key, _) => (key - _current).abs() > 3);
    return page;
  }

  @override
  Widget build(BuildContext context) {
    _watchNeighborhood();
    final l10n = context.l10n;
    final behavior = ref.watch(diaryPreviewBehaviorProvider);
    final navigation = ref.watch(
      diaryPreviewStyleProvider.select((style) => style.navigation),
    );
    return DiaryPagerView(
      itemCount: _ids.length,
      initialPage: _initialIndex,
      navigation: navigation,
      behavior: behavior,
      locked: _busy.isNotEmpty,
      cacheNeighbors: _entered,
      desktopControls: true,
      onPageChanged: _handlePageChanged,
      itemBuilder: (BuildContext context, DiaryPagerPosition position) =>
          _pageAt(l10n, position),
    );
  }
}

/// 一页的输入；按值比较（详情按身份比较：同一份数据对象才算没变）。
@immutable
class _PageInputs {
  const _PageInputs({
    required this.id,
    required this.detail,
    required this.initial,
    required this.hasMore,
    required this.count,
    required this.previousTitle,
    required this.nextTitle,
    required this.l10n,
  });

  final String id;
  final DiaryWithTags? detail;
  final bool initial;
  final bool hasMore;
  final int count;
  final String? previousTitle;
  final String? nextTitle;
  final AppLocalizations l10n;

  @override
  bool operator ==(Object other) =>
      other is _PageInputs &&
      other.id == id &&
      identical(other.detail, detail) &&
      other.initial == initial &&
      other.hasMore == hasMore &&
      other.count == count &&
      other.previousTitle == previousTitle &&
      other.nextTitle == nextTitle &&
      identical(other.l10n, l10n);

  @override
  int get hashCode => Object.hash(
    id,
    identityHashCode(detail),
    initial,
    hasMore,
    count,
    previousTitle,
    nextTitle,
    identityHashCode(l10n),
  );
}

class _PageMemo {
  const _PageMemo(this.inputs, this.page);

  final _PageInputs inputs;
  final Widget page;
}
