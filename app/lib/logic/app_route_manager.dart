import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'task_schedule.dart';
import 'task_repository.dart';
import '../screens/settings_screen.dart';
import '../screens/create_task_screen.dart';

class AppRouteManager {
  final Uri? mockUri;

  AppRouteManager({this.mockUri});

  void updateUrlPath(int index) {
    if (!kIsWeb) return;
    String path;
    switch (index) {
      case 0:
        path = '/tasks';
        break;
      case 1:
        path = '/schedules';
        break;
      case 2:
        path = '/dashboard';
        break;
      case 3:
        path = '/family';
        break;
      default:
        return;
    }
    SystemNavigator.routeInformationUpdated(
      uri: Uri.parse(path),
      replace: true,
    );
  }

  void openEditScreen({
    required BuildContext context,
    required WidgetRef ref,
    required String scheduleId,
    required ValueChanged<int> onIndexChanged,
  }) {
    onIndexChanged(1);
    updateUrlPath(1);

    final taskRepo = ref.read(taskRepositoryProvider);
    if (taskRepo == null) return;

    taskRepo
        .getTasks()
        .first
        .then((tasks) {
          if (!context.mounted) return;
          final task = tasks.cast<TaskSchedule?>().firstWhere(
            (t) => t?.id == scheduleId,
            orElse: () => null,
          );

          if (task != null) {
            SystemNavigator.routeInformationUpdated(
              uri: Uri.parse('/edit/$scheduleId'),
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreateTaskScreen(taskToEdit: task),
              ),
            ).then((_) {
              if (!context.mounted) return;
              updateUrlPath(1);
            });
          }
        })
        .catchError((_) {});
  }

  void handleUrlParameters({
    required BuildContext context,
    required WidgetRef ref,
    required ValueChanged<int> onIndexChanged,
    required int currentIndex,
  }) {
    final uri = mockUri ?? Uri.base;

    String path = uri.path;
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }

    final routes = <String, VoidCallback>{
      'tasks': () {
        onIndexChanged(0);
        updateUrlPath(0);
      },
      'schedules': () {
        onIndexChanged(1);
        updateUrlPath(1);
      },
      'dashboard': () {
        onIndexChanged(2);
        updateUrlPath(2);
      },
      'family': () {
        onIndexChanged(3);
        updateUrlPath(3);
      },
      'settings': () {
        onIndexChanged(0);
        updateUrlPath(0);
        SystemNavigator.routeInformationUpdated(uri: Uri.parse('/settings'));
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SettingsScreen()),
        ).then((_) {
          if (!context.mounted) return;
          updateUrlPath(currentIndex);
        });
      },
      'new': () {
        final repeatingParam = uri.queryParameters['repeating'];
        final defaultToRepeating = repeatingParam == 'true';
        SystemNavigator.routeInformationUpdated(uri: Uri.parse('/new'));
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CreateTaskScreen(defaultToRepeating: defaultToRepeating),
          ),
        ).then((_) {
          if (!context.mounted) return;
          updateUrlPath(currentIndex);
        });
      },
    };

    final handler = routes[path];
    if (handler != null) {
      handler();
    } else if (path.startsWith('edit/')) {
      final scheduleId = path.substring('edit/'.length);
      openEditScreen(
        context: context,
        ref: ref,
        scheduleId: scheduleId,
        onIndexChanged: onIndexChanged,
      );
    } else if (path.isEmpty) {
      onIndexChanged(0);
      updateUrlPath(0);
    }
  }
}
