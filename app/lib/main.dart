import 'package:flutter/material.dart';
import 'task.dart';
import 'civil_day.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nothing Ever Happens',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const TaskScreen(),
    );
  }
}

class TaskScreen extends StatelessWidget {
  const TaskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Fake data
    final tasks = [
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nothing Ever Happens'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.builder(
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          final task = tasks[index];
          return ListTile(
            title: SelectableText(task.title),
            subtitle: SelectableText(task.description),
          );
        },
      ),
    );
  }
}
