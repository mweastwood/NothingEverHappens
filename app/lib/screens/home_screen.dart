import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../logic/auth_repository.dart';
import '../widgets/home_search_and_shortcut_widget.dart';
import '../logic/app_route_manager.dart';
import 'create_task_screen.dart';
import 'task_list_screen.dart';
import 'task_schedule_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'subscription_screen.dart';
import 'family_screen.dart';
import 'help_screen.dart';
import 'recipes/recipe_list_screen.dart';
import '../logic/l10n_extension.dart';
import '../logic/utils/app_version.dart';
import '../logic/utils/layout_breakpoints.dart';

final homeTabIndexProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerStatefulWidget {
  final Uri? mockUri;
  const HomeScreen({super.key, this.mockUri});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late final AppRouteManager _routeManager;

  @override
  void initState() {
    super.initState();
    _routeManager = AppRouteManager(mockUri: widget.mockUri);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _routeManager.handleUrlParameters(
        context: context,
        ref: ref,
        onIndexChanged: (index) {
          ref.read(homeTabIndexProvider.notifier).state = index;
        },
        currentIndex: ref.read(homeTabIndexProvider),
      );
    });
  }

  Future<void> _addNewTask() async {
    final currentIndex = ref.read(homeTabIndexProvider);
    SystemNavigator.routeInformationUpdated(uri: Uri.parse('/new'));
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CreateTaskScreen(defaultToRepeating: currentIndex == 1),
      ),
    );
    _routeManager.updateUrlPath(currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(homeTabIndexProvider);
    final isWide = isWideScreen(context);

    final activeScreen = currentIndex == 0
        ? const TaskListScreen()
        : currentIndex == 1
        ? const TaskScheduleScreen()
        : currentIndex == 2
        ? const DashboardScreen()
        : const FamilyScreen();

    return HomeSearchAndShortcutWidget(
      currentIndex: currentIndex,
      builder: (context, isSearching, appBar) {
        final mainContent = Scaffold(
          appBar: appBar,
          drawer: _buildDrawer(context),
          body: isWide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: currentIndex,
                      onDestinationSelected: (int index) {
                        ref.read(homeTabIndexProvider.notifier).state = index;
                        _routeManager.updateUrlPath(index);
                      },
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        NavigationRailDestination(
                          icon: const Icon(Icons.list_outlined),
                          selectedIcon: const Icon(Icons.list),
                          label: Text(context.l10n.tasksTab),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.calendar_month_outlined),
                          selectedIcon: const Icon(Icons.calendar_month),
                          label: Text(context.l10n.scheduleTab),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.dashboard_outlined),
                          selectedIcon: const Icon(Icons.dashboard),
                          label: Text(context.l10n.dashboardTab),
                        ),
                        NavigationRailDestination(
                          icon: const Icon(Icons.people_outline),
                          selectedIcon: const Icon(Icons.people),
                          label: Text(context.l10n.familyTab),
                        ),
                      ],
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                    Expanded(child: activeScreen),
                  ],
                )
              : activeScreen,
          bottomNavigationBar: isWide
              ? null
              : NavigationBar(
                  selectedIndex: currentIndex,
                  onDestinationSelected: (int index) {
                    ref.read(homeTabIndexProvider.notifier).state = index;
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
                      icon: const Icon(Icons.dashboard_outlined),
                      selectedIcon: const Icon(Icons.dashboard),
                      label: context.l10n.dashboardTab,
                    ),
                    NavigationDestination(
                      icon: const Icon(Icons.people_outline),
                      selectedIcon: const Icon(Icons.people),
                      label: context.l10n.familyTab,
                    ),
                  ],
                ),
          floatingActionButton: (currentIndex == 0 || currentIndex == 1)
              ? FloatingActionButton(
                  onPressed: _addNewTask,
                  tooltip: context.l10n.addTaskTooltip,
                  child: const Icon(Icons.add),
                )
              : null,
        );

        return mainContent;
      },
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final currentIndex = ref.read(homeTabIndexProvider);
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
            key: const Key('drawer_recipes_tile'),
            leading: const Icon(Icons.restaurant_menu),
            title: const Text('Recipes'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecipeListScreen(),
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
                _routeManager.updateUrlPath(currentIndex);
              });
            },
          ),
          ListTile(
            key: const Key('drawer_subscription_tile'),
            leading: const Icon(Icons.star_outline),
            title: const Text('Subscriptions'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              SystemNavigator.routeInformationUpdated(
                uri: Uri.parse('/subscriptions'),
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SubscriptionScreen(),
                ),
              ).then((_) {
                _routeManager.updateUrlPath(currentIndex);
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
          const Divider(),
          ListTile(
            key: const Key('drawer_version_tile'),
            leading: const Icon(Icons.info_outline),
            title: Text(AppVersion.display),
            enabled: false,
          ),
        ],
      ),
    );
  }
}
