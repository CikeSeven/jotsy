import 'package:flutter/material.dart';
import 'package:node_diary/ui/widgets/expressive_loading_indicator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/app_platform.dart';
import 'package:node_diary/core/services/diary_font_storage_service.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/diaries/providers/diary_typography_provider.dart';
import 'package:node_diary/ui/diaries/widgets/diary_font_choices.dart';
import 'package:node_diary/ui/diaries/widgets/diary_mobile_toolbar.dart';
import 'package:node_diary/ui/diaries/widgets/diary_typography_metrics_editor.dart';
import 'package:node_diary/ui/settings/pages/diary_toolbar_order_page.dart';
import 'package:node_diary/ui/settings/pages/diary_typography_page.dart';
import '../widgets/settings_card_group.dart';
import 'settings_code_block_style_tile.dart';
import 'settings_manual_save_switch.dart';
import 'settings_open_in_editor_switch.dart';
import 'settings_publish_on_leave_switch.dart';
import 'settings_toolbar_size_tile.dart';
import '../../ai/models/ai_preference_parts.dart';
import '../../ai/providers/ai_providers.dart';

/// 设置 → 编辑器设置的三组：「正文」（正文字体与排版、代码块样式）、
/// 「工具栏」（按钮排序、大小、始终显示）、「编辑行为」（打开日记时直接
/// 编辑、返回时直接发表新日记、手动保存修改、自动显示当天照片）。日记模板
/// 与心情符号在设置首页。
class SettingsEditorSection extends ConsumerWidget {
  const SettingsEditorSection({super.key, required this.settingsAsync});

  final AsyncValue<SettingsService> settingsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final aiWriting = ref.watch(aiModuleAvailableProvider(AiModule.writing));
    return settingsAsync.when(
      data: (settingsService) {
        return Column(
          children: <Widget>[
            SettingsCardGroup(
              title: l10n.settingsEditorBodyGroup,
              children: <Widget>[
                const _DiaryTypographyTile(),
                SettingsCodeBlockStyleTile(settingsService: settingsService),
              ],
            ),
            const SizedBox(height: 16),
            SettingsCardGroup(
              title: l10n.settingsEditorToolbarGroup,
              children: <Widget>[
                _ToolbarOrderTile(
                  settings: settingsService,
                  aiWriting: aiWriting,
                ),
                SettingsToolbarSizeTile(settings: settingsService),
                // 桌面没有软键盘，编辑页工具栏一直显示，这个开关没有意义。
                if (!AppPlatform.isDesktop)
                  _ToolbarAlwaysVisibleSwitch(settings: settingsService),
              ],
            ),
            const SizedBox(height: 16),
            SettingsCardGroup(
              title: l10n.settingsEditorBehaviorGroup,
              children: <Widget>[
                SettingsOpenInEditorSwitch(settingsService: settingsService),
                SettingsPublishOnLeaveSwitch(settingsService: settingsService),
                SettingsManualSaveSwitch(settingsService: settingsService),
                _DayPhotoSuggestionsSwitch(settings: settingsService),
              ],
            ),
          ],
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: ExpressiveLoadingIndicator(size: 32)),
      ),
      error: (Object error, StackTrace stackTrace) =>
          ListTile(title: Text(l10n.autoT0045(error.toString()))),
    );
  }
}

/// “工具栏按钮排序”入口：副标题列出当前前 4 个工具（隐藏的与本平台、本
/// 配置不提供的不算，如 Linux 的录音、没开 AI 写作时的 AI）。
class _ToolbarOrderTile extends StatelessWidget {
  const _ToolbarOrderTile({required this.settings, required this.aiWriting});

  final SettingsService settings;
  final bool aiWriting;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        settings.diaryToolbarOrderRawNotifier,
        settings.diaryToolbarHiddenItemsRawNotifier,
      ]),
      builder: (BuildContext context, Widget? child) {
        final order = decodeDiaryToolbarOrder(
          settings.diaryToolbarOrderRawNotifier.value,
        );
        final hiddenItems = decodeDiaryToolbarHiddenItems(
          settings.diaryToolbarHiddenItemsRawNotifier.value,
        );
        final enabledOrder = filterEnabledDiaryToolbarOrder(
          order,
          <DiaryToolbarItem>{
            ...hiddenItems,
            ...diaryToolbarUnavailableItems(ai: aiWriting),
          },
        );
        final preview = enabledOrder
            .take(4)
            .map((DiaryToolbarItem item) => item.label(l10n))
            .join(' · ');
        return ListTile(
          title: Text(l10n.autoT0043),
          subtitle: Text(l10n.autoT0044(preview.isEmpty ? '-' : preview)),
          trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) {
                  return DiaryToolbarOrderPage(
                    aiAvailable: aiWriting,
                    settingsService: settings,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// “正文字体与排版”入口：副标题概括当前字体、字号与行距。
class _DiaryTypographyTile extends ConsumerWidget {
  const _DiaryTypographyTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final typography = ref.watch(diaryTypographyProvider);
    final importedFonts =
        ref.watch(diaryImportedFontsProvider).asData?.value ??
        const <DiaryImportedFont>[];
    final options = diaryFontOptions(l10n, importedFonts);
    // 所选导入字体缺失时正文按内置字体显示，概括也如实显示内置字体。
    final fontLabel = options
        .firstWhere(
          (option) => option.id == typography.fontId,
          orElse: () => options.first,
        )
        .label;
    return ListTile(
      title: Text(l10n.diaryTypographyTitle),
      subtitle: Text(
        l10n.diaryTypographySummary(
          fontLabel,
          formatDiaryTypographyValue(typography.fontSize),
          formatDiaryTypographyValue(typography.lineHeight),
        ),
      ),
      trailing: const FaIcon(FontAwesomeIcons.angleRight, size: 14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const DiaryTypographyPage(),
        ),
      ),
    );
  }
}

/// “自动显示当天照片”开关：只决定补写日记（新建且日期早于今天）时标题下
/// 是否自动出现这天的照片提示条。关掉后编辑页右上角 ⋮ 菜单的“这天的照片”
/// 仍能打开同一个面板；那里也只在用户点“允许访问”时才申请相册权限。
class _DayPhotoSuggestionsSwitch extends StatelessWidget {
  const _DayPhotoSuggestionsSwitch({required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<bool>(
      valueListenable: settings.dayPhotoSuggestionsEnabledNotifier,
      builder: (BuildContext context, bool enabled, Widget? child) {
        return SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          value: enabled,
          title: Text(l10n.settingsDayPhotoSuggestions),
          subtitle: Text(l10n.settingsDayPhotoSuggestionsSubtitle),
          onChanged: settings.setDayPhotoSuggestionsEnabled,
        );
      },
    );
  }
}

/// “始终显示工具栏”开关：打开后编辑页（含模板编辑页）的悬浮工具栏不再随
/// 软键盘出现与消失，接实体键盘、不弹软键盘时也能用工具栏排版。
class _ToolbarAlwaysVisibleSwitch extends StatelessWidget {
  const _ToolbarAlwaysVisibleSwitch({required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<bool>(
      valueListenable: settings.diaryToolbarAlwaysVisibleNotifier,
      builder: (BuildContext context, bool enabled, Widget? child) {
        return SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          value: enabled,
          title: Text(l10n.settingsToolbarAlwaysVisible),
          subtitle: Text(l10n.settingsToolbarAlwaysVisibleSubtitle),
          onChanged: settings.setDiaryToolbarAlwaysVisible,
        );
      },
    );
  }
}
