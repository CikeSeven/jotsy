import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_breakpoints.dart';
import '../../../../core/services/app_platform.dart';
import '../../../app_surface/widgets/app_glass_scope.dart';
import '../../../widgets/primary_shortcut.dart';
import '../../controllers/diary_editor_controller.dart';
import '../../controllers/diary_find_replace.dart';
import '../../models/diary_find_query.dart';
import '../../models/diary_toolbar_layout.dart';
import '../diary_find_bar/diary_find_bar.dart';
import '../diary_find_bar/diary_floating_find_transitions.dart';
import '../diary_floating_toolbar_surface.dart';

/// 预览页的正文查找（只找、不替换）：顶栏“更多 → 查找”、桌面 Ctrl / ⌘ + F
/// 打开；从搜索结果打开日记时带着搜索词打开（`DiaryPreviewView.initialFind`）。
///
/// - 查找栏与编辑页同一个 [DiaryFindBar]，放在悬浮于页面底部、键盘之上的
///   卡片里（与编辑页的悬浮工具栏同一材质），出现时升起淡入、关闭时降下
///   淡出（[DiaryFloatingPresence]）；
/// - 高亮与跳转在正文会话的 [DiaryFindReplace] 里，只读正文同样能用，跳到
///   收起的折叠块里时只展开本地显示状态；
/// - 开着时页尾多留出查找栏的高度，最后几行也能滚到查找栏上方；返回键 /
///   Esc 先关掉查找（[DiaryPreviewFindHost.wrapFindPopScope]）。
///
/// 正文控制器随内容变化重建（如勾选待办写库后）时，开着的查找带到新的
/// 会话上，查找栏不消失。

/// 预览页的“打开查找”请求：桌面的 Ctrl / ⌘ + F 由路由层（单篇预览页、
/// 翻页器）在 `DesktopPageKeys` 外面接住——那里自带一个 autofocus 的
/// Focus，正文与输入框都没有焦点时按键从它起冒泡，包在里面的快捷键收不到
/// ——再按日记 id 交给当前那一篇（翻页器里左右几篇都挂着）。
class DiaryPreviewFindRequests extends ChangeNotifier {
  String? _target;

  /// 最近一次请求的日记业务 id。
  String? get target => _target;

  void request(String diaryId) {
    _target = diaryId;
    notifyListeners();
  }
}

/// 在 [child]（含 `DesktopPageKeys`）外面接住桌面的 Ctrl / ⌘ + F，交给
/// [currentDiaryId] 那一篇（见 [DiaryPreviewFindRequests]）。手机上只提供
/// 请求通道，不加快捷键。
class DiaryPreviewFindShortcuts extends StatefulWidget {
  const DiaryPreviewFindShortcuts({
    super.key,
    required this.currentDiaryId,
    required this.child,
  });

  final String Function() currentDiaryId;
  final Widget child;

  @override
  State<DiaryPreviewFindShortcuts> createState() =>
      _DiaryPreviewFindShortcutsState();
}

class _DiaryPreviewFindShortcutsState extends State<DiaryPreviewFindShortcuts> {
  final DiaryPreviewFindRequests _requests = DiaryPreviewFindRequests();

  @override
  void dispose() {
    _requests.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scoped = _DiaryPreviewFindScope(
      requests: _requests,
      child: widget.child,
    );
    if (!AppPlatform.isDesktop) return scoped;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        primaryShortcut(LogicalKeyboardKey.keyF): () =>
            _requests.request(widget.currentDiaryId()),
      },
      child: scoped,
    );
  }
}

class _DiaryPreviewFindScope extends InheritedWidget {
  const _DiaryPreviewFindScope({required this.requests, required super.child});

  final DiaryPreviewFindRequests requests;

  @override
  bool updateShouldNotify(_DiaryPreviewFindScope oldWidget) =>
      requests != oldWidget.requests;
}

/// 预览页一篇日记的查找状态与界面（`DiaryPreviewView` 的 State 混入）。
///
/// 宿主负责：正文控制器绑定 / 换掉时调用 [attachFind]、销毁前 [detachFind]；
/// 把 [findBottomPadding] 加到页尾留白，把 [buildFindBar] 交给页面外壳的
/// 底部浮层，用 [wrapFindPopScope] 包住页面；实现 [findDiaryId]。
mixin DiaryPreviewFindHost<T extends StatefulWidget> on State<T> {
  final GlobalKey<DiaryFindBarState> _findBarKey =
      GlobalKey<DiaryFindBarState>();
  DiaryEditorController? _findController;
  DiaryPreviewFindRequests? _findRequests;

  /// 卡片还挂着：查找开着，或关上后还在降下的过渡里。
  bool _findCardMounted = false;
  bool _findAutofocus = true;
  bool _findWasOpen = false;

  /// 这一篇的日记业务 id（接住 Ctrl / ⌘ + F 时比对）。
  String get findDiaryId;

  DiaryFindReplace? get _find => _findController?.find;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final requests = context
        .dependOnInheritedWidgetOfExactType<_DiaryPreviewFindScope>()
        ?.requests;
    if (requests == _findRequests) return;
    _findRequests?.removeListener(_onFindRequest);
    _findRequests = requests?..addListener(_onFindRequest);
  }

  @override
  void dispose() {
    _findRequests?.removeListener(_onFindRequest);
    super.dispose();
  }

  void _onFindRequest() {
    if (mounted && _findRequests?.target == findDiaryId) openFind();
  }

  /// 换上新的正文控制器（首次绑定或内容变化重建），在释放旧控制器之前
  /// 调用（构建期间也可以）。旧会话开着查找时把查找条件带到新会话上；
  /// [initial] 给出时（首次绑定、从搜索打开）这一帧之后带着它打开查找，
  /// 正文里没有匹配就不打开。
  void attachFind(DiaryEditorController controller, {DiaryFindQuery? initial}) {
    final previous = _findController;
    final carried = previous != null && previous.find.isOpen
        ? previous.find.query
        : null;
    detachFind();
    _findController = controller;
    // 先打开再订阅：绑定发生在构建里，打开时的通知不能触发重建。
    if (carried != null) controller.find.open(query: carried, fromStart: true);
    _findWasOpen = carried != null;
    controller.find
      ..addListener(_onFindChanged)
      ..barHeight.addListener(_onFindChanged);
    if (initial == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_findController, controller)) return;
      final find = controller.find;
      if (find.isOpen) return;
      openFind(query: initial, focus: false);
      if (find.isOpen && find.matches.isEmpty) {
        setState(() {
          find.close();
          _findCardMounted = false;
        });
      }
    });
  }

  /// 不再看这个控制器（换掉之前、页面销毁时）。
  void detachFind() {
    final find = _find;
    if (find == null) return;
    find
      ..removeListener(_onFindChanged)
      ..barHeight.removeListener(_onFindChanged);
    _findController = null;
  }

  /// 只在开关查找与查找栏量好新高度时重建页面（页尾留白、底部浮层）；
  /// 输入查找文字、跳到下一处由查找栏与高亮自己刷新。
  void _onFindChanged() {
    final find = _find;
    if (!mounted || find == null) return;
    final open = find.isOpen;
    if (open == _findWasOpen && !_barHeightChanged(find)) return;
    _findWasOpen = open;
    setState(() {
      if (open) _findCardMounted = true;
    });
  }

  double _lastBarHeight = 0;
  bool _barHeightChanged(DiaryFindReplace find) {
    final height = find.barHeight.value;
    if (height == _lastBarHeight) return false;
    _lastBarHeight = height;
    return true;
  }

  /// 打开查找；已开着时把焦点交回查找框。[query] 整个换掉查找条件、从文首
  /// 找；[focus] 为 false 时不取焦点、不弹键盘。
  void openFind({DiaryFindQuery? query, bool focus = true}) {
    final find = _find;
    if (find == null) return;
    final bar = _findBarKey.currentState;
    setState(() {
      _findAutofocus = focus;
      _findCardMounted = true;
      find.open(query: query, fromStart: query != null);
    });
    if (bar != null && focus) bar.focusFind();
  }

  void closeFind() {
    final find = _find;
    if (find == null || !find.isOpen) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(find.close);
  }

  /// 开着查找时页尾多留的高度：最后几行能滚到查找栏上方。
  double get findBottomPadding {
    final find = _find;
    if (find == null || !find.isOpen) return 0;
    return find.barHeight.value + kDiaryFindBarGap;
  }

  /// 底部的查找卡片；没有时为 null。
  Widget? buildFindBar(BuildContext context) {
    final find = _find;
    if (find == null || !_findCardMounted) return null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kDiaryFloatingToolbarInset,
        0,
        kDiaryFloatingToolbarInset,
        8,
      ),
      child: CenteredContent(
        maxWidth: AppContentWidth.editor,
        child: DiaryFloatingPresence(
          glass: AppGlass.of(context).isGlass(AppGlassComponent.toolbar),
          visible: find.isOpen,
          onHidden: () {
            if (mounted && !find.isOpen) {
              setState(() => _findCardMounted = false);
            }
          },
          child: DiaryFloatingToolbarSurface(
            child: DiaryFindBar(
              key: _findBarKey,
              find: find,
              onClose: closeFind,
              autofocus: _findAutofocus,
            ),
          ),
        ),
      ),
    );
  }

  /// 查找开着时返回键 / Esc 先关掉查找。
  Widget wrapFindPopScope(Widget child) {
    final open = _find?.isOpen ?? false;
    return PopScope(
      canPop: !open,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop) closeFind();
      },
      child: child,
    );
  }
}
