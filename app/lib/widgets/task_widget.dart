import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../logic/task.dart';
import '../logic/task_repository.dart';
import '../screens/create_task_screen.dart';
import 'fun_check_button.dart';

class TaskWidget extends StatefulWidget {
  final Task task;

  const TaskWidget({super.key, required this.task});

  @override
  State<TaskWidget> createState() => _TaskWidgetState();
}

class _TaskWidgetState extends State<TaskWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleYAnimation;
  late Animation<double> _scaleXAnimation;
  late Animation<double> _sizeFactorAnimation;
  late Animation<double> _contentOpacityAnimation;
  bool _isChecking = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    // Layout Collapse: 1.0 -> 0.0 over the FULL 200ms
    _sizeFactorAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));

    // Fade content out in the first 25% (50ms)
    _contentOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    // Visual Phase 1: Collapse Vertically (Height squish) - first 50%
    _scaleYAnimation = Tween<double>(begin: 1.0, end: 0.1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    // Visual Phase 2: Collapse Horizontally (Width) - last 50%
    _scaleXAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_isDeleting) {
          context.read<TaskRepository>().deleteTask(widget.task.id);
        } else {
          context.read<TaskRepository>().completeTask(widget.task.id);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCompletion() {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    // Wait for fun check animation (confetti) to finish (500ms)
    // The confetti lasts ~500ms.
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Task?'),
          content: Text(
            'Are you sure you want to delete "${widget.task.title}"? This action will permanently remove the task.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('confirm_delete_button'),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                setState(() {
                  _isDeleting = true;
                });
                _controller.forward();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Visual Transformation (Squish/Shrink) affects the whole Card
        final transformedChild = Transform(
          alignment: Alignment.topCenter,
          transform: Matrix4.diagonal3Values(
            _scaleXAnimation.value,
            _scaleYAnimation.value,
            1.0,
          ),
          child: Card(
            child: Opacity(
              opacity: _contentOpacityAnimation.value,
              child: child,
            ),
          ),
        );

        // Layout Transformation (Slide-up)
        return SizeTransition(
          sizeFactor: _sizeFactorAnimation,
          axis: Axis.vertical,
          alignment: Alignment.topCenter,
          child: transformedChild,
        );
      },
      child: ListTile(
        leading: FunCheckButton(
          value: _isChecking,
          onChanged: (value) {
            if (value && !_isChecking) {
              _handleCompletion();
            }
          },
        ),
        title: Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: SelectableText(
            widget.task.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        subtitle: MarkdownBody(data: widget.task.description, selectable: true),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: const Key('edit_pencil_button'),
              icon: const Icon(Icons.edit, size: 20),
              tooltip: 'Edit Task',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        CreateTaskScreen(taskToEdit: widget.task),
                  ),
                );
              },
            ),
            IconButton(
              key: const Key('delete_task_button'),
              icon: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
                size: 20,
              ),
              tooltip: 'Delete Task',
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ),
    );
  }
}
