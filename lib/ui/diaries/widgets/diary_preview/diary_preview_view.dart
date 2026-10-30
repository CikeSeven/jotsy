import 'dart:async';

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart' as af;
import 'package:node_diary/ui/diaries/controllers/diary_editor_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widget_screenshot_plus/widget_screenshot_plus.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/diary_blocks/diary_link_target.dart';
import '../../../../core/services/app_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/widgets/home_hint_visibility_scope.dart';
import '../../../notebooks/controllers/notebook_navigation.dart';
import '../../../notebooks/providers/notebook_providers.dart';
import '../../../notebooks/viewmodels/notebook_view.dart';
import '../../../settings/providers/app_features_provider.dart';
import '../../../widgets/action_loading_overlay.dart';
import '../../../widgets/app_top_bar.dart';
import '../../../widgets/delayed_loading_indicator.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../../controllers/diary_comment_flows.dart';
import '../../controllers/diary_preview_edit_flow.dart';
import '../../controllers/diary_preview_export_controller.dart';
import '../../controllers/diary_tag_search_flow.dart';
import '../../controllers/diary_todo_autosave_controller.dart';
import '../../models/diary_preview_result.dart';
import '../../models/time_capsule.dart';
import '../../pages/locked_diary_page.dart';
import '../../providers/diary_comments_provider.dart';
import '../../providers/diary_detail_provider.dart';
import '../../providers/diary_link_providers.dart';
import '../../providers/diary_mood_palette_provider.dart';
import '../../providers/diary_preview_style_provider.dart';
import '../../sections/diary_typography_sheet.dart';
import '../../viewmodels/diary_preview_resolved_style.dart';
import '../../viewmodels/diary_preview_view_data.dart';
import '../diary_comments/diary_comments_section.dart';
import '../diary_link/diary_backlinks_section.dart';
import 'diary_preview_actions_sheet.dart';
import 'diary_preview_content.dart';
import 'diary_preview_dialogs.dart';
import 'diary_preview_host.dart';
import 'diary_preview_neighbors.dart';
import 'diary_preview_surface.dart';
import 'diary_preview_top_bar.dart';
import '../../../app_surface/widgets/app_page_backdrop.dart';

/// 一篇日记的预览（阅读优先）：数据、只读正文与动作。
///
/// 输入：日记业务 id，可选的入口数据（同一篇的 `DiaryWithTags`，首帧直接
/// 渲染）与列表封面抓取的共享元素（本组件销毁时释放）。输出：整页
/// Scaffold；未解封的时间胶囊内联显示封存页。副作用：勾选待办写库（见
/// [DiaryTodoAutoSaveController]）、分享、导出与删除。
///
/// 状态：详情查询返回前用入口数据渲染，返回后由最新数据接管；正文只在内容
/// 变化时重建 原生块控制器。
///
/// 放在翻页器（`DiaryPreviewPager`）里时：[paging] 给出位置与相邻篇，
/// [onBusyChanged] 报告导出 / 分享长图的忙碌态（翻页器据此暂停翻页），共享
/// 元素的标签与占位画面的所有权由翻页器决定（见 [coverHeroTag]、
/// [ownsCoverHero]）。
///
/// 嵌在页面里（宽窗口日记页的右栏）时传入 [host]：顶栏没有返回按钮，头图
/// 不建立共享元素（列表卡片与右栏同在一个路由，同名 Hero 会冲突），删除与
/// “日记不见了”交给宿主而不是退出路由；未解封的胶囊同样内联显示封存页
/// （也没有返回按钮）。[paging] 的上一篇 / 下一篇由宿主给出（在列表里换选）。
class DiaryPreviewView extends ConsumerStatefulWidget {
  const DiaryPreviewView({
    super.key,
    required this.diaryId,
    this.initialDetail,
    this.coverHero,
    this.ownsCoverHero = true,
    this.coverHeroTag,
    this.paging,
    this.onBusyChanged,
    this.host,
  });

  final String diaryId;

  /// 入口已持有的同一篇日记（`diary.diaryId` 必须等于 [diaryId]）。
  final DiaryWithTags? initialDetail;

  /// 列表封面抓取的画面：头图以它为共享元素落点与占位。
  final ImageViewerHero? coverHero;

  /// 为 true 时本组件销毁即释放 [coverHero]；翻页器里翻走的初始页会被回收
  /// 又可能翻回来，占位画面改由翻页器在路由结束时释放。
  final bool ownsCoverHero;

  /// 头图的共享元素标签；null 时为 `diaryCoverHeroTag`（返回时飞回列表卡片）。
  final Object? coverHeroTag;

  /// 在翻页顺序里的位置；单篇打开时为 null。
  final DiaryPreviewPaging? paging;

  /// 导出、分享长图等忙碌态变化时回调。
  final ValueChanged<bool>? onBusyChanged;

  /// 嵌在页面里时的宿主；独立路由时为 null。
  final DiaryPreviewHost? host;

  @override
  ConsumerState<DiaryPreviewView> createState() => _DiaryPreviewViewState();
}

class _DiaryPreviewViewState extends ConsumerState<DiaryPreviewView> {
  final GlobalKey _shareCaptureKey = GlobalKey();
  final GlobalKey _commentsKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  late final DiaryPreviewExportController _export =
      DiaryPreviewExportController(
        captureKey: _shareCaptureKey,
        scrollController: _scrollController,
        onHint: _showHint,
      )..addListener(_handleExportChanged);
  late final DiaryTodoAutoSaveController _todoAutoSave;

  DiaryEditorController? _controller;
  String? _boundContentRaw;
  StreamSubscription<af.EditorTransactionValue>? _docChanges;
  DiaryWithTags? _currentDetail;
  DiaryPreviewViewData? _viewData;
  bool _hadLoadedData = false;
  bool _reportedBusy = false;

  @override
  void initState() {
    super.initState();
    // 待办可能在本组件销毁时才补写（翻走后被回收、勾完立即返回），那时已
    // 不能再用 ref：写库与刷新详情都经提前取得的 container。
    final container = ProviderScope.containerOf(context, listen: false);
    final diaryId = widget.diaryId;
    _todoAutoSave = DiaryTodoAutoSaveController(
      readDetail: () => _currentDetail,
      readDocument: () => _controller?.document,
      readDatabase: () => container.read(appDatabaseProvider),
      onSaved: () => container.invalidate(diaryDetailProvider(diaryId)),
      onSaveError: (error) =>
          _showHint(context.l10n.autoT0087(error.toString())),
    );
  }

  @override
  void dispose() {
    // 返回飞行在本帧绘制前已结束，此时释放占位画面是安全的。
    if (widget.ownsCoverHero) {
      widget.coverHero?.dispose();
    }
    // 先于正文控制器释放：补写待办要读当下的文档。
    _todoAutoSave.dispose();
    _docChanges?.cancel();
    _controller?.dispose();
    _export
      ..removeListener(_handleExportChanged)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleExportChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
    final busy = _export.busy;
    if (busy != _reportedBusy) {
      _reportedBusy = busy;
      widget.onBusyChanged?.call(busy);
    }
  }

  /// 根据正文 JSON 绑定只读控制器；仅在内容变化时重建，避免 build 阶段重复
  /// 构造 controller。
  void _bindController(String contentRaw) {
    if (_boundContentRaw == contentRaw && _controller != null) {
      return;
    }
    _docChanges?.cancel();
    _controller?.dispose();
    _boundContentRaw = contentRaw;
    final controller = DiaryEditorController(
      document: diaryEditorDocument(contentRaw),
      selection: af.Selection.single(path: [0], startOffset: 0),
      readOnly: true,
    );
    _controller = controller;
    _docChanges = controller.state.transactionStream.listen((
      af.EditorTransactionValue change,
    ) {
      // 预览页是只读模式，唯一允许的本地变更是待办勾选状态。
      if (change.$1 != af.TransactionTime.after ||
          change.$2.operations.isEmpty) {
        return;
      }
      _todoAutoSave.schedule();
    });
  }

  void _showHint(String message) {
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      ),
    );
  }

  void _openImageViewer(
    List<String> sources,
    String initialSource,
    ImageViewerHero? hero,
  ) {
    openDiaryPreviewImages(
      context,
      sources: sources,
      initialSource: initialSource,
      hero: hero,
    );
  }

  Future<void> _openEditor() async {
    // 编辑页里删除了这一篇：按“已删除”收尾，入口给出撤销。
    final deleted = await openDiaryEditorFromPreview(
      context,
      ref,
      widget.diaryId,
    );
    if (mounted && deleted) {
      _finishDeleted();
    }
  }

  /// 这一篇已删除：独立路由以 [DiaryPreviewResult.deleted] 退出，由入口给出
  /// 撤销；嵌在页面里时交给宿主。
  void _finishDeleted() {
    final host = widget.host;
    if (host != null) {
      host.onDeleted(widget.diaryId);
      return;
    }
    Navigator.of(context).pop(DiaryPreviewResult.deleted(widget.diaryId));
  }

  /// 写留言。从“更多”进入时（[reveal]）先滚到留言区末尾再打开面板：面板
  /// 收起后，新写下的那条就在眼前。
  Future<void> _writeComment(Diary diary, {bool reveal = false}) async {
    if (reveal) {
      await DiaryCommentsSection.reveal(context, _commentsKey, end: true);
      if (!mounted) return;
    }
    await writeDiaryComment(context, ref, diary: diary);
  }

  /// 留言区的数据与动作；留言功能关闭、日记在回收站或首次读取还没返回时为
  /// null（不显示留言区）。截取分享长图期间同样为 null：分享不带留言。
  ///
  /// 截图期间仍然订阅留言：只是不交给正文，截完立刻原样回来，不必重新读取。
  DiaryPreviewComments? _resolveComments(Diary diary) {
    if (!ref.watch(diaryCommentsEnabledProvider) || diary.isDeleted) {
      return null;
    }
    final rows = ref.watch(diaryCommentsProvider(widget.diaryId)).value;
    if (rows == null || _export.capturingLongImage) return null;
    return DiaryPreviewComments(
      diaryCreatedAt: diary.createdAt,
      comments: rows,
      sectionKey: _commentsKey,
      actions: DiaryCommentActions(
        onWrite: () => unawaited(_writeComment(diary)),
        onEdit: (comment) =>
            unawaited(editDiaryComment(context, ref, comment: comment)),
        onCopy: (comment) => unawaited(copyDiaryComment(context, comment)),
        onDelete: (comment) =>
            unawaited(deleteDiaryComment(context, ref, comment: comment)),
      ),
    );
  }

  /// “提到这篇的日记”；日记在回收站、截取分享长图期间或没有日记提到它时
  /// 为 null（不显示）。未解封的胶囊不建正文，这一块随正文一起不出现。
  DiaryPreviewBacklinks? _resolveBacklinks(Diary diary) {
    if (diary.isDeleted) return null;
    final target = DiaryLinkTarget.diary(widget.diaryId);
    final items = ref.watch(diaryPreviewBacklinksProvider(target)).value;
    if (items == null || items.isEmpty || _export.capturingLongImage) {
      return null;
    }
    return DiaryPreviewBacklinks(target: target, items: items);
  }

  Future<void> _deleteDiary() async {
    final shouldDelete = await confirmDiaryPreviewDelete(context);
    if (!mounted || !shouldDelete) {
      return;
    }
    final db = ref.read(appDatabaseProvider);
    await db.softDeleteDiary(widget.diaryId, touchUpdatedAt: false);
    if (!mounted) {
      return;
    }
    _finishDeleted();
  }

  Widget _messageScaffold(Widget body) {
    final embedded = widget.host != null;
    return Scaffold(
      // 读取中 / 出错：独立页面时透出预览区域背景，嵌在右栏时透出宿主日记页
      // 的背景；都没有背景时就是原来的 surface。
      backgroundColor: AppPageBackdrop.pageColorOf(context),
      appBar: AppTopBar(
        centerTitle: true,
        // 嵌入时与正文顶栏一致：不要返回按钮，也不要“日记”标题。
        title: embedded ? null : Text(context.l10n.autoT0120),
        automaticallyImplyLeading: !embedded,
        leading: embedded ? null : const DiaryPreviewBackButton(),
      ),
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _buildPage(context);
    // 嵌入时让顶栏知道不画返回按钮（顶栏由版式组件构建，不经这里传参）。
    return widget.host == null ? page : DiaryPreviewHostScope(child: page);
  }

  Widget _buildPage(BuildContext context) {
    final detailAsync = ref.watch(diaryDetailProvider(widget.diaryId));

    // 入口（列表、搜索、日历）已持有同一篇日记的完整数据（分页查询包含正文与
    // 标签）：详情首查返回前直接用它渲染整页，路由滑入时就是完整内容，而不是
    // 先出 1~2 帧空壳再整页硬切。查询返回后渲染同一结构；正文未变时 原生编辑器
    // 控制器不会重建，画面没有变化。
    final initialDetail = widget.initialDetail;
    if (initialDetail != null &&
        !detailAsync.hasValue &&
        !detailAsync.hasError) {
      return _buildDetailPage(initialDetail);
    }

    return detailAsync.when(
      loading: () => _messageScaffold(const DelayedLoadingIndicator()),
      error: (Object error, StackTrace stackTrace) => _messageScaffold(
        Center(child: Text(context.l10n.autoT0121(error.toString()))),
      ),
      data: (DiaryWithTags? detail) {
        if (detail == null) {
          if (_hadLoadedData) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              _showHint(context.l10n.autoT0122);
              final host = widget.host;
              if (host != null) {
                host.onVanished();
                return;
              }
              Navigator.of(context).pop();
            });
            return _messageScaffold(
              Center(child: Text(context.l10n.autoT0123)),
            );
          }
          return _messageScaffold(Center(child: Text(context.l10n.autoT0124)));
        }
        return _buildDetailPage(detail);
      },
    );
  }

  /// 已拿到日记数据时的完整页面（首查返回前的入口数据与查询结果共用）。
  Widget _buildDetailPage(DiaryWithTags detail) {
    _hadLoadedData = true;
    final capsuleState = TimeCapsuleState.fromFields(
      lockedAt: detail.diary.capsuleLockedAt,
      unlockAt: detail.diary.capsuleUnlockAt,
      now: DateTime.now(),
    );
    if (capsuleState.isLocked) {
      return LockedDiaryPage(
        diaryId: widget.diaryId,
        initialDetail: detail,
        host: widget.host,
      );
    }
    _currentDetail = detail;
    _bindController(detail.diary.content);
    final viewData = DiaryPreviewViewData.resolve(
      detail.diary,
      previous: _viewData,
    );
    _viewData = viewData;

    final style = ref.watch(diaryPreviewStyleProvider);
    final behavior = ref.watch(diaryPreviewBehaviorProvider);
    final resolved = DiaryPreviewResolvedStyle.resolve(
      style: style,
      appTheme: Theme.of(context),
      appSeed: ref.watch(appThemeSeedColorProvider),
      screenSize: MediaQuery.sizeOf(context),
      reduceMotion: MediaQuery.disableAnimationsOf(context),
      moodPalette: ref.watch(diaryMoodPaletteProvider),
      moodEmoji: viewData.moodEmoji,
      firstTagColor: detail.tags.isEmpty ? null : detail.tags.first.color,
    );
    // 日记本功能关闭时隐藏入口，数据保留：不订阅这篇所在的本子，信息栏
    // 没有日记本胶囊（也不因它显示信息栏）。
    final notebooksEnabled = ref.watch(
      appFeaturesProvider.select((features) => features.notebooks),
    );
    final notebooks = notebooksEnabled
        ? ref.watch(diaryNotebooksProvider(widget.diaryId)).value ??
              const <NotebookView>[]
        : const <NotebookView>[];
    final comments = _resolveComments(detail.diary);
    final canComment =
        ref.watch(diaryCommentsEnabledProvider) && !detail.diary.isDeleted;
    return DiaryPreviewSurface(
      resolved: resolved,
      scrollController: _scrollController,
      content: WidgetShotPlus(
        key: _shareCaptureKey,
        child: DiaryPreviewContent(
          detail: detail,
          viewData: viewData,
          controller: _controller,
          scrollController: _scrollController,
          resolved: resolved,
          behavior: behavior,
          // 嵌入时不建立共享元素：列表卡片与右栏同在一个路由。
          coverHeroTag: widget.host != null
              ? null
              : widget.coverHeroTag ?? diaryCoverHeroTag(widget.diaryId),
          coverPlaceholder: widget.coverHero?.placeholder,
          staticCover: _export.staticCover,
          paging: widget.paging,
          notebooks: notebooks,
          comments: comments,
          backlinks: _resolveBacklinks(detail.diary),
          onOpenNotebook: notebooksEnabled
              ? (NotebookView notebook) =>
                    unawaited(openNotebookFromAnywhere(context, ref, notebook))
              : null,
          onOpenTag: (int tagId) =>
              unawaited(openDiaryTagSearch(context, tagId)),
          onOpenImage: _openImageViewer,
          actions: DiaryPreviewActions(
            onOpenTypography: () => showDiaryTypographySheet(context),
            onEdit: _openEditor,
            onShare: () => openDiaryPreviewShare(
              context,
              ref,
              export: _export,
              detail: detail,
              background: resolved.background,
            ),
            onMore: () => showDiaryPreviewMore(
              context,
              ref,
              export: _export,
              detail: detail,
              background: resolved.background,
              onDelete: _deleteDiary,
              notebooks: notebooks,
              onWriteComment: canComment
                  ? () => _writeComment(detail.diary, reveal: true)
                  : null,
            ),
          ),
        ),
      ),
      overlay: ActionLoadingOverlay(
        visible: _export.showLoading,
        label: _export.loadingLabel,
      ),
    );
  }
}
