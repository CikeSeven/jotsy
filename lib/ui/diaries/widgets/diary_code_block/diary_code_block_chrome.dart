import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' show Block, QuillController;

import '../../../../l10n/app_localizations.dart';
import '../../../home/widgets/home_hint_visibility_scope.dart';
import '../../controllers/diary_code_block_editing.dart';
import '../../controllers/diary_code_language_tracker.dart';
import '../../viewmodels/diary_code_block_look.dart';
import 'render_diary_code_block_chrome.dart';

// 代码块标题栏：包在 QuillEditor 外，给每个代码块画上“语言名 + 复制”标题栏
// （渲染与几何见 RenderDiaryCodeBlockChrome）。
//
// 输入：代码块外观、正文控制器与它的语言识别状态、可选的编辑器滚动控制器。
// 输出：标题栏；点复制把该块的纯文本写入剪贴板，轻震一次并提示“已复制
// 代码”，复制图标换成对勾 1.5 秒。
// 副作用：写系统剪贴板；一个复位对勾的计时器（非动画计时，不走
// ExpressiveMotion），销毁时取消。
//
// 关闭标题栏时本组件仍在树上、只是什么都不做：开关切换时 QuillEditor 的
// 父链不变，编辑器状态（焦点、输入法连接、手势状态）不会因为多包或少包
// 一层而被重建。

/// 代码块标题栏；由 DiaryQuillStylesBuilder 包在编辑器外。
class DiaryCodeBlockChrome extends StatefulWidget {
  const DiaryCodeBlockChrome({
    super.key,
    required this.look,
    required this.controller,
    required this.tracker,
    this.scrollController,
    required this.child,
  });

  /// 复制后对勾停留的时长。
  static const Duration copiedDuration = Duration(milliseconds: 1500);

  final DiaryCodeBlockLook look;
  final QuillController controller;
  final DiaryCodeLanguageTracker tracker;

  /// 编辑器自带滚动视图时（`scrollable: true`）传它的滚动控制器：标题栏随
  /// 滚动重画，并把从标题栏开始的竖向拖动交给它。
  final ScrollController? scrollController;

  /// QuillEditor。
  final Widget child;

  @override
  State<DiaryCodeBlockChrome> createState() => _DiaryCodeBlockChromeState();
}

class _DiaryCodeBlockChromeState extends State<DiaryCodeBlockChrome> {
  Block? _copied;
  Timer? _resetCopied;

  Future<void> _copy(Block block) async {
    try {
      await copyDiaryCodeBlock(block);
    } on PlatformException {
      // 剪贴板不可用：不提示成功、不换对勾。
      return;
    }
    if (!mounted) {
      return;
    }
    // 复制生效的一刻轻震（DESIGN.md §4.3）。
    unawaited(HapticFeedback.lightImpact());
    unawaited(
      HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(content: Text(context.l10n.codeBlockCopied)),
      ),
    );
    _resetCopied?.cancel();
    setState(() => _copied = block);
    _resetCopied = Timer(DiaryCodeBlockChrome.copiedDuration, () {
      if (mounted) {
        setState(() => _copied = null);
      }
    });
  }

  @override
  void dispose() {
    _resetCopied?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 应用里总有本地化；只有未装配应用文案的组件测试会走到这里，此时不画
    // 标题栏（语言名与提示都没有文案可用）。
    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (l10n == null) {
      return widget.child;
    }
    final theme = Theme.of(context);
    // 标题栏高度固定，限制系统字号的放大倍数，语言名不至于撑出标题栏。
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 2);
    final labelStyle = (theme.textTheme.labelMedium ?? const TextStyle())
        .copyWith(fontSize: 12, fontWeight: FontWeight.w600);
    // 复制按钮在编辑器的点按区域之外：并入输入框的点按组，点它不算点到
    // 输入框外面（桌面与鼠标 / 手写笔点按时 Quill 会因此收起焦点）。
    return TextFieldTapRegion(
      child: _DiaryCodeBlockChromeLayer(
        look: widget.look,
        controller: widget.controller,
        tracker: widget.tracker,
        scrollController: widget.scrollController,
        l10n: l10n,
        labelStyle: labelStyle,
        textScaler: textScaler,
        textDirection: Directionality.of(context),
        copiedBlock: _copied,
        onCopy: (block) => unawaited(_copy(block)),
        child: widget.child,
      ),
    );
  }
}

class _DiaryCodeBlockChromeLayer extends SingleChildRenderObjectWidget {
  const _DiaryCodeBlockChromeLayer({
    required this.look,
    required this.controller,
    required this.tracker,
    required this.scrollController,
    required this.l10n,
    required this.labelStyle,
    required this.textScaler,
    required this.textDirection,
    required this.copiedBlock,
    required this.onCopy,
    required super.child,
  });

  final DiaryCodeBlockLook look;
  final QuillController controller;
  final DiaryCodeLanguageTracker tracker;
  final ScrollController? scrollController;
  final AppLocalizations l10n;
  final TextStyle labelStyle;
  final TextScaler textScaler;
  final TextDirection textDirection;
  final Block? copiedBlock;
  final ValueChanged<Block> onCopy;

  @override
  RenderDiaryCodeBlockChrome createRenderObject(BuildContext context) {
    return RenderDiaryCodeBlockChrome(
      look: look,
      controller: controller,
      tracker: tracker,
      scrollController: scrollController,
      l10n: l10n,
      labelStyle: labelStyle,
      textScaler: textScaler,
      textDirection: textDirection,
      copiedBlock: copiedBlock,
      onCopy: onCopy,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderDiaryCodeBlockChrome renderObject,
  ) {
    renderObject
      ..look = look
      ..controller = controller
      ..tracker = tracker
      ..scrollController = scrollController
      ..l10n = l10n
      ..labelStyle = labelStyle
      ..textScaler = textScaler
      ..textDirection = textDirection
      ..copiedBlock = copiedBlock
      ..onCopy = onCopy;
  }
}
