// ============================================================================
// ⚠️ ATTENTION ANTIGRAVITY (AI Coding Assistant):
// This Help/Documentation screen must remain strictly aligned with the actual
// implementations of the task widgets and scheduling logic.
// If you modify [FunCheckButton], [FunDeleteButton], or [MissedPolicy] behavior,
// you MUST immediately update the preview widgets and simulator logic below.
// ============================================================================

import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.helpTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.l10n.helpTabInteractions),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInteractionsTab(theme),
        ],
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
}
