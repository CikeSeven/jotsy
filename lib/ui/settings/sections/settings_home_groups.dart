// 设置首页的五个分组（DESIGN.md §5.3）：通用、写日记、整理、数据与安全，
// 以及末尾不带标题的 AI 助手与关于。每组一张 `SettingsCardGroup`，组内是
// `SettingsNavTile` 导航行，具体设置都在各自的二级页里。
//
// 输入：功能开关（`appFeaturesProvider`、`aiFeatureEnabledProvider`）决定
// 日记模板、日记本、AI 助手三行是否出现；`settingsServiceProvider` 就绪后
// 心情符号行才能打开编辑页；`appUpdateControllerProvider` 决定关于行的
// “新版本”标记。
// 输出：只有页面跳转，不写任何设置。
//
// 有条件的行直接从分组的 children 里省掉（分组按项数插分割线，放空占位会
// 多出一条）；这些都是无状态的导航行，分组按位置复用子项也不会串状态。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/core/services/settings_service.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../core/services/app_platform.dart';
import '../../../core/services/app_service.dart';
import '../../ai/pages/settings/ai_settings_page.dart';
import '../../ai/providers/ai_providers.dart';
import '../../diaries/pages/diary_drafts_page.dart';
import '../../diary_templates/models/built_in/diary_template_built_ins.dart';
import '../../diary_templates/pages/diary_templates_page.dart';
import '../../diary_templates/providers/diary_template_providers.dart';
import '../../notebooks/pages/notebooks_page.dart';
import '../controllers/app_update_controller.dart';
import '../pages/about_page.dart';
import '../pages/app_features_page.dart';
import '../pages/appearance_page.dart';
import '../pages/data_management_page.dart';
import '../pages/editor_settings_page.dart';
import '../pages/mood_options_page.dart';
import '../pages/recycle_bin_page.dart';
import '../pages/tag_management_page.dart';
import '../providers/app_features_provider.dart';
import '../widgets/app_update_badge.dart';
import '../widgets/settings_card_group.dart';
import '../widgets/settings_nav_tile.dart';
import 'settings_app_lock_tile.dart';
import 'settings_language_tile.dart';
import 'settings_lan_sync_tile.dart';

void _push(BuildContext context, Widget page) {
  Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (BuildContext context) => page));
}

/// 通用：外观、语言、功能管理。
class SettingsGeneralGroup extends StatelessWidget {
  const SettingsGeneralGroup({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsCardGroup(
      title: l10n.settingsGroupGeneral,
      children: <Widget>[
        SettingsNavTile(
          icon: FontAwesomeIcons.palette,
          title: l10n.settingsAppearance,
          subtitle: l10n.settingsAppearanceSubtitle,
          onTap: () => _push(context, const AppearancePage()),
        ),
        const SettingsLanguageTile(),
        SettingsNavTile(
          icon: FontAwesomeIcons.toggleOn,
          title: l10n.settingsFeaturesTitle,
          subtitle: l10n.settingsFeaturesSubtitle,
          onTap: () => _push(context, const AppFeaturesPage()),
        ),
      ],
    );
  }
}

/// 写日记：编辑器、日记模板（模板功能开启时）、草稿箱。
class SettingsWritingGroup extends ConsumerWidget {
  const SettingsWritingGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final templatesEnabled = ref.watch(
      appFeaturesProvider.select((features) => features.templates),
    );
    return SettingsCardGroup(
      title: l10n.settingsGroupWriting,
      children: <Widget>[
        SettingsNavTile(
          icon: FontAwesomeIcons.penNib,
          title: l10n.settingsEditor,
          subtitle: l10n.settingsEditorSubtitle,
          onTap: () => _push(context, const EditorSettingsPage()),
        ),
        if (templatesEnabled) const _DiaryTemplatesTile(),
        SettingsNavTile(
          icon: FontAwesomeIcons.filePen,
          title: l10n.diaryDraftsTitle,
          onTap: () => _push(context, const DiaryDraftsPage()),
        ),
      ],
    );
  }
}

/// 整理：标签管理、心情符号、日记本（日记本功能开启时）、回收站。
class SettingsOrganizeGroup extends ConsumerWidget {
  const SettingsOrganizeGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final notebooksEnabled = ref.watch(
      appFeaturesProvider.select((features) => features.notebooks),
    );
    return SettingsCardGroup(
      title: l10n.settingsGroupOrganize,
      children: <Widget>[
        SettingsNavTile(
          icon: FontAwesomeIcons.tags,
          title: l10n.settingsTagManagement,
          onTap: () => _push(context, const TagManagementPage()),
        ),
        const _MoodOptionsTile(),
        if (notebooksEnabled)
          SettingsNavTile(
            icon: FontAwesomeIcons.book,
            title: l10n.notebookTitle,
            onTap: () => _push(context, const NotebooksPage()),
          ),
        SettingsNavTile(
          icon: FontAwesomeIcons.trashCan,
          title: l10n.settingsRecycleBin,
          onTap: () => _push(context, const RecycleBinPage()),
        ),
      ],
    );
  }
}

/// 数据与安全：数据管理、局域网同步（iOS 不支持，见
/// `AppPlatform.supportsLanSync`）、应用锁与密码。
class SettingsDataSecurityGroup extends StatelessWidget {
  const SettingsDataSecurityGroup({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SettingsCardGroup(
      title: l10n.settingsGroupDataSecurity,
      children: <Widget>[
        SettingsNavTile(
          icon: FontAwesomeIcons.database,
          title: l10n.settingsDataManagement,
          subtitle: l10n.settingsDataManagementSubtitle,
          onTap: () => _push(context, const DataManagementPage()),
        ),
        if (AppPlatform.supportsLanSync) const SettingsLanSyncTile(),
        const SettingsAppLockTile(),
      ],
    );
  }
}

/// 末尾不带标题的一组：AI 助手（功能管理里开启后才出现）与关于。
class SettingsMoreGroup extends ConsumerWidget {
  const SettingsMoreGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final aiEnabled = ref.watch(aiFeatureEnabledProvider);
    // 有新版本时在“关于”行尾提示（自动检查或手动检查发现的）。
    final hasUpdate = ref.watch(
      appUpdateControllerProvider.select((state) => state.hasUpdate),
    );
    return SettingsCardGroup(
      children: <Widget>[
        if (aiEnabled)
          SettingsNavTile(
            icon: FontAwesomeIcons.wandMagicSparkles,
            title: l10n.aiSettingsTitle,
            subtitle: l10n.aiSettingsEntrySubtitle,
            onTap: () => _push(context, const AiSettingsPage()),
          ),
        SettingsNavTile(
          icon: FontAwesomeIcons.circleInfo,
          title: l10n.settingsAbout,
          badge: hasUpdate ? const AppUpdateBadge() : null,
          onTap: () => _push(context, const AboutPage()),
        ),
      ],
    );
  }
}

/// “日记模板”行：副标题写内置与我的模板各有几个。我的模板读一次性快照
/// （管理页写入后会让它失效），设置页不挂数据库的实时查询。
class _DiaryTemplatesTile extends ConsumerWidget {
  const _DiaryTemplatesTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mine = ref.watch(userDiaryTemplatesSnapshotProvider).asData?.value;
    return SettingsNavTile(
      icon: FontAwesomeIcons.layerGroup,
      title: l10n.diaryTemplatesTitle,
      subtitle: l10n.diaryTemplatesSettingsSubtitle(
        buildBuiltInDiaryTemplates(l10n).length,
        mine?.length ?? 0,
      ),
      onTap: () => _push(context, const DiaryTemplatesPage()),
    );
  }
}

/// “心情符号”行：副标题是当前 10 个心情的符号。编辑页要拿设置服务，未就绪
/// 时行照常显示、点了没有反应。
class _MoodOptionsTile extends ConsumerWidget {
  const _MoodOptionsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsServiceProvider).asData?.value;
    if (settings == null) {
      return SettingsNavTile(
        icon: FontAwesomeIcons.faceSmile,
        title: l10n.settingsMoodOptionsTitle,
        onTap: null,
      );
    }
    return ValueListenableBuilder<String?>(
      valueListenable: settings.moodOptionsRawNotifier,
      builder: (BuildContext context, String? raw, Widget? child) {
        return SettingsNavTile(
          icon: FontAwesomeIcons.faceSmile,
          title: l10n.settingsMoodOptionsTitle,
          subtitle: SettingsService.decodeMoodOptions(raw).join(' '),
          onTap: () =>
              _push(context, MoodOptionsPage(settingsService: settings)),
        );
      },
    );
  }
}
