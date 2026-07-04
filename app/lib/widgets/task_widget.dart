import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../logic/task_schedule.dart';
import '../logic/task_repository.dart';
import '../screens/create_task_screen.dart';
import 'fun_check_button.dart';
import 'fun_delete_button.dart';

import '../logic/task_instance.dart';
import '../logic/l10n_extension.dart';
import '../logic/undo_notifier.dart';
import '../logic/app_clock.dart';
import 'undo_snackbar.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _isMouse = false;
  DismissDirection? _swipeDirection;
  double _swipeProgress = 0.0;

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

    _controller.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        final repo = ref.read(taskRepositoryProvider)!;
        final notifier = ref.read(undoNotifierProvider.notifier);
        final instance = widget.instance;
        // Capture context-sensitive values before any async gap.
        final messenger = ScaffoldMessenger.of(context);
        final dismissMsg = context.l10n.taskDismissed(instance.title);
        final completeMsg = context.l10n.taskCompleted(instance.title);
        final undoLabel = context.l10n.undoButton;
        final undoneLabel = context.l10n.taskRestored(instance.title);
        if (_isDeleting) {
          final resolved = await repo.dismissTaskInstance(instance.id);
          UndoSnackBar.showWithMessenger(
            messenger: messenger,
            notifier: notifier,
            action: UndoResolveTaskInstanceAction(
              message: dismissMsg,
              instance: resolved ?? instance,
            ),
            repository: repo,
            undoLabel: undoLabel,
            undoneLabel: undoneLabel,
          );
        } else {
          final resolved = await repo.completeTaskInstance(instance.id);
          UndoSnackBar.showWithMessenger(
            messenger: messenger,
            notifier: notifier,
            action: UndoResolveTaskInstanceAction(
              message: completeMsg,
              instance: resolved ?? instance,
            ),
            repository: repo,
            undoLabel: undoLabel,
            undoneLabel: undoneLabel,
          );
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

  String _getScheduleLabel(BuildContext context, TaskScheduleRule schedule) {
    final l10n = context.l10n;
    if (schedule is OneOffSchedule) return l10n.oneOffLabel;
    if (schedule is DailySchedule) return l10n.dailyLabel;
    if (schedule is WeeklySchedule) return l10n.weeklyLabel;
    if (schedule is MonthlySchedule) return l10n.monthlyLabel;
    if (schedule is YearlySchedule) return l10n.yearlyLabel;
    return l10n.recurringLabel;
  }

  IconData _getScheduleIcon(TaskScheduleRule schedule) {
    if (schedule is OneOffSchedule) return Icons.today;
    if (schedule is DailySchedule) return Icons.repeat;
    if (schedule is WeeklySchedule) return Icons.view_week;
    if (schedule is MonthlySchedule) return Icons.calendar_month;
    if (schedule is YearlySchedule) return Icons.event;
    return Icons.settings_backup_restore;
  }

  String _getPriorityLabel(BuildContext context, TaskPriority priority) {
    final l10n = context.l10n;
    switch (priority) {
      case TaskPriority.high:
        return l10n.priorityHigh;
      case TaskPriority.medium:
        return l10n.priorityMedium;
      case TaskPriority.low:
        return l10n.priorityLow;
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
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDueDateBadge(BuildContext context) {
    final now = AppClock.now;
    final dueDateTime = widget.instance.dueRelativeTime.referenceTo(
      widget.instance.scheduledDate,
    );
    final isOverdue = dueDateTime.isBefore(now);
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(
      dueDateTime.year,
      dueDateTime.month,
      dueDateTime.day,
    );

    Color color;
    if (isOverdue) {
      color = Theme.of(context).colorScheme.error;
    } else if (dueDay == today) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      color = isDark ? Colors.orange.shade300 : Colors.orange.shade800;
    } else {
      color = Theme.of(context).colorScheme.secondary;
    }

    return _buildBadge(
      context,
      icon: Icons.event,
      label: _formatDueDate(context, dueDateTime, now),
      color: color,
    );
  }

  String _formatDueDate(
    BuildContext context,
    DateTime dueDateTime,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final tomorrow = today.add(const Duration(days: 1));

    final dueDay = DateTime(
      dueDateTime.year,
      dueDateTime.month,
      dueDateTime.day,
    );
    final timeStr = TimeOfDay.fromDateTime(dueDateTime).format(context);
    final isOverdue = dueDateTime.isBefore(now);
    final l10n = context.l10n;

    if (dueDay == today) {
      return isOverdue
          ? l10n.overdueTodayAt(timeStr)
          : l10n.dueTodayAt(timeStr);
    } else if (dueDay == yesterday) {
      return l10n.overdueYesterdayAt(timeStr);
    } else if (dueDay == tomorrow) {
      return l10n.dueTomorrowAt(timeStr);
    } else {
      final locale = Localizations.localeOf(context).languageCode;
      final dateFormat = dueDateTime.year != now.year
          ? DateFormat.yMMMd(locale)
          : DateFormat.MMMd(locale);
      final dateStr = dateFormat.format(dueDateTime);
      if (isOverdue) {
        return l10n.overdueAt(dateStr, timeStr);
      } else {
        return l10n.dueAt(dateStr, timeStr);
      }
    }
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
            id: widget.instance.ruleId,
            scheduleId: widget.instance.scheduleId,
            date: widget.instance.scheduledDate,
            startRelativeTime: widget.instance.startRelativeTime,
            dueRelativeTime: widget.instance.dueRelativeTime,
            notificationRelativeTimes:
                widget.instance.notificationRelativeTimes,
          );

    final startDateTime = widget.instance.startRelativeTime.referenceTo(
      widget.instance.scheduledDate,
    );
    final isFuturePending = AppClock.now.isBefore(startDateTime);

    return Stack(
      children: [
        if (_swipeProgress > 0.0 && _swipeDirection != null)
          Positioned.fill(
            child: Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 4.0,
                vertical: 5.0,
              ),
              color: _swipeDirection == DismissDirection.startToEnd
                  ? Colors.green
                  : Theme.of(context).colorScheme.error,
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              child: Container(
                alignment: _swipeDirection == DismissDirection.startToEnd
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Icon(
                  _swipeDirection == DismissDirection.startToEnd
                      ? Icons.check
                      : Icons.delete,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        Dismissible(
          key: ValueKey(widget.instance.id),
          direction: _isMouse
              ? DismissDirection.none
              : DismissDirection.horizontal,
          onUpdate: (details) {
            setState(() {
              _swipeDirection = details.direction;
              _swipeProgress = details.progress;
            });
          },
          onDismissed: (direction) async {
            final repo = ref.read(taskRepositoryProvider)!;
            final notifier = ref.read(undoNotifierProvider.notifier);
            final instance = widget.instance;
            // Capture context-sensitive values before any async gap.
            final messenger = ScaffoldMessenger.of(context);
            final completeMsg = context.l10n.taskCompleted(instance.title);
            final dismissMsg = context.l10n.taskDismissed(instance.title);
            final undoLabel = context.l10n.undoButton;
            final undoneLabel = context.l10n.taskRestored(instance.title);
            if (direction == DismissDirection.startToEnd) {
              final resolved = await repo.completeTaskInstance(instance.id);
              UndoSnackBar.showWithMessenger(
                messenger: messenger,
                notifier: notifier,
                action: UndoResolveTaskInstanceAction(
                  message: completeMsg,
                  instance: resolved ?? instance,
                ),
                repository: repo,
                undoLabel: undoLabel,
                undoneLabel: undoneLabel,
              );
            } else if (direction == DismissDirection.endToStart) {
              final resolved = await repo.dismissTaskInstance(instance.id);
              UndoSnackBar.showWithMessenger(
                messenger: messenger,
                notifier: notifier,
                action: UndoResolveTaskInstanceAction(
                  message: dismissMsg,
                  instance: resolved ?? instance,
                ),
                repository: repo,
                undoLabel: undoLabel,
                undoneLabel: undoneLabel,
              );
            }
          },
          child: Listener(
            onPointerHover: (event) {
              if (event.kind == PointerDeviceKind.mouse && !_isMouse) {
                setState(() {
                  _isMouse = true;
                });
              }
            },
            onPointerDown: (event) {
              final isMouse = event.kind == PointerDeviceKind.mouse;
              if (isMouse != _isMouse) {
                setState(() {
                  _isMouse = isMouse;
                });
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
                onLongPress: _isMouse
                    ? null
                    : () async {
                        final textToCopy =
                            widget.instance.description.isNotEmpty
                            ? '${widget.instance.title}\n\n${widget.instance.description}'
                            : widget.instance.title;
                        await Clipboard.setData(
                          ClipboardData(text: textToCopy),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.copiedToClipboard),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
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
                  child: _isMouse
                      ? SelectableText(
                          widget.instance.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        )
                      : Text(
                          widget.instance.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.instance.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      MarkdownBody(
                        data: widget.instance.description,
                        selectable: _isMouse,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6.0,
                      runSpacing: 6.0,
                      children: [
                        // Due Date Badge
                        _buildDueDateBadge(context),
                        // Pending Badge
                        if (isFuturePending)
                          _buildBadge(
                            context,
                            icon: Icons.hourglass_empty_outlined,
                            label: context.l10n.pendingBadge,
                            color: Colors.blue,
                          ),
                        // Scope (Family only)
                        if (widget.instance.isFamily)
                          _buildBadge(
                            context,
                            icon: Icons.people_alt,
                            label: context.l10n.familyTab,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        // Priority
                        _buildBadge(
                          context,
                          icon: _getPriorityIcon(widget.instance.priority),
                          label: _getPriorityLabel(
                            context,
                            widget.instance.priority,
                          ),
                          color: _getPriorityColor(
                            context,
                            widget.instance.priority,
                          ),
                        ),
                        // Schedule (Recurring only)
                        if (schedule is! OneOffSchedule)
                          _buildBadge(
                            context,
                            icon: _getScheduleIcon(schedule),
                            label: _getScheduleLabel(context, schedule),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        // Effort/Duration (if any)
                        if (widget.schedule?.estimatedDuration != null)
                          _buildBadge(
                            context,
                            icon: Icons.timer_outlined,
                            label: _formatDuration(
                              widget.schedule!.estimatedDuration!,
                            ),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        // Assignee (if family & assigned)
                        if (widget.instance.isFamily &&
                            widget.instance.assignedUserId != null)
                          _buildBadge(
                            context,
                            icon: Icons.assignment_ind,
                            label: _isLoadingAssignee
                                ? context.l10n.loadingBadge
                                : (_assigneeName != null
                                      ? context.l10n.assignedTo(_assigneeName!)
                                      : context.l10n.assignedBadge),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.instance.title.toLowerCase().contains(
                      'duolingo',
                    )) ...[
                      IconButton(
                        key: const Key('open_duolingo_button'),
                        icon: const Icon(Icons.open_in_new, size: 20),
                        tooltip: 'Open Duolingo',
                        onPressed: () async {
                          final url = Uri.parse('https://www.duolingo.com');
                          try {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Could not open Duolingo: $e'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (widget.showEditOption &&
                        widget.schedule != null &&
                        schedule is OneOffSchedule) ...[
                      IconButton(
                        key: const Key('edit_pencil_button'),
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: context.l10n.editScheduleTooltip,
                        onPressed: () {
                          SystemNavigator.routeInformationUpdated(
                            uri: Uri.parse('/edit/${widget.schedule!.id}'),
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateTaskScreen(
                                taskToEdit: widget.schedule!,
                              ),
                            ),
                          ).then((_) {
                            SystemNavigator.routeInformationUpdated(
                              uri: Uri.parse('/tasks'),
                            );
                          });
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
          ),
        ),
      ],
    );
  }
}
