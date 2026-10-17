import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:widget_screenshot_plus/widget_screenshot_plus.dart';

import '../../../core/database/app_database.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../models/diary_share_content.dart';
import '../models/diary_share_options.dart';
import '../models/diary_share_target.dart';
import '../sections/diary_share_sheet.dart';
import '../viewmodels/diary_share_messages.dart';
import 'diary_export_flow.dart';
import 'diary_share_controller.dart';

/// 预览页的分享与导出：分享面板（指定应用、系统分享、复制文字）、长图，以及
/// 经共用导出流程（`runDiaryExportFlow`）导出这一篇。
///
/// 输入：截图节点 [captureKey] 与正文 [scrollController]（页面持有），以及
/// 每次调用时传入的 context 与日记。输出：页面要显示的加载遮罩、静态头图
/// 状态与忙碌态（经 [ChangeNotifier] 通知，翻页器据此暂停翻页），结果提示经
/// [onHint] 给出。副作用：写临时文件，调起系统分享、目标应用与保存对话框。
///
/// 同一时刻只运行一个动作，进行中再次触发直接忽略。分享与长图在本控制器的
/// 加载遮罩下执行：动作开始前先让遮罩真正绘制出来，并保证最短可见时长，避免
/// “闪现式”动画；导出流程自带根 Overlay 上的遮罩，这里只报告忙碌。调用方的
/// context 卸载后不再提示，也不再通知。
class DiaryPreviewExportController extends ChangeNotifier {
  DiaryPreviewExportController({
    required this.captureKey,
    required this.scrollController,
    required this.onHint,
  });

  /// 加载遮罩的最短可见时长（防闪，不是动画时长）。
  static const Duration _minLoadingVisible = Duration(milliseconds: 320);

  final GlobalKey captureKey;
  final ScrollController scrollController;
  final ValueChanged<String> onHint;

  bool _showLoading = false;
  String _loadingLabel = '';
  bool _sharingImage = false;
  bool _staticCover = false;
  bool _exporting = false;
  bool _disposed = false;
  final DiaryShareController _share = DiaryShareController();

  /// 是否显示动作加载遮罩。
  bool get showLoading => _showLoading;
  String get loadingLabel => _loadingLabel;

  /// 分享长图期间用静态头图替换会随滚动折叠的头图，避免长图拼接出现拖影。
  bool get staticCover => _staticCover;

  /// 正在执行任一动作（遮罩、截图或导出中）。
  bool get busy => _showLoading || _sharingImage || _exporting;

  void _update(VoidCallback change) {
    change();
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// 分享整页长图；[background] 为长图底色（页面的纸色），默认取主题
  /// surface。
  Future<void> shareLongImage(BuildContext context, {Color? background}) async {
    if (_sharingImage || _showLoading) {
      return;
    }
    await _runWithLoading(
      context,
      label: context.l10n.autoT0114,
      action: () async {
        final l10n = context.l10n;
        final surfaceColor =
            background ?? Theme.of(context).colorScheme.surface;
        final pixelRatio = MediaQuery.of(
          context,
        ).devicePixelRatio.clamp(1.0, 2.2);
        _update(() {
          _sharingImage = true;
          // 分享截图时禁用封面折叠动画，避免长图拼接出现拖影。
          _staticCover = true;
        });
        try {
          // 等待 bottom sheet 完全关闭，避免截图带上遮罩层。
          await Future<void>.delayed(const Duration(milliseconds: 80));
          if (!context.mounted) {
            return;
          }
          if (scrollController.hasClients) {
            // 强制回到顶部，保证封面按“完整展开”形态进入截图。
            scrollController.jumpTo(0);
          }
          await Future<void>.delayed(const Duration(milliseconds: 60));
          final renderObject = captureKey.currentContext?.findRenderObject();
          if (renderObject is! WidgetShotPlusRenderRepaintBoundary) {
            throw Exception('截图节点未就绪');
          }
          final imageBytes = await renderObject.screenshot(
            scrollController: scrollController.hasClients
                ? scrollController
                : null,
            format: ShotFormat.png,
            quality: 100,
            maxHeight: 22000,
            backgroundColor: surfaceColor,
            pixelRatio: pixelRatio,
          );
          if (imageBytes == null || imageBytes.isEmpty) {
            throw Exception(l10n.autoT0111);
          }
          final tempDirectory = await getTemporaryDirectory();
          final imagePath = p.join(
            tempDirectory.path,
            'diary_share_${DateTime.now().millisecondsSinceEpoch}.png',
          );
          final imageFile = File(imagePath);
          await imageFile.writeAsBytes(imageBytes, flush: true);

          await Share.shareXFiles(<XFile>[XFile(imageFile.path)]);
        } catch (error) {
          if (!context.mounted) {
            return;
          }
          onHint(context.l10n.autoT0112(error.toString()));
        } finally {
          if (context.mounted) {
            _update(() {
              _sharingImage = false;
              _staticCover = false;
            });
          }
        }
      },
    );
  }

  /// 打开分享面板，按用户的选择分享长图、分享到指定应用 / 系统分享或复制
  /// 文字。
  ///
  /// 已安装应用的检测与面板打开并行：检测完成前面板先显示系统分享与复制，
  /// 不让原生查询拖慢面板出现。内容开关在面板内每次改动即保存；[background]
  /// 同 [shareLongImage]。
  Future<void> openShareSheet(
    BuildContext context, {
    required DiaryWithTags detail,
    required SettingsService settings,
    Color? background,
  }) async {
    if (busy) {
      return;
    }
    final request = await showDiaryShareSheet(
      context,
      content: DiaryShareContent.fromDetail(detail),
      initialOptions: DiaryShareOptions.fromRaw(settings.diaryShareOptionsRaw),
      // 开关只是下次打开时的默认值，写入失败不打断本次分享。
      onOptionsChanged: (DiaryShareOptions options) => unawaited(
        settings
            .setDiaryShareOptionsRaw(options.toRaw())
            .catchError((Object _) {}),
      ),
      availableTargets: _share.availableTargets(),
    );
    if (!context.mounted || request == null) {
      return;
    }
    if (request.action == DiaryShareAction.longImage) {
      await shareLongImage(context, background: background);
      return;
    }
    final l10n = context.l10n;
    await _runWithLoading(
      context,
      label: l10n.diaryShareInProgress,
      action: () async {
        try {
          final target = request.target;
          final result = target == null
              ? await _share.copyText(request.text)
              : await _share.share(
                  target,
                  text: request.text,
                  images: request.images,
                  chooserTitle: l10n.diaryShareTargetsSection,
                );
          final message = diaryShareResultMessage(l10n, result, target: target);
          if (context.mounted && message != null) {
            onHint(message);
          }
        } catch (error) {
          if (context.mounted) {
            onHint(l10n.diaryShareFailed(error.toString()));
          }
        }
      },
    );
  }

  /// 导出这一篇：格式选择、密码、生成与保存都在共用导出流程里。
  Future<void> exportDiary(
    BuildContext context,
    WidgetRef ref, {
    required DiaryWithTags detail,
  }) async {
    if (busy) {
      return;
    }
    _update(() => _exporting = true);
    try {
      await runDiaryExportFlow(
        context,
        ref,
        diaries: <DiaryWithTags>[detail],
        showHint: onHint,
      );
    } finally {
      if (context.mounted) {
        _update(() => _exporting = false);
      }
    }
  }

  /// 统一动作加载态：共享的遮罩 loading，限制最短可见时长，并在真正的重
  /// 任务前预留一帧，让动画先渲染出来。
  Future<void> _runWithLoading(
    BuildContext context, {
    required String label,
    required Future<void> Function() action,
  }) async {
    if (_showLoading) {
      return;
    }
    final startedAt = DateTime.now();
    if (context.mounted) {
      _update(() {
        _showLoading = true;
        _loadingLabel = label;
      });
    }

    // 先渲染 loading，再执行 IO/截图等重任务，避免动画“卡住不动”。
    // 等到包含遮罩的那一帧真正提交，而不是猜一个固定毫秒数。
    await WidgetsBinding.instance.endOfFrame;

    try {
      await action();
    } finally {
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < _minLoadingVisible) {
        await Future<void>.delayed(_minLoadingVisible - elapsed);
      }
      if (context.mounted) {
        _update(() {
          _showLoading = false;
          _loadingLabel = '';
        });
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
