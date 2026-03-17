import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/sections/settings_editor_section.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

import '../../../core/services/app_service.dart';

/// 设置-编辑器二级页。
class EditorSettingsPage extends ConsumerWidget {
  const EditorSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settingsAsync = ref.watch(settingsServiceProvider);
    return Scaffold(
      appBar: AppTopBar(
        title: Text(l10n.settingsEditorTitle),
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
        children: <Widget>[SettingsEditorSection(settingsAsync: settingsAsync)],
      ),
    );
  }
}
