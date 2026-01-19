import 'package:flutter/material.dart';
import '../logic/task.dart';
import '../widgets/fun_check_button.dart';
import '../logic/civil_day.dart';
import 'create_task_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  // Fake data
  final List<Task> _tasks = [
    Task(
      id: '1',
      title: 'Buy groceries',
      description: 'Milk, Eggs, Bread',
      startFromMidnight: const Duration(hours: 9),
      dueFromMidnight: const Duration(hours: 18),
      schedule: DailySchedule(
        startDate: CivilDay(year: 2024, month: 1, day: 1),
        interval: 1,
      ),
    ),
    Task(
      id: '2',
      title: 'Walk the dog',
      description: 'Take Fido to the park',
      startFromMidnight: const Duration(hours: 7),
      dueFromMidnight: const Duration(hours: 8),
      schedule: DailySchedule(
        startDate: CivilDay(year: 2024, month: 1, day: 1),
        interval: 1,
      ),
    ),
    Task(
      id: '3',
      title: 'Weekly meeting',
      description: 'Discuss project status',
      startFromMidnight: const Duration(hours: 10),
      dueFromMidnight: const Duration(hours: 11),
      schedule: WeeklySchedule(
        startDate: CivilDay(year: 2024, month: 1, day: 1),
        interval: 1,
        daysOfWeek: {1}, // Monday
      ),
    ),
  ];

  Future<void> _addNewTask() async {
    final newTask = await Navigator.push<Task>(
      context,
      MaterialPageRoute(builder: (context) => const CreateTaskScreen()),
    );

    if (newTask != null) {
      setState(() {
        _tasks.add(newTask);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nothing Ever Happens')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                return ListView.separated(
                  shrinkWrap: true,
                  itemCount: _tasks.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _buildTaskItem(_tasks[index]),
                );
              } else {
                return GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    childAspectRatio: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _tasks.length,
                  padding: const EdgeInsets.all(8),
                  itemBuilder: (context, index) =>
                      _buildTaskItem(_tasks[index]),
                );
              }
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewTask,
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    return ListTile(
      leading: FunCheckButton(value: false, onChanged: (value) {}),
      title: SelectableText(task.title),
      subtitle: SelectableText(task.description),
    );
  }
}
