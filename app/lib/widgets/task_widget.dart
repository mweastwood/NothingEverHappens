import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../logic/task.dart';
import '../logic/task_repository.dart';
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
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Phase 1: Collapse Vertically (Height) - first 50%
    _scaleYAnimation = Tween<double>(begin: 1.0, end: 0.02).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Phase 2: Collapse Horizontally (Width) - last 50%
    _scaleXAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        context.read<TaskRepository>().completeTask(widget.task.id);
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

    // Wait for fun check animation (confetti) to finish (~500ms)
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Apply transformations: Diagonal matrix to scale X and Y independently
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(
            _scaleXAnimation.value,
            _scaleYAnimation.value,
            1.0,
          ),
          child: child,
        );
      },
      child: Card(
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
          subtitle: MarkdownBody(
            data: widget.task.description,
            selectable: true,
          ),
        ),
      ),
    );
  }
}
