import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/home/widgets/home_hint_visibility_scope.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

/// 心情符号自定义页。
///
/// 职责边界：
/// - 输入/输出固定 10 个心情槽位，顺序从低落到高兴；
/// - 保存到 SettingsService，供发布/编辑面板、日历聚合和探索趋势共用；
/// - 不负责历史日记迁移，历史默认符号仍由权重映射兼容。
class MoodOptionsPage extends StatefulWidget {
  const MoodOptionsPage({super.key, required this.settingsService});

  final SettingsService settingsService;

  @override
  State<MoodOptionsPage> createState() => _MoodOptionsPageState();
}

class _MoodOptionsPageState extends State<MoodOptionsPage> {
  late final List<TextEditingController> _controllers;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final options = widget.settingsService.moodOptions;
    _controllers = List<TextEditingController>.generate(
      SettingsService.moodOptionCount,
      (index) => TextEditingController(text: options[index]),
    );
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppTopBar(
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          for (
            var index = 0;
            index < _controllers.length;
            index += 1
          ) ...<Widget>[
            _MoodOptionField(
              controller: _controllers[index],
              index: index,
              enabled: !_saving,
            ),
            if (index != _controllers.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _MoodOptionField extends StatelessWidget {
  const _MoodOptionField({
    required this.controller,
    required this.index,
    required this.enabled,
  });

  final TextEditingController controller;
  final int index;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final label = l10n.settingsMoodOptionsSlotLabel((index + 1).toString());
    final defaultEmoji = SettingsService.defaultMoodOptions[index];
    return TextField(
      controller: controller,
      enabled: enabled,
      textAlign: TextAlign.center,
      maxLength: 8,
      style: Theme.of(context).textTheme.headlineSmall,
      decoration: InputDecoration(
        labelText: label,
        helperText: l10n.settingsMoodOptionsSlotHelper(defaultEmoji),
        counterText: '',
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.4),
        ),
      ),
    );
  }
}
