import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import '../logic/task_delta.dart';
import '../widgets/task_delta_widget.dart';
import '../logic/task_repository.dart';
import '../logic/l10n_extension.dart';

class TaskHistoryScreen extends StatelessWidget {
  const TaskHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final taskRepository = Provider.of<TaskRepository?>(context);

    return ValueListenableBuilder<DateTime?>(
      valueListenable: AppClock.timeNotifier,
      builder: (context, mockTime, _) {
        final isMocked = mockTime != null;

        return Padding(
          padding: EdgeInsets.only(
            bottom: isMocked ? 60.0 : 0.0,
          ), // Avoid overlap with dev clock banner
          child: taskRepository == null
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  key: const PageStorageKey('historyView'),
                  slivers: [_buildHistorySliver(taskRepository)],
                ),
        );
      },
    );
  }

  Widget _buildHistorySliver(TaskRepository taskRepository) {
    return StreamBuilder<List<TaskDelta>>(
      stream: taskRepository.getHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n?.noHistoryYet ?? 'No history yet',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final history = snapshot.data!;
        return SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TaskDeltaWidget(delta: history[index]),
                ),
              ),
            );
          }, childCount: history.length),
        );
      },
    );
  }
}
