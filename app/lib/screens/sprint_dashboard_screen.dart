import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../logic/app_clock.dart';
import '../logic/task.dart';
import '../logic/task_repository.dart';
import '../logic/user_settings.dart';
import '../logic/user_settings_repository.dart';
import '../logic/family.dart';
import '../logic/family_repository.dart';
import '../logic/cycle_helper.dart';
import '../logic/auto_allocator.dart';
import '../logic/error_handler.dart';
import '../logic/l10n_extension.dart';

class SprintDashboardScreen extends ConsumerWidget {
  const SprintDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskRepo = ref.watch(taskRepositoryProvider);
    final settingsRepo = ref.watch(userSettingsRepositoryProvider);
    final familyRepo = ref.watch(familyRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.sprintDashboardTitle)),
      body: (taskRepo == null || settingsRepo == null || familyRepo == null)
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<UserSettings>(
              stream: settingsRepo.getSettings(),
              builder: (context, settingsSnapshot) {
                if (settingsSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final settings =
                    settingsSnapshot.data ??
                    const UserSettings(hoursAvailable: 8.0);

                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: familyRepo.getProfile(),
                  builder: (context, profileSnapshot) {
                    if (profileSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final profileData = profileSnapshot.data?.data() ?? {};
                    final familyId = profileData['familyId'] as String? ?? '';
                    final familyRole =
                        profileData['familyRole'] as String? ?? '';
                    final isParent = familyRole == 'parent';

                    return StreamBuilder<Family?>(
                      stream: familyId.isNotEmpty
                          ? familyRepo.getFamily(familyId)
                          : Stream.value(null),
                      builder: (context, familySnapshot) {
                        if (familyId.isNotEmpty &&
                            familySnapshot.connectionState ==
                                ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final family = familySnapshot.data;

                        return StreamBuilder<List<Task>>(
                          stream: taskRepo.getTasks(),
                          builder: (context, tasksSnapshot) {
                            if (tasksSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final tasks = tasksSnapshot.data ?? [];

                            return _SprintDashboardContent(
                              settings: settings,
                              familyId: familyId,
                              familyRole: familyRole,
                              isParent: isParent,
                              family: family,
                              tasks: tasks,
                              taskRepository: taskRepo,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

class _SprintDashboardContent extends ConsumerStatefulWidget {
  final UserSettings settings;
  final String familyId;
  final String familyRole;
  final bool isParent;
  final Family? family;
  final List<Task> tasks;
  final TaskRepository taskRepository;

  const _SprintDashboardContent({
    required this.settings,
    required this.familyId,
    required this.familyRole,
    required this.isParent,
    required this.family,
    required this.tasks,
    required this.taskRepository,
  });

  @override
  ConsumerState<_SprintDashboardContent> createState() =>
      _SprintDashboardContentState();
}

class _SprintDashboardContentState
    extends ConsumerState<_SprintDashboardContent> {
  bool _isAllocating = false;

  final Map<String, UserSettings> _memberSettings = {};
  final Map<String, List<Task>> _memberPersonalTasks = {};
  final Map<String, StreamSubscription<UserSettings>> _settingsSubscriptions =
      {};
  final Map<String, StreamSubscription<List<Task>>> _tasksSubscriptions = {};

  @override
  void initState() {
    super.initState();
    _updateSubscriptions();
  }

  @override
  void didUpdateWidget(covariant _SprintDashboardContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateSubscriptions();
  }

  @override
  void dispose() {
    for (final sub in _settingsSubscriptions.values) {
      sub.cancel();
    }
    for (final sub in _tasksSubscriptions.values) {
      sub.cancel();
    }
    super.dispose();
  }

  void _updateSubscriptions() {
    final family = widget.family;
    final settingsRepo = ref.read(userSettingsRepositoryProvider)!;
    final taskRepo = widget.taskRepository;

    final currentMembers = family?.members.keys.toSet() ?? {taskRepo.userId};

    // 1. Cancel subscriptions for members no longer present
    final removedMembers = _settingsSubscriptions.keys
        .where((uid) => !currentMembers.contains(uid))
        .toList();
    for (final uid in removedMembers) {
      _settingsSubscriptions[uid]?.cancel();
      _settingsSubscriptions.remove(uid);
      _memberSettings.remove(uid);

      _tasksSubscriptions[uid]?.cancel();
      _tasksSubscriptions.remove(uid);
      _memberPersonalTasks.remove(uid);
    }

    // 2. Add subscriptions for new members
    for (final uid in currentMembers) {
      if (!_settingsSubscriptions.containsKey(uid)) {
        _settingsSubscriptions[uid] = settingsRepo
            .getSettingsForUser(uid)
            .listen((settings) {
              setState(() {
                _memberSettings[uid] = settings;
              });
            });
      }
      if (!_tasksSubscriptions.containsKey(uid)) {
        _tasksSubscriptions[uid] = taskRepo.getPersonalTasksForUser(uid).listen(
          (tasks) {
            setState(() {
              _memberPersonalTasks[uid] = tasks;
            });
          },
        );
      }
    }
  }

  String _formatDateRange(DateTime start, DateTime end) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[start.weekday - 1]}, ${months[start.month - 1]} ${start.day} – '
        '${weekdays[end.weekday - 1]}, ${months[end.month - 1]} ${end.day}';
  }

  Future<void> _runAutoAllocator() async {
    final family = widget.family;
    if (family == null) return;

    setState(() {
      _isAllocating = true;
    });

    try {
      final currentNow = AppClock.now;
      final currentCycleId = CycleHelper.getCycleId(currentNow);

      final activeFamilyTasks = widget.tasks
          .where(
            (t) => t.isFamily && t.cycleId == currentCycleId && !t.isMaster,
          )
          .toList();

      if (activeFamilyTasks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No active family chores in this cycle to allocate.',
              ),
            ),
          );
        }
        return;
      }

      final userIds = family.members.keys.toList();
      final userWeeklyCapacities = <String, double>{};
      final userPersonalEfforts = <String, double>{};

      for (final uid in userIds) {
        final settings =
            _memberSettings[uid] ?? const UserSettings(hoursAvailable: 8.0);
        userWeeklyCapacities[uid] = settings.hoursAvailable * 7 * 60;

        final personalTasks = _memberPersonalTasks[uid] ?? [];
        double effort = 0;
        for (final t in personalTasks) {
          if (!t.isFamily && t.cycleId == currentCycleId && !t.isMaster) {
            effort += t.estimatedDuration?.inMinutes.toDouble() ?? 0.0;
          }
        }
        userPersonalEfforts[uid] = effort;
      }

      final assignments = AutoAllocator.allocate(
        userIds: userIds,
        userWeeklyCapacities: userWeeklyCapacities,
        userPersonalEfforts: userPersonalEfforts,
        familyTasks: activeFamilyTasks,
      );

      final futures = <Future<void>>[];
      for (final entry in assignments.entries) {
        final taskId = entry.key;
        final assignedUserId = entry.value;

        final task = activeFamilyTasks.firstWhere((t) => t.id == taskId);
        if (task.assignedUserId != assignedUserId) {
          final modification = task.updateAssignedUserId(
            assignedUserId,
            widget.taskRepository.userId,
          );
          futures.add(widget.taskRepository.updateTask(modification));
        }
      }

      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.choresAllocatedSuccess)),
        );
      }
    } catch (e, stackTrace) {
      if (mounted) {
        final errorHandler = ref.read(errorHandlerProvider);
        final report = errorHandler.report(e, stackTrace: stackTrace);
        errorHandler.showErrorDialog(context, report);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAllocating = false;
        });
      }
    }
  }

  Future<void> _toggleCycle(Task task, String? cycleId) async {
    try {
      final modification = task.updateCycleId(
        cycleId,
        widget.taskRepository.userId,
      );
      await widget.taskRepository.updateTask(modification);
    } catch (e, stackTrace) {
      if (mounted) {
        final errorHandler = ref.read(errorHandlerProvider);
        final report = errorHandler.report(e, stackTrace: stackTrace);
        errorHandler.showErrorDialog(context, report);
      }
    }
  }

  Future<void> _togglePreference(Task task) async {
    try {
      final currentUserId = widget.taskRepository.userId;
      final newPreferredBy = Map<String, bool>.from(task.preferredBy);
      newPreferredBy[currentUserId] = !(newPreferredBy[currentUserId] ?? false);

      final modification = task.updatePreferredBy(
        newPreferredBy,
        currentUserId,
      );
      await widget.taskRepository.updateTask(modification);
    } catch (e, stackTrace) {
      if (mounted) {
        final errorHandler = ref.read(errorHandlerProvider);
        final report = errorHandler.report(e, stackTrace: stackTrace);
        errorHandler.showErrorDialog(context, report);
      }
    }
  }

  Widget _buildMemberCapacityRow({
    required String name,
    required double total,
    required double personal,
    required double family,
    required double remaining,
    required double fraction,
  }) {
    Color progressColor;
    if (fraction <= 0.8) {
      progressColor = Theme.of(context).colorScheme.primary;
    } else if (fraction <= 1.0) {
      progressColor = Colors.orange;
    } else {
      progressColor = Theme.of(context).colorScheme.error;
    }

    final isCurrentUser = name.contains('(You)');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontWeight: isCurrentUser
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                context.l10n.memberRemainingTotal(
                  remaining.toInt(),
                  total.toInt(),
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.memberPersonalChores(personal.toInt(), family.toInt()),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(TaskPriority priority) {
    Color color;
    String label;
    switch (priority) {
      case TaskPriority.low:
        color = Colors.grey;
        label = context.l10n.priorityLow;
        break;
      case TaskPriority.medium:
        color = Colors.orange;
        label = context.l10n.priorityMedium;
        break;
      case TaskPriority.high:
        color = Colors.red;
        label = context.l10n.priorityHigh;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTaskCard(Task task, bool isActive, String currentCycleId) {
    final hasFamily = widget.familyId.isNotEmpty;
    final canModify = !task.isFamily || (hasFamily && widget.isParent);
    final currentUserId = widget.taskRepository.userId;

    String? assigneeName;
    if (task.isFamily && task.assignedUserId != null) {
      assigneeName =
          widget.family?.members[task.assignedUserId]?.displayName ??
          task.assignedUserId;
    }

    final hasStarred = task.preferredBy[currentUserId] == true;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildPriorityBadge(task.priority),
                    ],
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      task.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (task.estimatedDuration != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSecondaryContainer,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${task.estimatedDuration!.inMinutes} min',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSecondaryContainer,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: task.isFamily
                              ? Theme.of(context).colorScheme.tertiaryContainer
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          task.isFamily
                              ? context.l10n.familyTaskLabel
                              : 'Personal',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: task.isFamily
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onTertiaryContainer
                                    : Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      if (task.isFamily)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                task.assignedUserId != null
                                    ? Icons.person
                                    : Icons.person_outline,
                                size: 14,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                task.assignedUserId != null
                                    ? context.l10n.assignedTo(
                                        assigneeName ?? '',
                                      )
                                    : context.l10n.unassigned,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                    ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                if (task.isFamily && !isActive)
                  IconButton(
                    key: Key('star_btn_${task.id}'),
                    icon: Icon(
                      hasStarred ? Icons.star : Icons.star_border,
                      color: hasStarred
                          ? Colors.amber
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    tooltip: context.l10n.starTooltip,
                    onPressed: () => _togglePreference(task),
                  ),
                if (isActive)
                  IconButton(
                    key: Key('remove_btn_${task.id}'),
                    icon: const Icon(Icons.remove_circle_outline),
                    color: canModify
                        ? Theme.of(context).colorScheme.error
                        : Colors.grey,
                    tooltip: context.l10n.removeFromCycleTooltip,
                    onPressed: canModify
                        ? () => _toggleCycle(task, null)
                        : null,
                  )
                else
                  IconButton(
                    key: Key('add_btn_${task.id}'),
                    icon: const Icon(Icons.add_circle_outline),
                    color: canModify
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    tooltip: context.l10n.addToCycleTooltip,
                    onPressed: canModify
                        ? () => _toggleCycle(task, currentCycleId)
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentNow = AppClock.now;
    final currentCycleId = CycleHelper.getCycleId(currentNow);
    final range = CycleHelper.getCycleRange(currentNow);

    final hoursAvailable = widget.settings.hoursAvailable;
    final totalCapacityMins = hoursAvailable * 7 * 60;

    final currentUserId = widget.taskRepository.userId;

    double personalActiveEffort = 0;
    double familyActiveEffort = 0;

    final activeTasks = <Task>[];
    final backlogTasks = <Task>[];

    for (final task in widget.tasks) {
      if (task.isMaster) continue; // Skip master templates

      if (task.cycleId == currentCycleId) {
        activeTasks.add(task);
        final effort = task.estimatedDuration?.inMinutes.toDouble() ?? 0.0;
        if (!task.isFamily) {
          personalActiveEffort += effort;
        } else if (task.assignedUserId == currentUserId) {
          familyActiveEffort += effort;
        }
      } else if (task.cycleId == null) {
        backlogTasks.add(task);
      }
    }

    final totalUsedEffort = personalActiveEffort + familyActiveEffort;
    final remainingCapacity = (totalCapacityMins - totalUsedEffort).clamp(
      0.0,
      double.infinity,
    );
    final fractionUsed = totalCapacityMins > 0
        ? (totalUsedEffort / totalCapacityMins)
        : 0.0;

    Color progressColor;
    if (fractionUsed <= 0.8) {
      progressColor = Theme.of(context).colorScheme.primary;
    } else if (fractionUsed <= 1.0) {
      progressColor = Colors.orange;
    } else {
      progressColor = Theme.of(context).colorScheme.error;
    }

    return Stack(
      children: [
        DefaultTabController(
          length: 2,
          child: Column(
            children: [
              // Cycle Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDateRange(range.start, range.end),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            currentCycleId,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              TabBar(
                tabs: [
                  Tab(text: context.l10n.activeCycleTab),
                  Tab(text: context.l10n.backlogTab),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    // Active Cycle Tab
                    ListView(
                      children: [
                        // Capacity Card
                        Card(
                          margin: const EdgeInsets.all(16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.familyId.isNotEmpty &&
                                    widget.family != null) ...[
                                  Text(
                                    context.l10n.familyCapacityPool,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const Divider(height: 24),
                                  ...widget.family!.members.values.map((
                                    member,
                                  ) {
                                    final memberUid = member.userId;
                                    final memberSettings =
                                        _memberSettings[memberUid] ??
                                        const UserSettings(hoursAvailable: 8.0);
                                    final memberTotalCapMins =
                                        memberSettings.hoursAvailable * 7 * 60;

                                    double memberPersonalEffort = 0.0;
                                    final memberTasks =
                                        _memberPersonalTasks[memberUid] ?? [];
                                    for (final t in memberTasks) {
                                      if (!t.isFamily &&
                                          t.cycleId == currentCycleId &&
                                          !t.isMaster) {
                                        memberPersonalEffort +=
                                            t.estimatedDuration?.inMinutes
                                                .toDouble() ??
                                            0.0;
                                      }
                                    }

                                    double memberFamilyEffort = 0.0;
                                    for (final t in widget.tasks) {
                                      if (t.isFamily &&
                                          t.cycleId == currentCycleId &&
                                          !t.isMaster &&
                                          t.assignedUserId == memberUid) {
                                        memberFamilyEffort +=
                                            t.estimatedDuration?.inMinutes
                                                .toDouble() ??
                                            0.0;
                                      }
                                    }

                                    final memberUsedEffort =
                                        memberPersonalEffort +
                                        memberFamilyEffort;
                                    final memberRemaining =
                                        (memberTotalCapMins - memberUsedEffort)
                                            .clamp(0.0, double.infinity);
                                    final memberFraction =
                                        memberTotalCapMins > 0
                                        ? (memberUsedEffort /
                                              memberTotalCapMins)
                                        : 0.0;

                                    return _buildMemberCapacityRow(
                                      name:
                                          memberUid ==
                                              widget.taskRepository.userId
                                          ? '${member.displayName} (You)'
                                          : member.displayName,
                                      total: memberTotalCapMins,
                                      personal: memberPersonalEffort,
                                      family: memberFamilyEffort,
                                      remaining: memberRemaining,
                                      fraction: memberFraction,
                                    );
                                  }),
                                ] else ...[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        context.l10n.weeklyCapacityLabel,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        '${totalCapacityMins.toInt()} min (${hoursAvailable.toStringAsFixed(1)}h/day)',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      height: 12,
                                      child: LinearProgressIndicator(
                                        value: fractionUsed.clamp(0.0, 1.0),
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              progressColor,
                                            ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.outlineVariant,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                context.l10n.personalTasksLabel(
                                                  personalActiveEffort.toInt(),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            children: [
                                              Container(
                                                width: 12,
                                                height: 12,
                                                decoration: BoxDecoration(
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.tertiary,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                context.l10n.familyChoresLabel(
                                                  familyActiveEffort.toInt(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            context.l10n.remainingCapacityLabel(
                                              remainingCapacity.toInt(),
                                            ),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: remainingCapacity > 0
                                                  ? Theme.of(
                                                      context,
                                                    ).colorScheme.onSurface
                                                  : Theme.of(
                                                      context,
                                                    ).colorScheme.error,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // Auto-Allocate Button (Only for Family Parent roles)
                        if (widget.familyId.isNotEmpty && widget.isParent)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            child: ElevatedButton.icon(
                              key: const Key('auto_allocate_button'),
                              onPressed: _runAutoAllocator,
                              icon: const Icon(Icons.smart_toy_outlined),
                              label: Text(context.l10n.autoAllocateButton),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 12),

                        // List of Active Tasks
                        if (activeTasks.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Center(
                              child: Text(
                                context.l10n.noActiveTasks,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        else
                          ...activeTasks.map(
                            (t) => _buildTaskCard(t, true, currentCycleId),
                          ),

                        const SizedBox(height: 32),
                      ],
                    ),

                    // Backlog Tab
                    ListView(
                      children: [
                        const SizedBox(height: 12),
                        if (backlogTasks.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Center(
                              child: Text(
                                context.l10n.noBacklogTasks,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        else
                          ...backlogTasks.map(
                            (t) => _buildTaskCard(t, false, currentCycleId),
                          ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_isAllocating)
          Container(
            color: Colors.black45,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
