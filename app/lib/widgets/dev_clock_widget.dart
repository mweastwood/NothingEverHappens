import 'package:flutter/material.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';
import '../main.dart';

class DevClockWidget extends StatelessWidget {
  const DevClockWidget({super.key});

  void _showTimeMachine(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TimeMachineDashboard(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppConfig.environment == AppEnvironment.prod) {
      return const SizedBox.shrink();
    }

    return ValueListenableBuilder<DateTime?>(
      valueListenable: AppClock.timeNotifier,
      builder: (context, mockTime, _) {
        final isMocked = mockTime != null;

        return Stack(
          children: [
            // Floating Dev Action Button at Bottom-Left (uses InkWell instead of FAB to avoid finder collisions in tests)
            Positioned(
              left: 16,
              bottom: isMocked ? 80 : 16, // Shift up if banner is active
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isMocked
                      ? Colors.orangeAccent
                      : Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      // ignore: deprecated_member_use
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _showTimeMachine(context),
                    child: Tooltip(
                      message: 'Time Machine Dashboard',
                      child: Icon(
                        Icons.av_timer,
                        color: isMocked
                            ? Colors.black87
                            : Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Persistent Dev Banner at Bottom-Center
            if (isMocked)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.orange.shade900.withOpacity(0.9),
                    border: const Border(
                      top: BorderSide(color: Colors.orangeAccent, width: 2),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '🚨 Mock Clock: ${mockTime.year}-${mockTime.month.toString().padLeft(2, '0')}-${mockTime.day.toString().padLeft(2, '0')} ${mockTime.hour.toString().padLeft(2, '0')}:${mockTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.orange.shade900,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                              ),
                              onPressed: () =>
                                  AppClock.advanceTime(const Duration(days: 1)),
                              child: const Text(
                                '+1 Day',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                              ),
                              onPressed: () => AppClock.reset(),
                              child: const Text(
                                'Reset',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class TimeMachineDashboard extends StatelessWidget {
  const TimeMachineDashboard({super.key});

  Future<void> _pickDateTime(BuildContext context) async {
    final initialDate = AppClock.now;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date == null) return;
    if (!context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return;

    final newDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    AppClock.setMockTime(newDateTime);
  }

  Widget _buildQuickAdvanceButton(
    BuildContext context,
    String label,
    Duration duration,
  ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () => AppClock.advanceTime(duration),
      child: Text(label),
    );
  }

  Widget _buildDSTPresetButton(
    BuildContext context,
    String label,
    DateTime targetTime,
  ) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.speed, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      onPressed: () => AppClock.setMockTime(targetTime),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: AppClock.timeNotifier,
      builder: (context, mockTime, _) {
        final isMocked = mockTime != null;
        final currentSim = AppClock.now;

        return Card(
          margin: const EdgeInsets.all(16),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⏰ Time Machine',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Test recurring tasks & DST bounds',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Mock Clock Active Toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Simulate Custom Time',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Switch(
                        value: isMocked,
                        onChanged: (active) {
                          if (active) {
                            AppClock.setMockTime(DateTime.now());
                          } else {
                            AppClock.reset();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Current Simulated Date Display
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Simulated Date & Time',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${currentSim.year}-${currentSim.month.toString().padLeft(2, '0')}-${currentSim.day.toString().padLeft(2, '0')} ${currentSim.hour.toString().padLeft(2, '0')}:${currentSim.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                        if (isMocked)
                          IconButton.filledTonal(
                            icon: const Icon(Icons.edit_calendar),
                            onPressed: () => _pickDateTime(context),
                            tooltip: 'Pick Date & Time',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Quick Time Advance Grid
                  if (isMocked) ...[
                    const Text(
                      'Quick Time Advance',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      children: [
                        _buildQuickAdvanceButton(
                          context,
                          '+1 Hour',
                          const Duration(hours: 1),
                        ),
                        _buildQuickAdvanceButton(
                          context,
                          '+12 Hours',
                          const Duration(hours: 12),
                        ),
                        _buildQuickAdvanceButton(
                          context,
                          '+1 Day',
                          const Duration(days: 1),
                        ),
                        _buildQuickAdvanceButton(
                          context,
                          '+1 Week',
                          const Duration(days: 7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // DST Presets
                    const Text(
                      '🚀 DST Fast-Travel Presets',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: _buildDSTPresetButton(
                            context,
                            'Spring Forward 2026 (March 8, 1:59 AM)',
                            DateTime(2026, 3, 8, 1, 59, 0),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: _buildDSTPresetButton(
                            context,
                            'Autumn Fallback 2025 (Nov 2, 1:59 AM)',
                            DateTime(2025, 11, 2, 1, 59, 0),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
