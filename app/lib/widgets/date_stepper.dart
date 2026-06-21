import 'package:flutter/material.dart';

class DateStepper extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime>? onDateChanged;
  final String label;

  const DateStepper({
    super.key,
    required this.date,
    this.onDateChanged,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReadOnly = onDateChanged == null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          IconButton(
            key: const Key('date_decrement_button'),
            icon: const Icon(Icons.remove),
            onPressed: isReadOnly
                ? null
                : () {
                    final newDate = date.subtract(const Duration(days: 1));
                    onDateChanged!(newDate);
                  },
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            constraints: const BoxConstraints(),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const Key('start_recurrence_date_tile'),
                onTap: isReadOnly
                    ? null
                    : () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365 * 5),
                          ),
                        );
                        if (picked != null) {
                          onDateChanged!(picked);
                        }
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.calendar_today,
                              color: theme.colorScheme.primary,
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            key: const Key('date_increment_button'),
            icon: const Icon(Icons.add),
            onPressed: isReadOnly
                ? null
                : () {
                    final newDate = date.add(const Duration(days: 1));
                    onDateChanged!(newDate);
                  },
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
