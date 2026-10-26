import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';
import 'package:node_diary/ui/settings/sections/settings_editor_section.dart';
import 'package:node_diary/ui/widgets/app_top_bar.dart';

import '../../../core/services/app_service.dart';
import '../../widgets/form_width.dart';

/// 设置-编辑器二级页。
class EditorSettingsPage extends ConsumerWidget {
  const EditorSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settingsAsync = ref.watch(settingsServiceProvider);
    return Scaffold(
      appBar: AppTopBar(
        contentMaxWidth: FormWidth.maxWidth,
        title: Text(l10n.settingsEditorTitle),
        leading: IconButton(
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const FaIcon(FontAwesomeIcons.angleLeft, size: 18),
        ),
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final side = FormWidth.extra(constraints.maxWidth);
          return ListView(
            padding: EdgeInsets.fromLTRB(side, 12, side, 24),
            children: <Widget>[
              SettingsEditorSection(settingsAsync: settingsAsync),
            ],
          );
        },
      ),
    );
  }
}
