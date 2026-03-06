import 'package:flutter/material.dart';
import 'package:node_note/ui/calendar/pages/calendar_page.dart';
import 'package:node_note/ui/notes/pages/edit_note.dart';
import 'package:node_note/ui/notes/pages/notes_page.dart';
import 'package:node_note/ui/settings/pages/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  static const _titles = <String>['日记列表', '日历', '设置'];

  Future<void> _openCreateDiary() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const EditNotePage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(
        index: _index,
        children: const <Widget>[NotesPage(), CalendarPage(), SettingsPage()],
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
