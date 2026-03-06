import 'package:flutter/material.dart';
import 'package:node_diary/ui/calendar/pages/calendar_page.dart';
import 'package:node_diary/ui/diaries/pages/edit_diary_page.dart';
import 'package:node_diary/ui/diaries/pages/diaries_page.dart';
import 'package:node_diary/ui/settings/pages/settings_page.dart';

/// 主框架页：承载底部三栏导航（列表/日历/设置）。
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// 当前选中的底部导航索引。
  int _index = 0;

  static const _titles = <String>['日记列表', '日历', '设置'];

  /// 从列表页进入“新建日记”编辑流程。
  Future<void> _openCreateDiary() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const EditDiaryPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      // 使用 IndexedStack 保留各 tab 状态，切换时不销毁页面。
      body: IndexedStack(
        index: _index,
        children: const <Widget>[DiariesPage(), CalendarPage(), SettingsPage()],
      ),
      floatingActionButton:
          _index == 0
              ? FloatingActionButton.extended(
                onPressed: _openCreateDiary,
                icon: const Icon(Icons.add),
                label: const Text('新建'),
              )
              : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) {
          setState(() {
            _index = value;
          });
        },
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.article_outlined),
            selectedIcon: Icon(Icons.article),
            label: '列表',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '日历',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
