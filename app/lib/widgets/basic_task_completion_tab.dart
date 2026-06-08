import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../logic/task.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/task_repository.dart';
import '../logic/l10n_extension.dart';
import 'task_widget.dart';

const List<String> _taskTitles = [
  'Water the Houseplants',
  'Take out the Trash',
  'Wash the Dishes',
  'Mow the Lawn',
  'Feed the Dog',
  'Vacuum the Living Room',
  'Clean the Attic',
  'Fold the Laundry',
  'Dust the Shelves',
  'Buy Groceries',
];

const List<String> _taskDescriptions = [
  'Give them just enough water.',
  'Don\'t forget the recycling.',
  'Clean the pots and pans first.',
  'Trim the edges too.',
  'Make sure he has fresh water.',
  'Get under the couch.',
  'Sort the old boxes.',
  'Fold them neatly and put them away.',
  'Use a microfiber cloth.',
  'Milk, eggs, and bread.',
];

class BasicTaskCompletionTab extends StatefulWidget {
  const BasicTaskCompletionTab({super.key});

  @override
  State<BasicTaskCompletionTab> createState() => _BasicTaskCompletionTabState();
}

class _BasicTaskCompletionTabState extends State<BasicTaskCompletionTab> {
  late List<Task> _tasks;
  late FakeTaskRepository _fakeRepository;

  @override
  void initState() {
    super.initState();
    _reset();
    _fakeRepository = FakeTaskRepository(
      onComplete: _handleComplete,
      onDelete: _handleDelete,
    );
  }

  void _reset() {
    setState(() {
      _tasks = List.generate(10, (index) {
        final title = _taskTitles[index];
        final desc = _taskDescriptions[index];
        return Task(
          id: 'practice-task-$index',
          title: title,
          description: desc,
          startRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 9, minute: 0),
          ),
          dueRelativeTime: const RelativeTime(
            dayOffset: 0,
            time: TimeOfDay(hour: 17, minute: 0),
          ),
          schedule: OneOffSchedule(
            date: const CivilDay(year: 2026, month: 6, day: 4),
          ),
        );
      });
    });
  }

  void _handleComplete(String id) {
    if (!mounted) return;
    setState(() {
      _tasks.removeWhere((t) => t.id == id);
    });
  }

  void _handleDelete(String id) {
    if (!mounted) return;
    setState(() {
      _tasks.removeWhere((t) => t.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Provider<TaskRepository>.value(
        value: _fakeRepository,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Explanatory Card (Basic Mat Card)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: MarkdownBody(data: context.l10n.practiceHelpContent),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Practice Tasks (${_tasks.length} remaining)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset Practice'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_tasks.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.done_all,
                          size: 48,
                          color: Colors.green,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'All tasks completed or dismissed!',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          'Tap "Reset Practice" to try again.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._tasks.map((task) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TaskWidget(
                      key: ValueKey(task.id),
                      task: task,
                      showEditOption: false,
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class DummyFirebaseFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTaskRepository extends TaskRepository {
  final void Function(String) onComplete;
  final void Function(String) onDelete;

  FakeTaskRepository({required this.onComplete, required this.onDelete})
    : super(
        firestore: DummyFirebaseFirestore(),
        userId: 'practice_user',
        notificationService: null,
      );

  @override
  Future<void> completeTask(String id) async {
    onComplete(id);
  }

  @override
  Future<void> deleteTask(String id) async {
    onDelete(id);
  }
}
