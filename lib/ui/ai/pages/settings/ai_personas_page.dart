// 设置 → AI 助手 → 人设：各用途的默认人设、内置人设（可复制、隐藏）与
// 我的人设（新建、编辑、删除可撤销）。写入只经 `updateAiPreferences`。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../app_surface/widgets/app_glass_field.dart';
import '../../../home/widgets/home_hint_visibility_scope.dart';
import '../../../settings/widgets/settings_card_group.dart';
import '../../../widgets/app_modal/app_modal_bottom_sheet.dart';
import '../../../widgets/expressive_menu/expressive_menu_button.dart';
import '../../../widgets/expressive_menu/expressive_menu_item.dart';
import '../../models/ai_built_ins.dart';
import '../../models/ai_preference_parts.dart';
import '../../models/ai_preferences.dart';
import '../../providers/ai_providers.dart';
import '../../viewmodels/ai_labels.dart';
import '../../widgets/ai_page_scaffold.dart';
import '../../widgets/ai_persona_avatar.dart';
import 'ai_persona_edit_page.dart';

class AiPersonasPage extends ConsumerWidget {
  const AiPersonasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final prefs = ref.watch(aiPreferencesProvider);
    final builtIns = aiPersonas(
      l10n,
      prefs,
      includeHidden: true,
    ).where((persona) => persona.builtIn).toList();

    Future<void> openEditor({AiPersona? persona, AiPersonaInfo? copyOf}) {
      return Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              AiPersonaEditPage(persona: persona, copyOf: copyOf),
        ),
      );
    }

    Future<void> delete(AiPersona persona) async {
      final before = ref.read(aiPreferencesProvider);
      await updateAiPreferences(
        ref,
        (p) => p.copyWith(
          personas: [
            for (final item in p.personas)
              if (item.id != persona.id) item,
          ],
          personaFor: {
            for (final entry in p.personaFor.entries)
              if (entry.value != persona.id) entry.key: entry.value,
          },
        ),
      );
      if (!context.mounted) return;
      await HomeHintVisibilityScope.showTrackedSnackBar(
        context: context,
        snackBar: SnackBar(
          persist: false,
          content: Text(l10n.aiCommonDeleted(persona.name)),
          action: SnackBarAction(
            label: l10n.commonUndo,
            onPressed: () => updateAiPreferences(
              ref,
              (p) => p.copyWith(
                personas: before.personas,
                personaFor: before.personaFor,
              ),
            ),
          ),
        ),
      );
    }

    return AiPageScaffold(
      title: l10n.aiPersonasTitle,
      children: <Widget>[
        SettingsCardGroup(
          title: l10n.aiPersonasDefaultsGroup,
          children: <Widget>[
            for (final use in AiPersonaUse.values)
              Builder(
                builder: (BuildContext context) {
                  final current = aiPersonaFor(l10n, prefs, use);
                  return AiNavTile(
                    icon: FontAwesomeIcons.userPen,
                    title: aiPersonaUseLabel(l10n, use),
                    subtitle: '${current.emoji} ${current.name}',
                    onTap: () async {
                      final picked = await showAiPersonaPicker(
                        context,
                        personas: aiPersonas(l10n, prefs),
                        selectedId: current.id,
                        title: aiPersonaUseLabel(l10n, use),
                      );
                      if (picked == null) return;
                      await updateAiPreferences(
                        ref,
                        (p) => p.copyWith(
                          personaFor: {...p.personaFor, use: picked},
                        ),
                      );
                    },
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          title: l10n.aiPersonasBuiltInGroup,
          children: <Widget>[
            for (final persona in builtIns)
              _PersonaTile(
                persona: persona,
                hidden: prefs.hiddenPersonas.contains(persona.id),
                menu: <Widget>[
                  ExpressiveMenuItem(
                    leadingIcon: const FaIcon(FontAwesomeIcons.copy),
                    onPressed: () => openEditor(copyOf: persona),
                    child: Text(l10n.aiPersonaDuplicate),
                  ),
                  ExpressiveMenuItem(
                    leadingIcon: FaIcon(
                      prefs.hiddenPersonas.contains(persona.id)
                          ? FontAwesomeIcons.eye
                          : FontAwesomeIcons.eyeSlash,
                    ),
                    onPressed: () => updateAiPreferences(ref, (p) {
                      final hidden = {...p.hiddenPersonas};
                      hidden.contains(persona.id)
                          ? hidden.remove(persona.id)
                          : hidden.add(persona.id);
                      return p.copyWith(hiddenPersonas: hidden);
                    }),
                    child: Text(
                      prefs.hiddenPersonas.contains(persona.id)
                          ? l10n.aiCommonShow
                          : l10n.aiCommonHide,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsCardGroup(
          title: l10n.aiPersonasMineGroup,
          children: <Widget>[
            if (prefs.personas.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  l10n.aiPersonasMineEmpty,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
            for (final persona in prefs.personas)
              _PersonaTile(
                persona: AiPersonaInfo(
                  id: persona.id,
                  name: persona.name,
                  emoji: persona.emoji,
                  prompt: persona.prompt,
                ),
                onTap: () => openEditor(persona: persona),
                menu: <Widget>[
                  ExpressiveMenuItem(
                    leadingIcon: const FaIcon(FontAwesomeIcons.pen),
                    onPressed: () => openEditor(persona: persona),
                    child: Text(l10n.commonEdit),
                  ),
                  ExpressiveMenuItem(
                    leadingIcon: const FaIcon(FontAwesomeIcons.trashCan),
                    destructive: true,
                    onPressed: () => delete(persona),
                    child: Text(l10n.commonDelete),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FilledButton.tonalIcon(
                  style: AppGlassField.tonalButtonStyle(context),
                  onPressed: prefs.personas.length >= AiPreferences.maxPersonas
                      ? null
                      : () => openEditor(),
                  icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
                  label: Text(
                    prefs.personas.length >= AiPreferences.maxPersonas
                        ? l10n.aiPersonaLimit(AiPreferences.maxPersonas)
                        : l10n.aiPersonaAdd,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PersonaTile extends StatelessWidget {
  const _PersonaTile({
    required this.persona,
    required this.menu,
    this.hidden = false,
    this.onTap,
  });

  final AiPersonaInfo persona;
  final List<Widget> menu;
  final bool hidden;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 4),
      titleAlignment: ListTileTitleAlignment.center,
      leading: AiPersonaAvatar(emoji: persona.emoji),
      title: Row(
        children: <Widget>[
          Flexible(
            child: Text(
              persona.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hidden) ...<Widget>[
            const SizedBox(width: 8),
            AiBadge(l10n.aiCommonHidden),
          ],
        ],
      ),
      subtitle: Text(
        persona.description.isNotEmpty ? persona.description : persona.prompt,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: ExpressiveMenuButton(
        tooltip: persona.name,
        icon: FaIcon(
          FontAwesomeIcons.ellipsisVertical,
          size: 16,
          color: colors.onSurfaceVariant,
        ),
        items: menu,
      ),
      onTap: onTap,
    );
  }
}

/// 选一个人设（只负责挑选，返回人设 id）。
Future<String?> showAiPersonaPicker(
  BuildContext context, {
  required List<AiPersonaInfo> personas,
  required String? selectedId,
  required String title,
}) {
  return showAppModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (BuildContext sheetContext) {
      final theme = Theme.of(sheetContext);
      final colors = theme.colorScheme;
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final persona in personas)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                titleAlignment: ListTileTitleAlignment.center,
                leading: AiPersonaAvatar(emoji: persona.emoji),
                title: Text(persona.name),
                subtitle: persona.description.isEmpty
                    ? null
                    : Text(persona.description),
                trailing: persona.id == selectedId
                    ? FaIcon(
                        FontAwesomeIcons.check,
                        size: 14,
                        color: colors.primary,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(persona.id),
              ),
          ],
        ),
      );
    },
  );
}
