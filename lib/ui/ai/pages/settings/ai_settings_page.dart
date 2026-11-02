// 设置 → AI 助手（只在功能管理里打开 AI 助手后出现）。
//
// 输入：本机配置（服务商、路由）、AI 偏好、用量。
// 输出 / 副作用：各开关与选择即时写入偏好（`updateAiPreferences`）；服务商、
// 路由在各自的下一级页面里改。没有可用模型时顶部状态卡引导添加服务商。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_page_backdrop.dart';
import '../../../settings/widgets/settings_card_group.dart';
import '../../../settings/widgets/settings_option_tiles.dart';
import '../../../settings/widgets/settings_reveal.dart';
import '../../../widgets/expressive_button_group.dart';
import '../../models/ai_preference_parts.dart';
import '../../providers/ai_providers.dart';
import '../../sections/settings/ai_modules_group.dart';
import '../../sections/settings/ai_status_card.dart';
import '../../widgets/ai_page_scaffold.dart';
import 'ai_actions_page.dart';
import 'ai_model_routing_page.dart';
import 'ai_personas_page.dart';
import 'ai_privacy_page.dart';
import 'ai_profile_page.dart';
import 'ai_providers_page.dart';
import 'ai_usage_page.dart';

class AiSettingsPage extends ConsumerWidget {
  const AiSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final config = ref.watch(aiLocalConfigProvider);
    final prefs = ref.watch(aiPreferencesProvider);

    void push(Widget page) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (BuildContext context) => page),
      );
    }

    return AiPageScaffold(
      title: l10n.aiSettingsTitle,
      children: <Widget>[
        const AiStatusCard(),
        const SizedBox(height: 20),
        SettingsCardGroup(
          title: l10n.aiGroupService,
          children: <Widget>[
            AiNavTile(
              icon: FontAwesomeIcons.server,
              title: l10n.aiProvidersTitle,
              subtitle: config.providers.isEmpty
                  ? l10n.aiProvidersEmpty
                  : l10n.aiProvidersCount(config.providers.length),
              onTap: () => push(const AiProvidersPage()),
            ),
            AiNavTile(
              icon: FontAwesomeIcons.shuffle,
              title: l10n.aiRoutingTitle,
              subtitle: l10n.aiRoutingSubtitle,
              onTap: () => push(const AiModelRoutingPage()),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const AiModulesGroup(),
        const SizedBox(height: 16),
        SettingsCardGroup(
          title: l10n.aiGroupPersonal,
          children: <Widget>[
            AiNavTile(
              icon: FontAwesomeIcons.masksTheater,
              title: l10n.aiPersonasTitle,
              subtitle: l10n.aiPersonasSubtitle,
              onTap: () => push(const AiPersonasPage()),
            ),
            AiNavTile(
              icon: FontAwesomeIcons.penNib,
              title: l10n.aiActionsTitle,
              subtitle: l10n.aiActionsSubtitle,
              onTap: () => push(const AiActionsPage()),
            ),
            AiNavTile(
              icon: FontAwesomeIcons.idCard,
              title: l10n.aiProfileTitle,
              subtitle: l10n.aiProfileSubtitle,
              onTap: () => push(const AiProfilePage()),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SettingsChoiceTile(
                  title: l10n.aiOutputLanguage,
                  child: ExpressiveButtonGroup<AiOutputLanguage>(
                    minSegmentWidth: 80,
                    segments: <ButtonSegment<AiOutputLanguage>>[
                      ButtonSegment(
                        value: AiOutputLanguage.followDiary,
                        label: Text(l10n.aiLanguageFollowDiary),
                      ),
                      ButtonSegment(
                        value: AiOutputLanguage.followApp,
                        label: Text(l10n.aiLanguageFollowApp),
                      ),
                      ButtonSegment(
                        value: AiOutputLanguage.custom,
                        label: Text(l10n.aiLanguageCustom),
                      ),
                    ],
                    selected: {prefs.language},
                    onSelectionChanged: (Set<AiOutputLanguage> value) =>
                        updateAiPreferences(
                          ref,
                          (p) => p.copyWith(language: value.single),
                        ),
                  ),
                ),
                SettingsReveal(
                  visible: prefs.language == AiOutputLanguage.custom,
                  child: _CustomLanguageField(initial: prefs.customLanguage),
                ),
              ],
            ),
            SettingsChoiceTile(
              title: l10n.aiResponseLength,
              child: ExpressiveButtonGroup<AiResponseLength>(
                minSegmentWidth: 72,
                segments: <ButtonSegment<AiResponseLength>>[
                  ButtonSegment(
                    value: AiResponseLength.short,
                    label: Text(l10n.aiLengthShort),
                  ),
                  ButtonSegment(
                    value: AiResponseLength.medium,
                    label: Text(l10n.aiLengthMedium),
                  ),
                  ButtonSegment(
                    value: AiResponseLength.long,
                    label: Text(l10n.aiLengthLong),
                  ),
                ],
                selected: {prefs.length},
                onSelectionChanged: (Set<AiResponseLength> value) =>
                    updateAiPreferences(
                      ref,
                      (p) => p.copyWith(length: value.single),
                    ),
              ),
            ),
            SettingsChoiceTile(
              title: l10n.aiCreativity,
              subtitle: l10n.aiCreativitySubtitle,
              child: ExpressiveButtonGroup<AiCreativity>(
                minSegmentWidth: 72,
                segments: <ButtonSegment<AiCreativity>>[
                  ButtonSegment(
                    value: AiCreativity.precise,
                    label: Text(l10n.aiCreativityPrecise),
                  ),
                  ButtonSegment(
                    value: AiCreativity.balanced,
                    label: Text(l10n.aiCreativityBalanced),
                  ),
                  ButtonSegment(
                    value: AiCreativity.creative,
                    label: Text(l10n.aiCreativityCreative),
                  ),
                ],
                selected: {prefs.creativity},
                onSelectionChanged: (Set<AiCreativity> value) =>
                    updateAiPreferences(
                      ref,
                      (p) => p.copyWith(creativity: value.single),
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          title: l10n.aiGroupPrivacy,
          children: <Widget>[
            AiNavTile(
              icon: FontAwesomeIcons.userShield,
              title: l10n.aiPrivacyTitle,
              subtitle: l10n.aiPrivacySubtitle,
              onTap: () => push(const AiPrivacyPage()),
            ),
            AiNavTile(
              icon: FontAwesomeIcons.chartColumn,
              title: l10n.aiUsageTitle,
              subtitle: l10n.aiUsageSubtitle,
              onTap: () => push(const AiUsagePage()),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
          child: Text(
            l10n.aiSettingsFooter,
            style: AppPageBackdrop.onBackgroundTextStyle(
              context,
              theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 指定回答语言的输入框：随输入写入偏好（单个短字符串，写入很轻）。
class _CustomLanguageField extends ConsumerStatefulWidget {
  const _CustomLanguageField({required this.initial});

  final String initial;

  @override
  ConsumerState<_CustomLanguageField> createState() =>
      _CustomLanguageFieldState();
}

class _CustomLanguageFieldState extends ConsumerState<_CustomLanguageField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SettingsSwitchTile.nestedIndent,
        0,
        16,
        16,
      ),
      child: TextField(
        controller: _controller,
        maxLength: 40,
        decoration: InputDecoration(
          hintText: context.l10n.aiLanguageCustomHint,
          counterText: '',
        ),
        onChanged: (String value) => updateAiPreferences(
          ref,
          (p) => p.copyWith(customLanguage: value.trim()),
        ),
      ),
    );
  }
}
