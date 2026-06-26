import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/auth_repository.dart';
import '../widgets/dev_clock_widget.dart';
import '../widgets/home_search_and_shortcut_widget.dart';
import '../logic/app_route_manager.dart';
import 'create_task_screen.dart';
import 'task_list_screen.dart';
import 'task_schedule_screen.dart';
import 'settings_screen.dart';
import 'family_screen.dart';
import 'sprint_dashboard_screen.dart';
import 'help_screen.dart';
import '../logic/l10n_extension.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final Uri? mockUri;
  const HomeScreen({super.key, this.mockUri});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  late final AppRouteManager _routeManager;

  @override
  void initState() {
    super.initState();
    _routeManager = AppRouteManager(mockUri: widget.mockUri);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeManager.handleUrlParameters(
        context: context,
        ref: ref,
        onIndexChanged: (index) {
          if (mounted) {
            setState(() {
              _currentIndex = index;
            });
          }
        },
        currentIndex: _currentIndex,
      );
    });
  }

  Future<void> _addNewTask() async {
    SystemNavigator.routeInformationUpdated(uri: Uri.parse('/new'));
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CreateTaskScreen(defaultToRepeating: _currentIndex == 1),
      ),
    );
    _routeManager.updateUrlPath(_currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return HomeSearchAndShortcutWidget(
      currentIndex: _currentIndex,
      builder: (context, isSearching, appBar) {
        final mainContent = Scaffold(
          appBar: appBar,
          drawer: _buildDrawer(context),
          body: _currentIndex == 0
              ? const TaskListScreen()
              : _currentIndex == 1
              ? const TaskScheduleScreen()
              : const FamilyScreen(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _currentIndex = index;
              });
              _routeManager.updateUrlPath(index);
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
                icon: const Icon(Icons.people_outline),
                selectedIcon: const Icon(Icons.people),
                label: context.l10n.familyTab,
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
        );

        return Stack(
          children: [mainContent, const DevClockWidget(bottomOffset: 80.0)],
        );
      },
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
            key: const Key('drawer_sprint_dashboard_tile'),
            leading: const Icon(Icons.dashboard_customize),
            title: Text(context.l10n.sprintDashboardTitle),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SprintDashboardScreen(),
                ),
              );
            },
          ),
          ListTile(
            key: const Key('drawer_settings_tile'),
            leading: const Icon(Icons.settings),
            title: Text(context.l10n.settingsTitle),
            onTap: () {
              Navigator.pop(context); // Close drawer
              SystemNavigator.routeInformationUpdated(
                uri: Uri.parse('/settings'),
              );
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) {
                _routeManager.updateUrlPath(_currentIndex);
              });
            },
          ),
          ListTile(
            key: const Key('drawer_help_tile'),
            leading: const Icon(Icons.help_outline),
            title: Text(context.l10n.helpTitle),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpScreen()),
              );
            },
          ),
          ListTile(
            key: const Key('drawer_logout_tile'),
            leading: const Icon(Icons.logout),
            title: Text(context.l10n.logout),
            onTap: () async {
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
    );
  }
}
