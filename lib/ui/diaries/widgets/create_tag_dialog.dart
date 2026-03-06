import 'package:flutter/material.dart';

/// 弹窗创建标签时的临时数据对象。
class NewTagDraft {
  const NewTagDraft({required this.name, required this.color});

  final String name;
  final int color;
}

/// 展示“新建标签”弹窗并返回输入结果。
///
/// - 返回 `null` 表示取消
/// - 返回 `NewTagDraft` 表示输入合法可提交
Future<NewTagDraft?> showCreateTagDialog(BuildContext context) async {
  final nameController = TextEditingController();
  final colorController = TextEditingController(text: '#4CAF50');

  final result = await showDialog<NewTagDraft>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        // 允许在软键盘弹出时内容滚动，避免溢出。
        scrollable: true,
        title: const Text('新建标签'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: nameController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '标签名'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: colorController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '颜色(HEX，如 #4CAF50)',
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                return;
              }
              final parsedColor = _parseHexColor(colorController.text);
              if (parsedColor == null) {
                return;
              }
              Navigator.of(
                dialogContext,
              ).pop(NewTagDraft(name: name, color: parsedColor));
            },
            child: const Text('创建'),
          ),
        ],
      );
    },
  );

  nameController.dispose();
  colorController.dispose();
  return result;
}

/// 将用户输入的 HEX 颜色字符串解析为 ARGB int。
///
/// 支持：
/// - `#RRGGBB`（自动补 `FF` alpha）
/// - `#AARRGGBB`
int? _parseHexColor(String raw) {
  final normalized = raw.trim().replaceFirst('#', '');
  if (normalized.length != 6 && normalized.length != 8) {
    return null;
  }

  final withAlpha = normalized.length == 6 ? 'FF$normalized' : normalized;
  return int.tryParse(withAlpha, radix: 16);
}
