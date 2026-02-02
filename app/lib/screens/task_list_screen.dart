import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/auth_repository.dart';
import '../logic/task.dart';
import '../logic/task_delta.dart';
import '../widgets/fun_check_button.dart';
import '../widgets/task_delta_widget.dart';
import 'create_task_screen.dart';
import '../widgets/task_display.dart';
import '../logic/task_repository.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final Key _taskListKey = const ValueKey('taskList');

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
      drawer: _buildDrawer(context),
      body: taskRepository == null
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              center: _taskListKey,
              slivers: [
                _buildHistorySliver(taskRepository),
                _buildTaskListSliver(taskRepository),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewTask,
        tooltip: 'Add Task',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
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
    );
  }

  Widget _buildHistorySliver(TaskRepository taskRepository) {
    return StreamBuilder<List<TaskDelta>>(
      stream: taskRepository.getHistory(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
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
                color: Theme.of(context).colorScheme.surfaceVariant,
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

  Widget _buildTaskListSliver(TaskRepository taskRepository) {
    return SliverToBoxAdapter(
      key: _taskListKey,
      child: StreamBuilder<List<Task>>(
        stream: taskRepository.getTasks(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            // Keep it minimal to avoid shifting too much, effectively just a placeholder
            return const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final tasks = snapshot.data ?? [];

          if (tasks.isEmpty) {
            return const SizedBox(
              height: 200,
              child: Center(child: Text('No tasks yet. Add one!')),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: ListView.separated(
                physics:
                    const NeverScrollableScrollPhysics(), // Let the CustomScrollView handle scrolling
                shrinkWrap: true,
                itemCount: tasks.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) => _buildTaskItem(tasks[index]),
              ),
            ),
          );
        },
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
