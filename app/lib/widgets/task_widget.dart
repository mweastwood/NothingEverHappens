import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../logic/task.dart';
import '../logic/task_repository.dart';
import '../logic/auth_repository.dart';
import '../screens/create_task_screen.dart';
import 'fun_check_button.dart';
import 'fun_delete_button.dart';

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

  static final Map<String, String> _userNameCache = {};
  String? _assigneeName;
  bool _isLoadingAssignee = false;

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

    _loadAssigneeName();
  }

  @override
  void didUpdateWidget(TaskWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.task.assignedUserId != oldWidget.task.assignedUserId) {
      _loadAssigneeName();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadAssigneeName() async {
    final assigneeId = widget.task.assignedUserId;
    if (assigneeId == null) {
      setState(() {
        _assigneeName = null;
      });
      return;
    }

    if (_userNameCache.containsKey(assigneeId)) {
      setState(() {
        _assigneeName = _userNameCache[assigneeId];
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingAssignee = true;
      });
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(assigneeId).get();
      final name = doc.data()?['displayName'] as String? ?? doc.data()?['email'] as String? ?? 'User';
      _userNameCache[assigneeId] = name;
      if (mounted) {
        setState(() {
          _assigneeName = name;
          _isLoadingAssignee = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _assigneeName = 'User';
          _isLoadingAssignee = false;
        });
      }
    }
  }

  void _handleCompletion() {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    // Wait for fun check animation (confetti) to finish (500ms)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  void _handleDeletion() {
    if (_isDeleting) return;

    setState(() {
      _isDeleting = true;
    });

    // Wait for poof animation to finish (400ms) before starting collapse
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h${minutes > 0 ? ' ${minutes}m' : ''}';
    }
    return '${minutes}m';
  }

  String _getScheduleLabel(TaskSchedule schedule) {
    if (schedule is OneOffSchedule) return 'One-off';
    if (schedule is DailySchedule) return 'Daily';
    if (schedule is WeeklySchedule) return 'Weekly';
    if (schedule is MonthlySchedule) return 'Monthly';
    if (schedule is YearlySchedule) return 'Yearly';
    return 'Recurring';
  }

  IconData _getScheduleIcon(TaskSchedule schedule) {
    if (schedule is OneOffSchedule) return Icons.today;
    if (schedule is DailySchedule) return Icons.repeat;
    if (schedule is WeeklySchedule) return Icons.view_week;
    if (schedule is MonthlySchedule) return Icons.calendar_month;
    if (schedule is YearlySchedule) return Icons.event;
    return Icons.settings_backup_restore;
  }

  String _getPriorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return 'High';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.low:
        return 'Low';
    }
  }

  Color _getPriorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.low:
        return Colors.blueGrey;
    }
  }

  IconData _getPriorityIcon(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.high:
        return Icons.warning_amber_rounded;
      case TaskPriority.medium:
        return Icons.info_outline;
      case TaskPriority.low:
        return Icons.arrow_downward;
    }
  }

  String _getMissedPolicyLabel(MissedPolicy policy) {
    switch (policy) {
      case MissedPolicy.rollover:
        return 'Rollover';
      case MissedPolicy.skip:
        return 'Skip';
      case MissedPolicy.shift:
        return 'Shift';
      case MissedPolicy.stack:
        return 'Stack';
    }
  }

  Widget _buildBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.4 : 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeBackground(
    BuildContext context, {
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        alignment: alignment,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: alignment == Alignment.centerLeft
                ? [color.withOpacity(0.25), color.withOpacity(0.02)]
                : [color.withOpacity(0.02), color.withOpacity(0.25)],
            begin: alignment == Alignment.centerLeft ? Alignment.centerLeft : Alignment.centerRight,
            end: alignment == Alignment.centerLeft ? Alignment.centerRight : Alignment.centerLeft,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: alignment == Alignment.centerLeft
              ? [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ]
              : [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, color: color, size: 24),
                ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(widget.task.id),
      background: _buildSwipeBackground(
        context,
        alignment: Alignment.centerLeft,
        color: Theme.of(context).colorScheme.error,
        icon: Icons.close,
        label: "Dismiss",
      ),
      secondaryBackground: _buildSwipeBackground(
        context,
        alignment: Alignment.centerRight,
        color: Theme.of(context).colorScheme.primary,
        icon: Icons.check,
        label: "Complete",
      ),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          context.read<TaskRepository>().deleteTask(widget.task.id);
        } else {
          context.read<TaskRepository>().completeTask(widget.task.id);
        }
      },
      child: AnimatedBuilder(
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
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.task.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                MarkdownBody(data: widget.task.description, selectable: true),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6.0,
                runSpacing: 6.0,
                children: [
                  // Scope (Family vs Personal)
                  _buildBadge(
                    context,
                    icon: widget.task.isFamily ? Icons.people_alt : Icons.person,
                    label: widget.task.isFamily ? 'Family' : 'Personal',
                    color: widget.task.isFamily ? Colors.deepPurple : Colors.teal,
                  ),
                  // Priority
                  _buildBadge(
                    context,
                    icon: _getPriorityIcon(widget.task.priority),
                    label: _getPriorityLabel(widget.task.priority),
                    color: _getPriorityColor(widget.task.priority),
                  ),
                  // Schedule
                  _buildBadge(
                    context,
                    icon: _getScheduleIcon(widget.task.schedule),
                    label: _getScheduleLabel(widget.task.schedule),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  // Effort/Duration (if any)
                  if (widget.task.estimatedDuration != null)
                    _buildBadge(
                      context,
                      icon: Icons.timer_outlined,
                      label: _formatDuration(widget.task.estimatedDuration!),
                      color: Colors.blue,
                    ),
                  // Missed Policy (if recurring)
                  if (widget.task.schedule is! OneOffSchedule)
                    _buildBadge(
                      context,
                      icon: Icons.refresh,
                      label: 'Policy: ${_getMissedPolicyLabel(widget.task.missedPolicy)}',
                      color: Colors.blueGrey,
                    ),
                  // Assignee (if family & assigned)
                  if (widget.task.isFamily && widget.task.assignedUserId != null)
                    _buildBadge(
                      context,
                      icon: Icons.assignment_ind,
                      label: _isLoadingAssignee
                          ? 'Loading...'
                          : (_assigneeName != null ? 'Assigned: $_assigneeName' : 'Assigned'),
                      color: Colors.amber[800] ?? Colors.amber,
                    ),
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.task.schedule is OneOffSchedule) ...[
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
                const SizedBox(width: 8),
              ],
              FunDeleteButton(
                key: const Key('delete_task_button'),
                onTap: _handleDeletion,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
