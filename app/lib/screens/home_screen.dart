import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/auth_repository.dart';
import '../widgets/dev_clock_widget.dart';
import 'create_task_screen.dart';
import 'task_list_screen.dart';
import 'task_schedule_screen.dart';
import 'task_history_screen.dart';

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
          appBar: AppBar(title: const Text('Nothing Ever Happens')),
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
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.list_outlined),
                selectedIcon: Icon(Icons.list),
                label: 'Tasks',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Schedule',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'History',
              ),
            ],
          ),
          floatingActionButton: (_currentIndex == 0 || _currentIndex == 1)
              ? FloatingActionButton(
                  onPressed: _addNewTask,
                  tooltip: 'Add Task',
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
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text('Menu'),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await context.read<AuthRepository>().signOut();
            },
          ),
        ],
      ),
    );
  }
}
