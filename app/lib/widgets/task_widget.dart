import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../logic/task_schedule.dart';
import '../logic/task_repository.dart';
import '../screens/create_task_screen.dart';
import 'fun_check_button.dart';
import 'fun_delete_button.dart';

import '../logic/task_instance.dart';

class TaskWidget extends ConsumerStatefulWidget {
  final TaskInstance instance;
  final TaskSchedule? schedule;
  final bool showEditOption;

  const TaskWidget({
    super.key,
    required this.instance,
    this.schedule,
    this.showEditOption = true,
  });

  @override
  ConsumerState<TaskWidget> createState() => _TaskWidgetState();
}

class _TaskWidgetState extends ConsumerState<TaskWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleYAnimation;
  late Animation<double> _scaleXAnimation;
  late Animation<double> _sizeFactorAnimation;
  late Animation<double> _contentOpacityAnimation;
  static final Map<String, String> _userNameCache = {};
  String? _assigneeName;
  bool _isLoadingAssignee = false;
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
        if (!mounted) return;
        if (_isDeleting) {
          ref
              .read(taskRepositoryProvider)!
              .deleteTask(widget.instance.scheduleId);
        } else {
          ref.read(taskRepositoryProvider)!.completeTask(widget.instance.id);
        }
      }
    });

    _loadAssigneeName();
  }

  @override
  void didUpdateWidget(TaskWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.instance.assignedUserId != oldWidget.instance.assignedUserId) {
      _loadAssigneeName();
    }
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

  Future<void> _loadAssigneeName() async {
    final assigneeId = widget.instance.assignedUserId;
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
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(assigneeId)
          .get();
      final name =
          doc.data()?['displayName'] as String? ??
          doc.data()?['email'] as String? ??
          'User';
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h${minutes > 0 ? ' ${minutes}m' : ''}';
    }
    return '${minutes}m';
  }

  String _getScheduleLabel(TaskScheduleRule schedule) {
    if (schedule is OneOffSchedule) return 'One-off';
    if (schedule is DailySchedule) return 'Daily';
    if (schedule is WeeklySchedule) return 'Weekly';
    if (schedule is MonthlySchedule) return 'Monthly';
    if (schedule is YearlySchedule) return 'Yearly';
    return 'Recurring';
  }

  IconData _getScheduleIcon(TaskScheduleRule schedule) {
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

  Color _getPriorityColor(BuildContext context, TaskPriority priority) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (priority) {
      case TaskPriority.high:
        return colorScheme.error;
      case TaskPriority.medium:
      case TaskPriority.low:
        return colorScheme.primary;
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
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.4 : 0.25),
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

  int _getRuleIndex(TaskInstance instance, TaskSchedule schedule) {
    if (schedule.schedules.length <= 1) return 0;
    final parts = instance.id.split('_');
    if (parts.length >= 3) {
      final idxPart = parts.last;
      final idx = int.tryParse(idxPart);
      if (idx != null && idx >= 0 && idx < schedule.schedules.length) {
        return idx;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final ruleIdx = widget.schedule != null
        ? _getRuleIndex(widget.instance, widget.schedule!)
        : 0;
    final schedule =
        widget.schedule != null && ruleIdx < widget.schedule!.schedules.length
        ? widget.schedule!.schedules[ruleIdx]
        : OneOffSchedule(
            date: widget.instance.scheduledDate,
            startRelativeTime: widget.instance.startRelativeTime,
            dueRelativeTime: widget.instance.dueRelativeTime,
            notificationRelativeTime: widget.instance.notificationRelativeTime,
          );

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
            widget.instance.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.instance.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              MarkdownBody(data: widget.instance.description, selectable: true),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children: [
                // Scope (Family vs Personal)
                _buildBadge(
                  context,
                  icon: widget.instance.isFamily
                      ? Icons.people_alt
                      : Icons.person,
                  label: widget.instance.isFamily ? 'Family' : 'Personal',
                  color: Theme.of(context).colorScheme.primary,
                ),
                // Priority
                _buildBadge(
                  context,
                  icon: _getPriorityIcon(widget.instance.priority),
                  label: _getPriorityLabel(widget.instance.priority),
                  color: _getPriorityColor(context, widget.instance.priority),
                ),
                // Schedule
                _buildBadge(
                  context,
                  icon: _getScheduleIcon(schedule),
                  label: _getScheduleLabel(schedule),
                  color: Theme.of(context).colorScheme.primary,
                ),
                // Effort/Duration (if any)
                if (widget.schedule?.estimatedDuration != null)
                  _buildBadge(
                    context,
                    icon: Icons.timer_outlined,
                    label: _formatDuration(widget.schedule!.estimatedDuration!),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                // Missed Policy (if recurring)
                if (schedule is! OneOffSchedule && widget.schedule != null)
                  _buildBadge(
                    context,
                    icon: Icons.refresh,
                    label:
                        'Policy: ${_getMissedPolicyLabel(widget.schedule!.missedPolicy)}',
                    color: Theme.of(context).colorScheme.primary,
                  ),
                // Assignee (if family & assigned)
                if (widget.instance.isFamily &&
                    widget.instance.assignedUserId != null)
                  _buildBadge(
                    context,
                    icon: Icons.assignment_ind,
                    label: _isLoadingAssignee
                        ? 'Loading...'
                        : (_assigneeName != null
                              ? 'Assigned: $_assigneeName'
                              : 'Assigned'),
                    color: Theme.of(context).colorScheme.primary,
                  ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showEditOption &&
                widget.schedule != null &&
                schedule is OneOffSchedule) ...[
              IconButton(
                key: const Key('edit_pencil_button'),
                icon: const Icon(Icons.edit, size: 20),
                tooltip: 'Edit TaskSchedule',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CreateTaskScreen(taskToEdit: widget.schedule!),
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
    );
  }
}
