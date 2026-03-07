import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';


/// 笔记列表空状态组件。
///
/// 当当前列表没有可显示笔记时，给出简洁空态和“创建笔记”入口。
class DiariesEmptyState extends StatelessWidget {
  const DiariesEmptyState({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.square_pencil,
            size: 38,
            color: color.secondary,
          ),
          const SizedBox(height: 12),
          Text("还有日记"),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(CupertinoIcons.add),
            label: Text('新家日记'),
          ),
        ],
      ),
    );
  }
}
