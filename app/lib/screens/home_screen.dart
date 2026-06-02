import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/auth_repository.dart';
import '../widgets/dev_clock_widget.dart';
import 'create_task_screen.dart';
import 'task_list_screen.dart';
import 'task_schedule_screen.dart';
import 'task_history_screen.dart';
import 'settings_screen.dart';
import '../logic/l10n_extension.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  Future<void> _addNewTask() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateTaskScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: Text(context.l10n.appName)),
          drawer: _buildDrawer(context),
          body: _currentIndex == 0
              ? const TaskListScreen()
              : _currentIndex == 1
              ? const TaskScheduleScreen()
              : const TaskHistoryScreen(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _currentIndex = index;
              });
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.list_outlined),
                selectedIcon: const Icon(Icons.list),
                label: context.l10n.tasksTab,
              ),
              NavigationDestination(
                icon: const Icon(Icons.calendar_month_outlined),
                selectedIcon: const Icon(Icons.calendar_month),
                label: context.l10n.scheduleTab,
              ),
              NavigationDestination(
                icon: const Icon(Icons.history_outlined),
                selectedIcon: const Icon(Icons.history),
                label: context.l10n.historyTab,
              ),
            ],
          ),
          floatingActionButton: (_currentIndex == 0 || _currentIndex == 1)
              ? FloatingActionButton(
                  onPressed: _addNewTask,
                  tooltip: context.l10n.addTaskTooltip,
                  child: const Icon(Icons.add),
                )
              : null,
        ),
        const DevClockWidget(bottomOffset: 80.0),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                context.l10n.menu,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          ListTile(
            key: const Key('drawer_settings_tile'),
            leading: const Icon(Icons.settings),
            title: Text(context.l10n.settingsTitle),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
          ListTile(
            key: const Key('drawer_logout_tile'),
            leading: const Icon(Icons.logout),
            title: Text(context.l10n.logout),
            onTap: () async {
              await context.read<AuthRepository>().signOut();
            },
          ),
        ],
      ),
    );
  }
}
