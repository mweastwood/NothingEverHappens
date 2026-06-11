import 'package:flutter/material.dart';

/// A widget that allows users to select a specific date and time.
///
/// It visually mimics the [RelativeTimeWidget] but for absolute [DateTime]s.
class AbsoluteTimeWidget extends StatefulWidget {
  final ValueNotifier<DateTime> controller;

  const AbsoluteTimeWidget({super.key, required this.controller});

  @override
  State<AbsoluteTimeWidget> createState() => _AbsoluteTimeWidgetState();
}

class _AbsoluteTimeWidgetState extends State<AbsoluteTimeWidget> {
  late final ValueNotifier<DateTime> _dateTimeNotifier;

  @override
  void initState() {
    super.initState();
    _dateTimeNotifier = ValueNotifier(widget.controller.value);
    widget.controller.addListener(_onExternalUpdate);
    _dateTimeNotifier.addListener(_onInternalUpdate);
  }

  @override
  void didUpdateWidget(covariant AbsoluteTimeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onExternalUpdate);
      widget.controller.addListener(_onExternalUpdate);
      _onExternalUpdate();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onExternalUpdate);
    _dateTimeNotifier.removeListener(_onInternalUpdate);
    _dateTimeNotifier.dispose();
    super.dispose();
  }

  void _onExternalUpdate() {
    if (_dateTimeNotifier.value != widget.controller.value) {
      _dateTimeNotifier.value = widget.controller.value;
    }
  }

  void _onInternalUpdate() {
    if (widget.controller.value != _dateTimeNotifier.value) {
      widget.controller.value = _dateTimeNotifier.value;
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTimeNotifier.value),
    );
    if (picked != null) {
      final current = _dateTimeNotifier.value;
      _dateTimeNotifier.value = DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      );
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateTimeNotifier.value,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      final current = _dateTimeNotifier.value;
      _dateTimeNotifier.value = DateTime(
        picked.year,
        picked.month,
        picked.day,
        current.hour,
        current.minute,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: _dateTimeNotifier,
      builder: (context, dateTime, child) {
        return Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pickTime,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Time',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        height: 1.1,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  TimeOfDay.fromDateTime(
                                    dateTime,
                                  ).format(context),
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.access_time,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Date',
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        height: 1.1,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        height: 1.2,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.calendar_today,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
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
