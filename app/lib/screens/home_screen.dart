import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../logic/auth_repository.dart';
import '../widgets/dev_clock_widget.dart';
import 'create_task_screen.dart';
import 'task_list_screen.dart';
import 'task_schedule_screen.dart';
import 'settings_screen.dart';
import 'family_screen.dart';
import 'sprint_dashboard_screen.dart';
import 'help_screen.dart';
import '../logic/l10n_extension.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Future<void> _addNewTask() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            CreateTaskScreen(defaultToRepeating: _currentIndex == 1),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(taskSearchQueryProvider, (previous, next) {
      if (_currentIndex == 0 && _searchController.text != next) {
        _searchController.text = next;
      }
    });
    ref.listen<String>(scheduleSearchQueryProvider, (previous, next) {
      if (_currentIndex == 1 && _searchController.text != next) {
        _searchController.text = next;
      }
    });

    final mainContent = PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSearching) {
          setState(() {
            _isSearching = false;
            _searchController.clear();
            if (_currentIndex == 0) {
              ref.read(taskSearchQueryProvider.notifier).state = '';
            } else if (_currentIndex == 1) {
              ref.read(scheduleSearchQueryProvider.notifier).state = '';
            }
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: _isSearching
              ? TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: _currentIndex == 0
                        ? context.l10n.searchTasksPlaceholder
                        : context.l10n.searchSchedulesPlaceholder,
                    hintStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    if (_currentIndex == 0) {
                      ref.read(taskSearchQueryProvider.notifier).state = value;
                    } else if (_currentIndex == 1) {
                      ref.read(scheduleSearchQueryProvider.notifier).state =
                          value;
                    }
                  },
                )
              : Text(context.l10n.appName),
          leading: _isSearching
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchController.clear();
                      if (_currentIndex == 0) {
                        ref.read(taskSearchQueryProvider.notifier).state = '';
                      } else if (_currentIndex == 1) {
                        ref.read(scheduleSearchQueryProvider.notifier).state =
                            '';
                      }
                    });
                  },
                )
              : null,
          actions: [
            if (_isSearching)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  if (_currentIndex == 0) {
                    ref.read(taskSearchQueryProvider.notifier).state = '';
                  } else if (_currentIndex == 1) {
                    ref.read(scheduleSearchQueryProvider.notifier).state = '';
                  }
                  _searchFocusNode.requestFocus();
                },
              )
            else if (_currentIndex == 0 || _currentIndex == 1) ...[
              IconButton(
                icon: const Icon(Icons.help_outline),
                tooltip: context.l10n.helpTooltip,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          HelpScreen(initialIndex: _currentIndex == 0 ? 0 : 1),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  setState(() {
                    _isSearching = true;
                  });
                  _searchFocusNode.requestFocus();
                },
              ),
            ],
          ],
        ),
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
              if (_isSearching) {
                _isSearching = false;
                _searchController.clear();
                ref.read(taskSearchQueryProvider.notifier).state = '';
                ref.read(scheduleSearchQueryProvider.notifier).state = '';
              }
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
      ),
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.slash): () {
          final primaryFocus = FocusManager.instance.primaryFocus;
          final isEditableFocused =
              primaryFocus?.context?.widget is EditableText;
          if ((_currentIndex == 0 || _currentIndex == 1) &&
              !_isSearching &&
              !isEditableFocused) {
            setState(() {
              _isSearching = true;
            });
            _searchFocusNode.requestFocus();
          }
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_isSearching) {
            setState(() {
              _isSearching = false;
              _searchController.clear();
              if (_currentIndex == 0) {
                ref.read(taskSearchQueryProvider.notifier).state = '';
              } else if (_currentIndex == 1) {
                ref.read(scheduleSearchQueryProvider.notifier).state = '';
              }
            });
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [mainContent, const DevClockWidget(bottomOffset: 80.0)],
        ),
      ),
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
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
