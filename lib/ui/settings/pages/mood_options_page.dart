import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';
import '../../diaries/models/diary_mood_palette.dart';
import '../../diaries/viewmodels/diary_card_colors.dart';
import '../../widgets/form_width.dart';
import '../widgets/mood_option_row.dart';
import '../widgets/mood_palette_strip.dart';
import '../widgets/style_editor/style_color_dialog.dart';
import 'package:node_diary/ui/app_surface/models/app_surface_enums.dart';
import 'package:node_diary/ui/app_surface/widgets/app_page_background.dart';

/// 心情符号与心情颜色的自定义页。
///
/// 职责边界：
/// - 输入/输出固定 10 个心情槽位，顺序从低落到高兴；每个槽位一个符号、一个
///   颜色（心情色板，见 `DiaryMoodPalette`）；
/// - 改动先留在页面里的草稿，“保存”时依次写入心情符号与心情颜色（颜色全为
///   内置色时删除设置键），“重置”把两者都恢复为默认（同样要保存才生效）；
/// - 保存到 SettingsService，符号供发布/编辑面板、日历聚合和探索趋势共用，
///   颜色供预览页“心情”配色基调与卡片心情色使用；
/// - 不负责历史日记迁移，历史默认符号仍由权重映射兼容。
class MoodOptionsPage extends StatefulWidget {
  const MoodOptionsPage({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  State<MoodOptionsPage> createState() => _MoodOptionsPageState();
}

class _MoodOptionsPageState extends State<MoodOptionsPage> {
  late final List<TextEditingController> _controllers;
  late final Listenable _emojis;
  late DiaryMoodColors _colors;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final options = widget.settingsService.moodOptions;
    _controllers = List<TextEditingController>.generate(
      SettingsService.moodOptionCount,
      (index) => TextEditingController(text: options[index]),
    );
    _emojis = Listenable.merge(_controllers);
    _colors = DiaryMoodColors.decode(widget.settingsService.moodColorsRaw);
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final nextOptions = _controllers
        .map((controller) => controller.text.trim())
        .toList(growable: false);
    setState(() => _saving = true);
    try {
      await widget.settingsService.setMoodOptions(nextOptions);
      await widget.settingsService.setMoodColorsRaw(_colors.encode());
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      await HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(
          content: Text(
            context.l10n.settingsMoodOptionsSaveFailed(error.toString()),
          ),
        ),
      );
    }
  }

  void _reset() {
    setState(() {
      for (var index = 0; index < _controllers.length; index += 1) {
        _controllers[index].text = SettingsService.defaultMoodOptions[index];
      }
      _colors = DiaryMoodColors.defaults;
    });
  }

  /// 换槽位 [slot]（1–10）的颜色：只选一个颜色，两种明暗下的用色都由心情色板
  /// 推出；取消时不改动。
  Future<void> _pickColor(int slot) async {
    final result = await showStyleColorDialog(
      context,
      title: context.l10n.settingsMoodOptionsColorLabel(slot.toString()),
      light: _colors.colorOf(slot),
      dark: null,
      role: DiaryCardColorRole.accent,
      showDarkVariant: false,
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() => _colors = _colors.withColor(slot, result.light));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AppPageBackground(
      area: AppBackgroundArea.settings,
      child: Builder(
        builder: (BuildContext context) => Scaffold(
          backgroundColor: AppPageBackdrop.pageColorOf(context),
          appBar: AppTopBar(
            contentMaxWidth: FormWidth.maxWidth,
            leading: IconButton(
              tooltip: l10n.commonBack,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
            ),
            title: Text(l10n.settingsMoodOptionsTitle),
            actions: <Widget>[
              TextButton(
                onPressed: _saving ? null : _reset,
                child: Text(l10n.commonReset),
              ),
              TextButton(
                onPressed: _saving ? null : _save,
                child: Text(l10n.commonSave),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final side = FormWidth.gutter(constraints.maxWidth);
              return ListView(
                padding: EdgeInsets.fromLTRB(side, 12, side, 24),
                children: <Widget>[
                  ListenableBuilder(
                    listenable: _emojis,
                    builder: (BuildContext context, Widget? child) =>
                        MoodPaletteStrip(
                          moods: <String>[
                            for (var i = 0; i < _controllers.length; i += 1)
                              _controllers[i].text.trim().isEmpty
                                  ? SettingsService.defaultMoodOptions[i]
                                  : _controllers[i].text.trim(),
                          ],
                          colors: <Color>[
                            for (
                              var slot = 1;
                              slot <= _controllers.length;
                              slot += 1
                            )
                              Color(_colors.colorOf(slot)),
                          ],
                        ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
                    child: Text(
                      l10n.settingsMoodOptionsColorsHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  for (
                    var index = 0;
                    index < _controllers.length;
                    index += 1
                  ) ...<Widget>[
                    MoodOptionRow(
                      controller: _controllers[index],
                      index: index,
                      color: Color(_colors.colorOf(index + 1)),
                      enabled: !_saving,
                      onPickColor: () => _pickColor(index + 1),
                    ),
                    if (index != _controllers.length - 1)
                      const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
