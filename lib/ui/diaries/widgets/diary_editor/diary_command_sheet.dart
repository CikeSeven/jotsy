import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../l10n/app_localizations.dart';
import 'diary_block_commands.dart';

/// 手机软键盘的命令搜索使用真正的输入框；上游桌面菜单只监听硬件按键，
/// 不能接收手机 IME 的文字。选择和取消后由调用方恢复正文的原生选区。
class DiaryCommandSheet extends StatefulWidget {
  const DiaryCommandSheet({super.key, required this.commands});
  final List<DiaryBlockCommand> commands;
  @override
  State<DiaryCommandSheet> createState() => _DiaryCommandSheetState();
}

class _DiaryCommandSheetState extends State<DiaryCommandSheet> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final commands = widget.commands
        .where((command) => command.matches(_query))
        .toList();
    final available =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: available.clamp(160, 430),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Text(
                  l10n.diaryEditorSlashCommands,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  onSubmitted: (_) {
                    if (commands.isNotEmpty) {
                      Navigator.pop(context, commands.first);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: l10n.diaryEditorCommandHint,
                    prefixIcon: const Center(
                      widthFactor: 1,
                      child: FaIcon(FontAwesomeIcons.magnifyingGlass, size: 16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: commands.length,
                  itemBuilder: (context, index) => ListTile(
                    leading: FaIcon(
                      commands[index].icon,
                      size: 17,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(commands[index].label),
                    onTap: () => Navigator.pop(context, commands[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
