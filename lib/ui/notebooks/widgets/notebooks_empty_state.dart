import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:node_diary/l10n/app_localizations.dart';

import '../../../app/theme/app_spacing.dart';
import '../../app_surface/widgets/app_glass_field.dart';
import '../../widgets/empty_hint.dart';

/// 还没有日记本时的空态：一句说明 + “新建日记本”。书架面板与管理页共用。
class NotebooksEmptyState extends StatelessWidget {
  const NotebooksEmptyState({super.key, required this.onCreate});

  final Future<void> Function() onCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        EmptyHint(icon: FontAwesomeIcons.book, message: l10n.notebookEmptyHint),
        const SizedBox(height: AppSpacing.l),
        FilledButton.tonalIcon(
          onPressed: () => unawaited(onCreate()),
          style: AppGlassField.tonalButtonStyle(context),
          icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
          label: Text(l10n.notebookNew),
        ),
      ],
    );
  }
}
