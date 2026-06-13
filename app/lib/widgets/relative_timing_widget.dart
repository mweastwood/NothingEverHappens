import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../logic/relative_time.dart';

class RelativeTimingWidget extends StatefulWidget {
  final RelativeTime startRelativeTime;
  final RelativeTime dueRelativeTime;
  final RelativeTime? notificationRelativeTime;
  final ValueChanged<RelativeTime> onStartChanged;
  final ValueChanged<RelativeTime> onDueChanged;
  final ValueChanged<RelativeTime?> onNotificationChanged;

  const RelativeTimingWidget({
    super.key,
    required this.startRelativeTime,
    required this.dueRelativeTime,
    required this.notificationRelativeTime,
    required this.onStartChanged,
    required this.onDueChanged,
    required this.onNotificationChanged,
  });

  @override
  State<RelativeTimingWidget> createState() => _RelativeTimingWidgetState();
}

class _RelativeTimingWidgetState extends State<RelativeTimingWidget> {
  late TextEditingController _startOffsetController;
  late TextEditingController _dueOffsetController;
  late TextEditingController _notifOffsetController;

  bool _customStart = false;
  bool _customDue = false;
  bool _customNotif = false;

  final List<int> _standardOffsets = [0, 1, 2, -1, -2];

  @override
  void initState() {
    super.initState();
    _startOffsetController = TextEditingController(
      text: widget.startRelativeTime.dayOffset.toString(),
    );
    _dueOffsetController = TextEditingController(
      text: widget.dueRelativeTime.dayOffset.toString(),
    );
    _notifOffsetController = TextEditingController(
      text: widget.notificationRelativeTime?.dayOffset.toString() ?? '0',
    );

    _customStart = !_standardOffsets.contains(
      widget.startRelativeTime.dayOffset,
    );
    _customDue = !_standardOffsets.contains(widget.dueRelativeTime.dayOffset);
    if (widget.notificationRelativeTime != null) {
      _customNotif = !_standardOffsets.contains(
        widget.notificationRelativeTime!.dayOffset,
      );
    }
  }

  @override
  void dispose() {
    _startOffsetController.dispose();
    _dueOffsetController.dispose();
    _notifOffsetController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RelativeTimingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.startRelativeTime.dayOffset !=
            widget.startRelativeTime.dayOffset &&
        !_customStart) {
      final startOffsetStr = widget.startRelativeTime.dayOffset.toString();
      final standard = _standardOffsets.contains(
        widget.startRelativeTime.dayOffset,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _startOffsetController.text = startOffsetStr;
            _customStart = !standard;
          });
        }
      });
    }
    if (oldWidget.dueRelativeTime.dayOffset !=
            widget.dueRelativeTime.dayOffset &&
        !_customDue) {
      final dueOffsetStr = widget.dueRelativeTime.dayOffset.toString();
      final standard = _standardOffsets.contains(
        widget.dueRelativeTime.dayOffset,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _dueOffsetController.text = dueOffsetStr;
            _customDue = !standard;
          });
        }
      });
    }
    if (widget.notificationRelativeTime != null &&
        oldWidget.notificationRelativeTime?.dayOffset !=
            widget.notificationRelativeTime!.dayOffset &&
        !_customNotif) {
      final notifOffsetStr = widget.notificationRelativeTime!.dayOffset
          .toString();
      final standard = _standardOffsets.contains(
        widget.notificationRelativeTime!.dayOffset,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _notifOffsetController.text = notifOffsetStr;
            _customNotif = !standard;
          });
        }
      });
    }
  }

  String _getOffsetLabel(int offset) {
    switch (offset) {
      case 0:
        return 'Same day';
      case 1:
        return '1 day after';
      case 2:
        return '2 days after';
      case -1:
        return '1 day before';
      case -2:
        return '2 days before';
      default:
        return '$offset days';
    }
  }

  Widget _buildOffsetField({
    required String label,
    required int currentOffset,
    required TimeOfDay currentTime,
    required TextEditingController customController,
    required bool isCustom,
    required ValueChanged<int> onOffsetChanged,
    required VoidCallback onTimePickerTap,
    required ValueChanged<bool> onCustomChanged,
  }) {
    final theme = Theme.of(context);
    final dropdownValue = isCustom ? -999 : currentOffset;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<int>(
                  initialValue: dropdownValue,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    ..._standardOffsets.map(
                      (val) => DropdownMenuItem<int>(
                        value: val,
                        child: Text(_getOffsetLabel(val)),
                      ),
                    ),
                    const DropdownMenuItem<int>(
                      value: -999,
                      child: Text('Custom offset...'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val == -999) {
                      onCustomChanged(true);
                    } else if (val != null) {
                      onCustomChanged(false);
                      onOffsetChanged(val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: onTimePickerTap,
                  icon: const Icon(Icons.access_time, size: 16),
                  label: Text(
                    currentTime.format(context),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isCustom) ...[
            const SizedBox(height: 8),
            TextFormField(
              controller: customController,
              decoration: const InputDecoration(
                labelText: 'Enter offset in days',
                helperText:
                    'Use positive numbers for after, negative numbers for before',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
              ],
              onChanged: (val) {
                final offset = int.tryParse(val) ?? 0;
                onOffsetChanged(offset);
              },
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notificationEnabled = widget.notificationRelativeTime != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOffsetField(
          label: 'Start window',
          currentOffset: widget.startRelativeTime.dayOffset,
          currentTime: widget.startRelativeTime.time,
          customController: _startOffsetController,
          isCustom: _customStart,
          onOffsetChanged: (offset) {
            setState(() {
              _customStart = !_standardOffsets.contains(offset);
            });
            widget.onStartChanged(
              RelativeTime(
                dayOffset: offset,
                time: widget.startRelativeTime.time,
              ),
            );
          },
          onCustomChanged: (custom) {
            setState(() {
              _customStart = custom;
            });
          },
          onTimePickerTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: widget.startRelativeTime.time,
            );
            if (picked != null) {
              widget.onStartChanged(
                RelativeTime(
                  dayOffset: widget.startRelativeTime.dayOffset,
                  time: picked,
                ),
              );
            }
          },
        ),
        const SizedBox(height: 8),
        _buildOffsetField(
          label: 'Due window',
          currentOffset: widget.dueRelativeTime.dayOffset,
          currentTime: widget.dueRelativeTime.time,
          customController: _dueOffsetController,
          isCustom: _customDue,
          onOffsetChanged: (offset) {
            setState(() {
              _customDue = !_standardOffsets.contains(offset);
            });
            widget.onDueChanged(
              RelativeTime(
                dayOffset: offset,
                time: widget.dueRelativeTime.time,
              ),
            );
          },
          onCustomChanged: (custom) {
            setState(() {
              _customDue = custom;
            });
          },
          onTimePickerTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: widget.dueRelativeTime.time,
            );
            if (picked != null) {
              widget.onDueChanged(
                RelativeTime(
                  dayOffset: widget.dueRelativeTime.dayOffset,
                  time: picked,
                ),
              );
            }
          },
        ),
        const SizedBox(height: 12),
        const Divider(),
        CheckboxListTile(
          title: Text(
            'Enable notification reminder',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          value: notificationEnabled,
          onChanged: (enabled) {
            if (enabled == true) {
              widget.onNotificationChanged(
                const RelativeTime(
                  dayOffset: 0,
                  time: TimeOfDay(hour: 9, minute: 0),
                ),
              );
            } else {
              widget.onNotificationChanged(null);
            }
          },
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        if (notificationEnabled)
          _buildOffsetField(
            label: 'Notification window',
            currentOffset: widget.notificationRelativeTime!.dayOffset,
            currentTime: widget.notificationRelativeTime!.time,
            customController: _notifOffsetController,
            isCustom: _customNotif,
            onOffsetChanged: (offset) {
              setState(() {
                _customNotif = !_standardOffsets.contains(offset);
              });
              widget.onNotificationChanged(
                RelativeTime(
                  dayOffset: offset,
                  time: widget.notificationRelativeTime!.time,
                ),
              );
            },
            onCustomChanged: (custom) {
              setState(() {
                _customNotif = custom;
              });
            },
            onTimePickerTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: widget.notificationRelativeTime!.time,
              );
              if (picked != null) {
                widget.onNotificationChanged(
                  RelativeTime(
                    dayOffset: widget.notificationRelativeTime!.dayOffset,
                    time: picked,
                  ),
                );
              }
            },
          ),
      ],
    );
  }
}
