import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../logic/task.dart';
import '../logic/civil_day.dart';
import '../logic/relative_time.dart';
import '../logic/l10n_extension.dart';
import '../widgets/fun_check_button.dart';
import '../widgets/fun_delete_button.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // State for Interactions Tab
  bool _checkButtonVal = false;
  String _checkButtonStateText = 'Task Status: Active ⭕';
  bool _deleteCardVisible = true;
  String _deleteButtonStateText = 'Tap close to delete task card';

  // State for Missed Policies Tab / Simulator
  MissedPolicy _selectedPolicy = MissedPolicy.rollover;
  
  // Simulator State: List of simulated active tasks
  late List<SimulatedTask> _simulatedTasks;
  late List<String> _simulatedHistory;
  
  // Date definitions for Simulator
  final CivilDay _monday = const CivilDay(year: 2026, month: 5, day: 25);
  final CivilDay _tuesday = const CivilDay(year: 2026, month: 5, day: 26);
  final CivilDay _wednesday = const CivilDay(year: 2026, month: 5, day: 27);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _resetSimulator();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _resetSimulator() {
    setState(() {
      _simulatedHistory = [];
      if (_selectedPolicy == MissedPolicy.stack) {
        // Stack policy simulator starts with a Master task scheduled for Monday, current day Wednesday
        _simulatedTasks = [
          SimulatedTask(
            id: 'mower-master',
            title: 'Mow the Lawn',
            scheduledDate: _monday,
            isMaster: true,
            missedPolicy: MissedPolicy.stack,
          )
        ];
      } else {
        // Other policies start with a regular task scheduled for Monday, current day Tuesday
        _simulatedTasks = [
          SimulatedTask(
            id: 'mower-task',
            title: 'Mow the Lawn',
            scheduledDate: _monday,
            isMaster: false,
            missedPolicy: _selectedPolicy,
          )
        ];
      }
    });
  }

  void _simulateComplete(SimulatedTask task) {
    setState(() {
      _simulatedHistory.add('Completed task "${task.title}" (scheduled for ${task.scheduledDate.dayName})');
      
      if (task.missedPolicy == MissedPolicy.rollover) {
        // Rollover: next occurrence is strictly 1 day after scheduled date
        final nextDate = task.scheduledDate.addDays(1);
        _simulatedTasks = [
          SimulatedTask(
            id: task.id,
            title: task.title,
            scheduledDate: nextDate,
            isMaster: task.isMaster,
            missedPolicy: task.missedPolicy,
          )
        ];
      } else if (task.missedPolicy == MissedPolicy.shift) {
        // Shift: next occurrence is strictly 1 day after Today (Tuesday)
        final nextDate = _tuesday.addDays(1);
        _simulatedTasks = [
          SimulatedTask(
            id: task.id,
            title: task.title,
            scheduledDate: nextDate,
            isMaster: task.isMaster,
            missedPolicy: task.missedPolicy,
          )
        ];
      } else {
        // Standard completion for spawned cards in Stack, or Skip policy completed before skip occurs
        _simulatedTasks.removeWhere((t) => t.id == task.id);
      }
    });
  }

  void _simulateBackgroundSkip() {
    setState(() {
      final task = _simulatedTasks.firstWhere((t) => t.id == 'mower-task', orElse: () => _simulatedTasks[0]);
      _simulatedHistory.add('System automatically SKIPPED overdue task "${task.title}" scheduled for ${task.scheduledDate.dayName}');
      
      // Reschedule to next occurrence after scheduled date
      final nextDate = task.scheduledDate.addDays(1);
      _simulatedTasks = [
        SimulatedTask(
          id: task.id,
          title: task.title,
          scheduledDate: nextDate,
          isMaster: task.isMaster,
          missedPolicy: task.missedPolicy,
        )
      ];
    });
  }

  void _simulateBackgroundStackSpawning() {
    setState(() {
      final master = _simulatedTasks.firstWhere((t) => t.isMaster);
      _simulatedHistory.add('System processed Master stack task. Spawning missing cards up to Wednesday.');
      
      // Spawn cards for Monday, Tuesday, Wednesday
      _simulatedTasks = [
        SimulatedTask(
          id: 'mower-master',
          title: master.title,
          scheduledDate: master.scheduledDate,
          isMaster: true,
          lastSpawnedDate: _wednesday,
          missedPolicy: MissedPolicy.stack,
        ),
        SimulatedTask(
          id: 'mower_2026-05-25',
          title: '${master.title} (Mon)',
          scheduledDate: _monday,
          isMaster: false,
          missedPolicy: MissedPolicy.stack,
        ),
        SimulatedTask(
          id: 'mower_2026-05-26',
          title: '${master.title} (Tue)',
          scheduledDate: _tuesday,
          isMaster: false,
          missedPolicy: MissedPolicy.stack,
        ),
        SimulatedTask(
          id: 'mower_2026-05-27',
          title: '${master.title} (Wed)',
          scheduledDate: _wednesday,
          isMaster: false,
          missedPolicy: MissedPolicy.stack,
        ),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.helpTitle),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: context.l10n.helpTabGeneral),
            Tab(text: context.l10n.helpTabSchedules),
            Tab(text: context.l10n.helpTabInteractions),
            Tab(text: context.l10n.helpTabPolicies),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralTab(theme),
          _buildSchedulesTab(theme),
          _buildInteractionsTab(theme),
          _buildPoliciesTab(theme),
        ],
      ),
    );
  }

  Widget _buildGeneralTab(ThemeData theme) {
    const markdownContent = '''
# 🏠 Household Task Types
Our application organizes household tasks into two main categories:
1. **Personal Tasks**: 
   - Visible and manageable only by you.
   - Ideal for personal chores, habits, or private checklists.
2. **Family Tasks**:
   - Shared with the entire family unit.
   - Visible to all family members.
   - Can be assigned to a specific family member or left unassigned for anyone to pick up.
   - *Note: Only parents have permissions to edit or allocate Family tasks.*

---

# ⏱️ Agile Scheduling & Cycle Planning
We apply agile framework concepts to make household chore planning stress-free:
- **Weekly Sprint Cycles**: Tasks are planned in cycles (sprints). Chores can reside in the **Backlog** until they are moved into the **Active Cycle**.
- **Capacity Planning**: Each family member sets their daily/weekly available hours in Settings. The app translates this into a **Weekly Capacity Pool**.
- **Auto-Allocation**: When parents trigger "Auto-Allocate Chores" from the Sprint Dashboard, the app automatically distributes unassigned backlog tasks to family members based on:
  - Their remaining available capacity.
  - Starring/preferred tasks (chores they prefer to do).
''';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: MarkdownBody(
        data: markdownContent,
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          p: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
      ),
    );
  }

  Widget _buildSchedulesTab(ThemeData theme) {
    const markdownContent = '''
# 📅 Recurring schedules
Tasks can repeat automatically on a variety of flexible schedules:
- **Daily**: Repeats every N days (e.g., *every day*, *every 2 days*).
- **Weekly**: Repeats every N weeks on specific days of the week (e.g., *every week on Monday and Thursday*).
- **Monthly**: Repeats every N months:
  - **Day of Month**: On a specific day of the month (e.g., *on day 15*, *on the last day [-1]*).
  - **Nth Weekday**: On a specific weekday occurrence (e.g., *on the 2nd Tuesday*, *on the last Sunday*).
- **Yearly**: Repeats every N years on a specific month and day (e.g., *every year on June 4th*).

---

# 🕒 Multi-Time Daily Slots
For tasks that repeat multiple times in a single day (e.g., *Feed the dog morning & evening*):
- You can add **multiple daily time slots** with distinct Start and Due times.
- Completing a task advances it to the next scheduled slot of the day.
- Once the last slot is completed, the task rolls over to the next scheduled day.
''';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: MarkdownBody(
        data: markdownContent,
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
          p: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
      ),
    );
  }

  Widget _buildInteractionsTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Interactive Components',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8.0),
          Text(
            'Explore the custom interactive behaviors built into our chore card items below. These live examples run the exact widget code used in the app.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24.0),
          
          // Confetti Checkbox Section
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.celebration, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        '1. Fun Check Completion',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tapping the check button plays a satisfying scale-down rebound animation and releases a burst of colored confetti when checked.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  
                  // Live interactive widget container
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8.0),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        FunCheckButton(
                          value: _checkButtonVal,
                          onChanged: (val) {
                            setState(() {
                              _checkButtonVal = val;
                              _checkButtonStateText = val 
                                  ? 'Task Status: Completed! 🎉 (Confetti Burst!)' 
                                  : 'Task Status: Active ⭕';
                            });
                          },
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Water the Houseplants',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  decoration: _checkButtonVal ? TextDecoration.lineThrough : null,
                                  color: _checkButtonVal ? theme.colorScheme.onSurfaceVariant : null,
                                ),
                              ),
                              Text(
                                _checkButtonStateText,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: _checkButtonVal ? theme.colorScheme.primary : theme.colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16.0),

          // Delete Poof Section
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_queue, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Text(
                        '2. Poof Delete Dismissal',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tapping the delete icon triggers a playful cloud "poof" animation, expanding outward and fading away. The task item is removed after the animation completes.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  
                  // Live interactive delete card container
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    child: _deleteCardVisible
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                FunDeleteButton(
                                  onTap: () {
                                    setState(() {
                                      _deleteCardVisible = false;
                                      _deleteButtonStateText = 'Task card deleted! Tap "Restore Task" to try again.';
                                    });
                                  },
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Clean the Attic Chores',
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          color: theme.colorScheme.onErrorContainer,
                                        ),
                                      ),
                                      Text(
                                        _deleteButtonStateText,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _deleteButtonStateText,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _deleteCardVisible = true;
                                      _deleteButtonStateText = 'Tap close to delete task card';
                                    });
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Restore Task'),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoliciesTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Missed Task Policies',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8.0),
          Text(
            'Select a policy type below to learn how recurring tasks behave when they become overdue, and try it yourself in our Simulator.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16.0),

          // Policy choices grid/selector
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: MissedPolicy.values.map((policy) {
              final isSelected = _selectedPolicy == policy;
              return ChoiceChip(
                label: Text(
                  policy == MissedPolicy.rollover ? 'Rollover' :
                  policy == MissedPolicy.skip ? 'Skip' :
                  policy == MissedPolicy.shift ? 'Shift' : 'Stack',
                  style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedPolicy = policy;
                      _resetSimulator();
                    });
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16.0),

          // Policy Description Card
          _buildPolicyInfoCard(theme),
          const SizedBox(height: 24.0),

          // Simulator Title
          Row(
            children: [
              Icon(Icons.science, color: theme.colorScheme.secondary),
              const SizedBox(width: 8),
              Text(
                'Interactive Simulator',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          
          // The Simulator Box
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 3,
            color: theme.colorScheme.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header detailing the simulated conditions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SIMULATED CLOCK',
                            style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _selectedPolicy == MissedPolicy.stack 
                                ? 'Wednesday (May 27)' 
                                : 'Tuesday (May 26)',
                            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(
                          'Policy: ${_selectedPolicy.name.toUpperCase()}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24.0),

                  // Simulation Action Buttons
                  Row(
                    children: [
                      // Active buttons based on policy
                      if (_selectedPolicy == MissedPolicy.skip)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _simulatedTasks.any((t) => t.scheduledDate == _monday) 
                                ? _simulateBackgroundSkip 
                                : null,
                            icon: const Icon(Icons.autorenew),
                            label: const Text('Run Auto-Skip Check'),
                          ),
                        )
                      else if (_selectedPolicy == MissedPolicy.stack)
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _simulatedTasks.length == 1 && _simulatedTasks[0].lastSpawnedDate == null
                                ? _simulateBackgroundStackSpawning
                                : null,
                            icon: const Icon(Icons.grid_view),
                            label: const Text('Run Stack Spawning Check'),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      
                      if (_selectedPolicy == MissedPolicy.rollover || _selectedPolicy == MissedPolicy.shift || _selectedPolicy == MissedPolicy.stack) ...[
                        if (_selectedPolicy == MissedPolicy.skip) const SizedBox(width: 8.0),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _resetSimulator,
                            child: const Text('Reset Simulation'),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(width: 8.0),
                        OutlinedButton(
                          onPressed: _resetSimulator,
                          child: const Text('Reset'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16.0),

                  // Simulated Database / Task List
                  Text(
                    'SIMULATED ACTIVE TASK LIST',
                    style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8.0),
                  
                  if (_simulatedTasks.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      alignment: Alignment.center,
                      child: Text(
                        'No active tasks in database!',
                        style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    )
                  else
                    ..._simulatedTasks.map((simTask) {
                      final isOverdue = simTask.isOverdueForSim(_selectedPolicy == MissedPolicy.stack ? _wednesday : _tuesday);
                      return Card(
                        color: theme.colorScheme.surface,
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 8.0),
                        child: ListTile(
                          leading: simTask.isMaster 
                              ? Icon(Icons.star, color: theme.colorScheme.primary)
                              : FunCheckButton(
                                  value: false,
                                  onChanged: (val) {
                                    if (val) {
                                      _simulateComplete(simTask);
                                    }
                                  },
                                ),
                          title: Text(
                            simTask.title,
                            style: TextStyle(
                              fontWeight: simTask.isMaster ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            simTask.isMaster 
                                ? 'Master Task Schedule | Last Spawn: ${simTask.lastSpawnedDate?.dayName ?? "None"}'
                                : 'Scheduled: ${simTask.scheduledDate.dayName}',
                          ),
                          trailing: simTask.isMaster
                              ? Chip(
                                  label: const Text('MASTER'),
                                  backgroundColor: theme.colorScheme.primaryContainer,
                                  labelStyle: TextStyle(fontSize: 10, color: theme.colorScheme.onPrimaryContainer),
                                )
                              : (isOverdue 
                                  ? Chip(
                                      label: const Text('OVERDUE'),
                                      backgroundColor: theme.colorScheme.errorContainer,
                                      labelStyle: TextStyle(fontSize: 10, color: theme.colorScheme.onErrorContainer),
                                    )
                                  : Chip(
                                      label: const Text('ACTIVE'),
                                      backgroundColor: theme.colorScheme.secondaryContainer,
                                      labelStyle: TextStyle(fontSize: 10, color: theme.colorScheme.onSecondaryContainer),
                                    )),
                        ),
                      );
                    }),
                  
                  const SizedBox(height: 16.0),
                  
                  // History Log
                  Text(
                    'SIMULATION HISTORY LOG',
                    style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8.0),
                  Container(
                    height: 100.0,
                    width: double.infinity,
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: _simulatedHistory.isEmpty
                        ? Text(
                            'No actions performed yet.',
                            style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                          )
                        : ListView.builder(
                            itemCount: _simulatedHistory.length,
                            itemBuilder: (context, idx) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Text(
                                  '• ${_simulatedHistory[idx]}',
                                  style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyInfoCard(ThemeData theme) {
    switch (_selectedPolicy) {
      case MissedPolicy.rollover:
        return _buildCard(
          theme,
          title: 'Rollover (Push to Next Day)',
          icon: Icons.replay_outlined,
          color: theme.colorScheme.primary,
          description: 
              'The standard default policy. If you miss a task occurrence, it rolls forward to today and remains in an OVERDUE state.\n\n'
              '**Grounding in Implementation:**\n'
              'When you check off a Rollover task, its next occurrence is scheduled relative to its original scheduled date. '
              'For daily tasks, this means it rolls immediately to the day after it was due.',
        );
      case MissedPolicy.skip:
        return _buildCard(
          theme,
          title: 'Skip (Drop Occurrence)',
          icon: Icons.skip_next_outlined,
          color: Colors.orange,
          description:
              'If the due time of a recurring task has passed, the app automatically drops the current occurrence.\n\n'
              '**Grounding in Implementation:**\n'
              'A background process check runs automatically on task fetch. If it detects an overdue Skip task, '
              'it logs a "skipped" delta in the history list and automatically updates the task schedule to the next calendar date.',
        );
      case MissedPolicy.shift:
        return _buildCard(
          theme,
          title: 'Shift Schedule (Push Out Future)',
          icon: Icons.alarm_on_outlined,
          color: Colors.green,
          description:
              'Perfect for flexible chores (like mowing the lawn). If you complete the chore late, the rest of your future schedule shifts outward.\n\n'
              '**Grounding in Implementation:**\n'
              'When completing a Shift task, the next occurrence date is calculated relative to Today (completion day) instead of the original due date. '
              'For a bi-daily task due Monday and checked off Wednesday, the next occurrence shifts to Friday (Wednesday + 2 days).',
        );
      case MissedPolicy.stack:
        return _buildCard(
          theme,
          title: 'Stack/Overlap (Allow Concurrency)',
          icon: Icons.layers_outlined,
          color: Colors.purple,
          description:
              'Allows multiple active occurrences of the same task to exist concurrently in the task list.\n\n'
              '**Grounding in Implementation:**\n'
              'The recurring task acts as a "Master" template. A background check automatically spawns separate '
              'one-off task cards for every calendar occurrence date that has passed between the Master\'s scheduled date and today. '
              'You can check off or delete each card independently.',
        );
    }
  }

  Widget _buildCard(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper class for simulation task state
class SimulatedTask {
  final String id;
  final String title;
  final CivilDay scheduledDate;
  final bool isMaster;
  final CivilDay? lastSpawnedDate;
  final MissedPolicy missedPolicy;

  SimulatedTask({
    required this.id,
    required this.title,
    required this.scheduledDate,
    required this.isMaster,
    this.lastSpawnedDate,
    required this.missedPolicy,
  });

  bool isOverdueForSim(CivilDay currentDay) {
    if (isMaster) return false;
    return scheduledDate.isBefore(currentDay);
  }
}

extension on CivilDay {
  String get dayName {
    final utc = toUtcDateTime();
    switch (utc.weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }
}
