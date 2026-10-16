import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:widget_screenshot_plus/widget_screenshot_plus.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/content_codec.dart';
import '../../../../core/services/app_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../anniversaries/controllers/anniversary_navigation.dart';
import '../../../anniversaries/models/anniversary_draft.dart';
import '../../../home/widgets/home_hint_visibility_scope.dart';
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
import '../../providers/diary_detail_provider.dart';
import '../../sections/diary_typography_sheet.dart';
import '../../viewmodels/diary_preview_view_data.dart';
import 'diary_preview_actions_sheet.dart';
import 'diary_preview_content.dart';
import 'diary_preview_dialogs.dart';
import 'diary_preview_top_bar.dart';

/// 一篇日记的预览（阅读优先）：数据、只读正文与动作。
///
/// 输入：日记业务 id，可选的入口数据（同一篇的 `DiaryWithTags`，首帧直接
/// 渲染）与列表封面抓取的共享元素（本组件销毁时释放）。输出：整页
/// Scaffold；未解封的时间胶囊内联显示封存页。副作用：勾选待办写库（见
/// [DiaryTodoAutoSaveController]）、导出与删除。
///
/// 状态：详情查询返回前用入口数据渲染，返回后由最新数据接管；正文只在内容
/// 变化时重建 Quill 控制器。
class DiaryPreviewView extends ConsumerStatefulWidget {
  const DiaryPreviewView({
    super.key,
    required this.diaryId,
    this.initialDetail,
    this.coverHero,
  });

  final String diaryId;

  /// 入口已持有的同一篇日记（`diary.diaryId` 必须等于 [diaryId]）。
  final DiaryWithTags? initialDetail;

  /// 列表封面抓取的画面：头图以它为共享元素落点与占位。
  final ImageViewerHero? coverHero;

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
  late final DiaryTodoAutoSaveController _todoAutoSave =
      DiaryTodoAutoSaveController(
        readDetail: () => _currentDetail,
        readDocument: () => _controller?.document,
        readDatabase: () => ref.read(appDatabaseProvider),
        onSaved: () {
          if (mounted) {
            ref.invalidate(diaryDetailProvider(widget.diaryId));
          }
        },
      );

  quill.QuillController? _controller;
  String? _boundContentRaw;
  StreamSubscription<quill.DocChange>? _docChanges;
  DiaryWithTags? _currentDetail;
  DiaryPreviewViewData? _viewData;
  bool _hadLoadedData = false;

  @override
  void dispose() {
    // 返回飞行在本帧绘制前已结束，此时释放占位画面是安全的。
    widget.coverHero?.dispose();
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
    if (mounted) {
      setState(() {});
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
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
    Navigator.of(context).pop(DiaryPreviewResult.deleted);
  }

  Future<void> _showActions(DiaryWithTags detail) {
    return showDiaryPreviewActionsSheet(
      context,
      onShareImage: () => _export.shareLongImage(context),
      onExportMarkdown: () async {
        final controller = _controller;
        if (controller == null) {
          return;
        }
        await _export.exportMarkdown(
          context,
          detail: detail,
          document: controller.document,
        );
      },
      onExportPdf: () async {
        final controller = _controller;
        if (controller == null) {
          return;
        }
        await _export.exportPdf(
          context,
          detail: detail,
          document: controller.document,
        );
      },
      onExportDiaryFile: () => _export.exportDiaryFile(
        context,
        detail: detail,
        database: ref.read(appDatabaseProvider),
      ),
      onSetAsAnniversary: () => openAnniversaryEditor(
        context,
        database: ref.read(appDatabaseProvider),
        draft: AnniversaryDraft.fromDiary(detail.diary),
      ),
      onDelete: _deleteDiary,
    );
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

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        top: false,
        child: Stack(
          children: <Widget>[
            WidgetShotPlus(
              key: _shareCaptureKey,
              child: DiaryPreviewContent(
                detail: detail,
                viewData: viewData,
                controller: _controller,
                scrollController: _scrollController,
                coverPlaceholder: widget.coverHero?.placeholder,
                staticCover: _export.staticCover,
                onOpenImage: _openImageViewer,
                onOpenTypography: () => showDiaryTypographySheet(context),
                onEdit: _openEditor,
                onMore: () => _showActions(detail),
              ),
            ),
            Positioned.fill(
              child: ActionLoadingOverlay(
                visible: _export.showLoading,
                label: _export.loadingLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
