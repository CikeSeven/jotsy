import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widget_screenshot_plus/widget_screenshot_plus.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/content_codec.dart';
import '../../../../core/services/app_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../home/widgets/home_hint_visibility_scope.dart';
import '../../../notebooks/controllers/notebook_navigation.dart';
import '../../../notebooks/providers/notebook_providers.dart';
import '../../../notebooks/viewmodels/notebook_view.dart';
import '../../../widgets/action_loading_overlay.dart';
import '../../../widgets/app_top_bar.dart';
import '../../../widgets/delayed_loading_indicator.dart';
import '../../../widgets/image_viewer_hero.dart';
import '../../controllers/diary_preview_export_controller.dart';
import '../../controllers/diary_todo_autosave_controller.dart';
import '../../models/diary_preview_result.dart';
import '../../models/time_capsule.dart';
import '../../pages/edit_diary_page.dart';
import '../../pages/locked_diary_page.dart';
import '../../providers/diary_card_style_provider.dart';
import '../../providers/diary_detail_provider.dart';
import '../../providers/diary_preview_style_provider.dart';
import '../../sections/diary_typography_sheet.dart';
import '../../viewmodels/diary_preview_resolved_style.dart';
import '../../viewmodels/diary_preview_view_data.dart';
import 'diary_preview_actions_sheet.dart';
import 'diary_preview_content.dart';
import 'diary_preview_dialogs.dart';
import 'diary_preview_neighbors.dart';
import 'diary_preview_surface.dart';
import 'diary_preview_top_bar.dart';

/// 一篇日记的预览（阅读优先）：数据、只读正文与动作。
///
/// 输入：日记业务 id，可选的入口数据（同一篇的 `DiaryWithTags`，首帧直接
/// 渲染）与列表封面抓取的共享元素（本组件销毁时释放）。输出：整页
/// Scaffold；未解封的时间胶囊内联显示封存页。副作用：勾选待办写库（见
/// [DiaryTodoAutoSaveController]）、分享、导出与删除。
///
/// 状态：详情查询返回前用入口数据渲染，返回后由最新数据接管；正文只在内容
/// 变化时重建 Quill 控制器。
///
/// 放在翻页器（`DiaryPreviewPager`）里时：[paging] 给出位置与相邻篇，
/// [onBusyChanged] 报告导出 / 分享长图的忙碌态（翻页器据此暂停翻页），共享
/// 元素的标签与占位画面的所有权由翻页器决定（见 [coverHeroTag]、
/// [ownsCoverHero]）。
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

  @override
  ConsumerState<DiaryPreviewView> createState() => _DiaryPreviewViewState();
}

class _DiaryPreviewViewState extends ConsumerState<DiaryPreviewView> {
  final GlobalKey _shareCaptureKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  late final DiaryPreviewExportController _export =
      DiaryPreviewExportController(
        captureKey: _shareCaptureKey,
        scrollController: _scrollController,
        onHint: _showHint,
      )..addListener(_handleExportChanged);
  late final DiaryTodoAutoSaveController _todoAutoSave;

  quill.QuillController? _controller;
  String? _boundContentRaw;
  StreamSubscription<quill.DocChange>? _docChanges;
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
    final controller = quill.QuillController(
      document: decodeDiaryContentToDocument(contentRaw),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
    _controller = controller;
    _docChanges = controller.changes.listen((quill.DocChange change) {
      // 预览页是只读模式，唯一允许的本地变更是待办勾选状态。
      if (change.source != quill.ChangeSource.local) {
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
    // 编辑页里删除日记后以 true 返回：按“已删除”退出，入口给出撤销。经发布
    // 页保存时编辑页以日记 id（String）结束，所以结果类型放宽为 Object?。
    final result = await Navigator.of(context).push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (BuildContext context) {
          return EditDiaryPage(
            diaryId: widget.diaryId,
            entryMode: EditDiaryEntryMode.edit,
          );
        },
      ),
    );
    if (!mounted) {
      return;
    }
    if (result == true) {
      Navigator.of(context).pop(DiaryPreviewResult.deleted(widget.diaryId));
      return;
    }
    ref.invalidate(diaryDetailProvider(widget.diaryId));
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
    Navigator.of(context).pop(DiaryPreviewResult.deleted(widget.diaryId));
  }

  Widget _messageScaffold(Widget body) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppTopBar(
        centerTitle: true,
        title: Text(context.l10n.autoT0120),
        leading: const DiaryPreviewBackButton(),
      ),
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(diaryDetailProvider(widget.diaryId));

    // 入口（列表、搜索、日历）已持有同一篇日记的完整数据（分页查询包含正文与
    // 标签）：详情首查返回前直接用它渲染整页，路由滑入时就是完整内容，而不是
    // 先出 1~2 帧空壳再整页硬切。查询返回后渲染同一结构；正文未变时 Quill
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
      return LockedDiaryPage(diaryId: widget.diaryId, initialDetail: detail);
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
      moodOptions: ref.watch(diaryCardMoodOptionsProvider),
      moodEmoji: viewData.moodEmoji,
      firstTagColor: detail.tags.isEmpty ? null : detail.tags.first.color,
    );
    final notebooks =
        ref.watch(diaryNotebooksProvider(widget.diaryId)).value ??
        const <NotebookView>[];
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
          coverHeroTag:
              widget.coverHeroTag ?? diaryCoverHeroTag(widget.diaryId),
          coverPlaceholder: widget.coverHero?.placeholder,
          staticCover: _export.staticCover,
          paging: widget.paging,
          notebooks: notebooks,
          onOpenNotebook: (NotebookView notebook) =>
              unawaited(openNotebookFromAnywhere(context, ref, notebook)),
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
