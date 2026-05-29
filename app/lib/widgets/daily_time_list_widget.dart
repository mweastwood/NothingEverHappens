import 'package:flutter/material.dart';
import '../logic/task.dart';
import '../logic/l10n_extension.dart';

/// A widget that allows users to manage a list of daily occurrence time windows.
///
/// It provides a beautiful interface to add, remove, and edit multiple
/// time slots (Start Time and Due Time).
class DailyTimeListWidget extends StatefulWidget {
  final ValueNotifier<List<DailyOccurrenceTime>> controller;

  const DailyTimeListWidget({super.key, required this.controller});

  @override
  State<DailyTimeListWidget> createState() => _DailyTimeListWidgetState();
}

class _DailyTimeListWidgetState extends State<DailyTimeListWidget> {
  List<DailyOccurrenceTime> get _times => widget.controller.value;

  void _updateTimes(List<DailyOccurrenceTime> newTimes) {
    widget.controller.value = newTimes;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickTime({
    required int index,
    required bool isStart,
    required TimeOfDay initialTime,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      final updatedTimes = List<DailyOccurrenceTime>.from(_times);
      final current = updatedTimes[index];
      updatedTimes[index] = DailyOccurrenceTime(
        startTime: isStart ? picked : current.startTime,
        dueTime: isStart ? current.dueTime : picked,
        notificationTime: current.notificationTime,
      );
      _updateTimes(updatedTimes);
    }
  }

  Future<void> _pickNotificationTime({
    required int index,
    required TimeOfDay initialTime,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      final updatedTimes = List<DailyOccurrenceTime>.from(_times);
      final current = updatedTimes[index];
      updatedTimes[index] = DailyOccurrenceTime(
        startTime: current.startTime,
        dueTime: current.dueTime,
        notificationTime: picked,
      );
      _updateTimes(updatedTimes);
    }
  }

  void _clearNotificationTime(int index) {
    final updatedTimes = List<DailyOccurrenceTime>.from(_times);
    final current = updatedTimes[index];
    updatedTimes[index] = DailyOccurrenceTime(
      startTime: current.startTime,
      dueTime: current.dueTime,
      notificationTime: null,
    );
    _updateTimes(updatedTimes);
  }

  void _addTimeSlot() {
    final updatedTimes = List<DailyOccurrenceTime>.from(_times);
    // Add a default slot: 9:00 AM to 5:00 PM
    updatedTimes.add(
      const DailyOccurrenceTime(
        startTime: TimeOfDay(hour: 9, minute: 0),
        dueTime: TimeOfDay(hour: 17, minute: 0),
      ),
    );
    _updateTimes(updatedTimes);
  }

  void _removeTimeSlot(int index) {
    if (_times.length > 1) {
      final updatedTimes = List<DailyOccurrenceTime>.from(_times);
      updatedTimes.removeAt(index);
      _updateTimes(updatedTimes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n?.dailyOccurrencesHeader ?? 'Daily Occurrences',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _times.length,
          itemBuilder: (context, index) {
            final slot = _times[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  context.l10n?.startTimeLabel ?? 'Start Time',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: () => _pickTime(
                                    index: index,
                                    isStart: true,
                                    initialTime: slot.startTime,
                                  ),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    fixedSize: const Size.fromHeight(36),
                                  ),
                                  icon: const Icon(Icons.access_time, size: 16),
                                  label: Text(
                                    slot.startTime.format(context),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  context.l10n?.dueTimeLabel ?? 'Due Time',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: () => _pickTime(
                                    index: index,
                                    isStart: false,
                                    initialTime: slot.dueTime,
                                  ),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    fixedSize: const Size.fromHeight(36),
                                  ),
                                  icon: const Icon(Icons.access_time, size: 16),
                                  label: Text(
                                    slot.dueTime.format(context),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  context.l10n?.notificationTimeLabel ?? 'Notification Time',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (slot.notificationTime == null)
                                  OutlinedButton.icon(
                                    onPressed: () => _pickNotificationTime(
                                      index: index,
                                      initialTime: const TimeOfDay(
                                        hour: 9,
                                        minute: 0,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      fixedSize: const Size.fromHeight(36),
                                    ),
                                    icon: const Icon(
                                      Icons.notifications_none,
                                      size: 16,
                                    ),
                                    label: Text(
                                      context.l10n?.noneLabel ?? 'None',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  )
                                else
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FilledButton.tonalIcon(
                                        onPressed: () => _pickNotificationTime(
                                          index: index,
                                          initialTime: slot.notificationTime!,
                                        ),
                                        style: FilledButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 4,
                                          ),
                                          fixedSize: const Size.fromHeight(36),
                                        ),
                                        icon: const Icon(
                                          Icons.notifications_active,
                                          size: 16,
                                        ),
                                        label: Text(
                                          slot.notificationTime!.format(
                                            context,
                                          ),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () =>
                                            _clearNotificationTime(index),
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: context.l10n?.clearNotificationTimeTooltip ?? 'Clear notification time',
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (_times.length > 1) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () => _removeTimeSlot(index),
                          tooltip: context.l10n?.removeTimeSlotTooltip ?? 'Remove time slot',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addTimeSlot,
          icon: const Icon(Icons.add, size: 18),
          label: Text(context.l10n?.addTimeSlotButton ?? 'Add Time Slot'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 44),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
