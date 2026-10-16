import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../app/theme/expressive_motion.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../diaries/models/diary_card_style/diary_card_style.dart';
import '../../widgets/app_top_bar.dart';
import '../controllers/diary_card_style_editor_controller.dart';
import '../sections/diary_card_style/diary_card_style_color_tab.dart';
import '../sections/diary_card_style/diary_card_style_common.dart';
import '../sections/diary_card_style/diary_card_style_content_tab.dart';
import '../sections/diary_card_style/diary_card_style_cover_tab.dart';
import '../sections/diary_card_style/diary_card_style_date_tab.dart';
import '../sections/diary_card_style/diary_card_style_layout_tab.dart';
import '../sections/diary_card_style/diary_card_style_order_tab.dart';
import '../sections/diary_card_style/diary_card_style_presets_tab.dart';
import '../sections/diary_card_style/diary_card_style_preview.dart';
import '../sections/diary_card_style/diary_card_style_samples.dart';
import '../sections/diary_card_style/diary_card_style_text_tab.dart';
import '../sections/diary_card_style/diary_card_style_texture_tab.dart';

/// 设置 → 外观与语言 → 日记卡片样式。
///
/// 页面壳层：上方吸附实时预览，下方按标签页分组调整（预设、布局、封面、
/// 内容、日期、排序、字体、色彩、质感）。宽屏（≥720dp）时预览与选项左右
/// 并排。状态与写入由 [DiaryCardStyleEditorController] 负责，改动即时生效、
/// 无需保存；右上角“重置”回到默认样式并提供撤销。
///
/// 标签页之间禁用横滑：选项里有大量滑块与拖拽排序，横滑切页会与它们抢
/// 手势。
class DiaryCardStylePage extends StatefulWidget {
  const DiaryCardStylePage({
    super.key,
    required this.settingsService,
    this.initialMode = DiaryCardMode.list,
  });

  final SettingsService settingsService;

  /// 打开时预览与编辑的布局（从日记页进入时取当前布局）。
  final DiaryCardMode initialMode;

  @override
  State<DiaryCardStylePage> createState() => _DiaryCardStylePageState();
}

class _DiaryCardStylePageState extends State<DiaryCardStylePage>
    with SingleTickerProviderStateMixin {
  static const int _tabCount = 9;

  late final DiaryCardStyleEditorController _controller =
      DiaryCardStyleEditorController(
        settingsService: widget.settingsService,
        initialMode: widget.initialMode,
      );
  TabController? _tabController;
  List<DiaryWithTags>? _samples;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 切页动画时长取 ExpressiveMotion token（减少动画时为 0），需要读取
    // MediaQuery，因此在首次 didChangeDependencies 而不是 initState 里创建。
    _tabController ??= TabController(
      length: _tabCount,
      vsync: this,
      animationDuration: ExpressiveMotion.duration(
        context,
        ExpressiveMotion.medium,
      ),
    );
    _samples ??= buildDiaryCardStyleSamples(context.l10n, now: DateTime.now());
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    final message = context.l10n.diaryCardStyleResetDone;
    final previous = await _controller.reset();
    if (!mounted) {
      return;
    }
    unawaited(
      showDiaryCardStyleUndoSnackBar(
        context,
        message: message,
        onUndo: () => _controller.applyStyle(previous),
      ),
    );
  }

  List<Tab> _tabs(AppLocalizations l10n) => <Tab>[
    Tab(text: l10n.diaryCardStyleTabPresets),
    Tab(text: l10n.diaryCardStyleTabLayout),
    Tab(text: l10n.diaryCardStyleTabCover),
    Tab(text: l10n.diaryCardStyleTabContent),
    Tab(text: l10n.diaryCardStyleTabDate),
    Tab(text: l10n.diaryCardStyleTabOrder),
    Tab(text: l10n.diaryCardStyleTabText),
    Tab(text: l10n.diaryCardStyleTabColor),
    Tab(text: l10n.diaryCardStyleTabTexture),
  ];

  List<Widget> _tabViews() => <Widget>[
    DiaryCardStylePresetsTab(controller: _controller),
    DiaryCardStyleLayoutTab(controller: _controller),
    DiaryCardStyleCoverTab(controller: _controller),
    DiaryCardStyleContentTab(controller: _controller),
    DiaryCardStyleDateTab(controller: _controller),
    DiaryCardStyleOrderTab(controller: _controller),
    DiaryCardStyleTextTab(controller: _controller),
    DiaryCardStyleColorTab(controller: _controller),
    DiaryCardStyleTextureTab(controller: _controller),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tabController = _tabController!;
    return Scaffold(
      appBar: AppTopBar(
        title: Text(l10n.diaryCardStyleTitle),
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
        actions: <Widget>[
          ListenableBuilder(
            listenable: _controller,
            builder: (BuildContext context, Widget? child) => TextButton(
              onPressed: _controller.style.isDefault ? null : _reset,
              child: Text(l10n.commonReset),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (BuildContext context, Widget? child) {
          return LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final preview = DiaryCardStylePreview(
                controller: _controller,
                samples: _samples!,
                moodOptions: widget.settingsService.moodOptions,
              );
              final options = Column(
                children: <Widget>[
                  TabBar(
                    controller: tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    tabs: _tabs(l10n),
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: tabController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: _tabViews(),
                    ),
                  ),
                ],
              );
              if (constraints.maxWidth >= 720) {
                return Row(
                  children: <Widget>[
                    Expanded(child: preview),
                    const VerticalDivider(width: 1),
                    Expanded(child: options),
                  ],
                );
              }
              // 预览约占四成高度（220~360），矮屏（横屏、分屏）上不超过一半，
              // 给标签页留出可用空间。
              final previewHeight = math.min(
                (constraints.maxHeight * 0.38).clamp(220.0, 360.0).toDouble(),
                constraints.maxHeight * 0.5,
              );
              return Column(
                children: <Widget>[
                  SizedBox(height: previewHeight, child: preview),
                  const Divider(height: 1),
                  Expanded(child: options),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
