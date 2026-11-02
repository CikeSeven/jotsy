import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../settings/widgets/settings_card_group.dart';
import '../../models/ai_preferences.dart';
import '../../providers/ai_providers.dart';
import '../../widgets/ai_page_scaffold.dart';

/// 设置 → AI 助手 → 关于我与文风。两段可选的说明随每次请求注入提示词；
/// 离开页面时写入（输入中不反复写偏好）。
class AiProfilePage extends ConsumerStatefulWidget {
  const AiProfilePage({super.key});

  @override
  ConsumerState<AiProfilePage> createState() => _AiProfilePageState();
}

class _AiProfilePageState extends ConsumerState<AiProfilePage> {
  late final TextEditingController _aboutMe;
  late final TextEditingController _style;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(aiPreferencesProvider);
    _aboutMe = TextEditingController(text: prefs.aboutMe);
    _style = TextEditingController(text: prefs.writingStyle);
  }

  @override
  void dispose() {
    _aboutMe.dispose();
    _style.dispose();
    super.dispose();
  }

  Future<bool> _commit() async {
    final aboutMe = _aboutMe.text.trim();
    final style = _style.text.trim();
    final prefs = ref.read(aiPreferencesProvider);
    if (aboutMe != prefs.aboutMe || style != prefs.writingStyle) {
      await updateAiPreferences(
        ref,
        (p) => p.copyWith(aboutMe: aboutMe, writingStyle: style),
      );
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AiPageScaffold(
      title: l10n.aiProfileTitle,
      onWillPopGuard: _commit,
      children: <Widget>[
        SettingsCardGroup(
          footer: l10n.aiProfileFooter,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextField(
                    controller: _aboutMe,
                    minLines: 4,
                    maxLines: 10,
                    maxLength: AiPreferences.maxAboutMeLength,
                    decoration: InputDecoration(
                      labelText: l10n.aiProfileAboutMe,
                      hintText: l10n.aiProfileAboutMeHint,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _style,
                    minLines: 3,
                    maxLines: 8,
                    maxLength: AiPreferences.maxWritingStyleLength,
                    decoration: InputDecoration(
                      labelText: l10n.aiProfileStyle,
                      hintText: l10n.aiProfileStyleHint,
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
