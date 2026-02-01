import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/auth_repository.dart';
import '../logic/task.dart';
import '../widgets/fun_check_button.dart';
import 'create_task_screen.dart';
import '../widgets/task_display.dart';
import '../logic/task_repository.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  Future<void> _addNewTask() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateTaskScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskRepository = Provider.of<TaskRepository?>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Nothing Ever Happens')),
      drawer: Drawer(
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
      ),
      body: taskRepository == null
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<Task>>(
              stream: taskRepository.getTasks(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final tasks = snapshot.data ?? [];

                if (tasks.isEmpty) {
                  return const Center(child: Text('No tasks yet. Add one!'));
                }

                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Card(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: tasks.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) =>
                          _buildTaskItem(tasks[index]),
                    ),
                  ),
                );
              },
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
