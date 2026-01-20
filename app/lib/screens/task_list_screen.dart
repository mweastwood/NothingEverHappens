import 'package:flutter/material.dart';
import '../logic/task.dart';
import '../widgets/fun_check_button.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import 'create_task_screen.dart';
import '../widgets/task_display.dart';

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
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 9, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 18, minute: 0),
      ),
      schedule: DailySchedule(
        startDate: CivilDay(year: 2024, month: 1, day: 1),
        interval: 1,
      ),
    ),
    Task(
      id: '2',
      title: 'Walk the dog',
      description: 'Take Fido to the park',
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 7, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 8, minute: 0),
      ),
      schedule: DailySchedule(
        startDate: CivilDay(year: 2024, month: 1, day: 1),
        interval: 1,
      ),
    ),
    Task(
      id: '3',
      title: 'Weekly meeting',
      description: 'Discuss project status',
      startRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 10, minute: 0),
      ),
      dueRelativeTime: const RelativeTime(
        dayOffset: 0,
        time: TimeOfDay(hour: 11, minute: 0),
      ),
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
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _tasks.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) => _buildTaskItem(_tasks[index]),
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
      title: TaskDisplay(title: task.title, description: task.description),
    );
  }
}
