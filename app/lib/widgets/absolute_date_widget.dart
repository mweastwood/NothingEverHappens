import 'package:flutter/material.dart';

/// A widget that allows users to select a specific date.
///
/// It visually mimics the compact date container used in absolute/relative time selections.
class AbsoluteDateWidget extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime>? onDateChanged;
  final String label;

  const AbsoluteDateWidget({
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isReadOnly
              ? null
              : () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (picked != null) {
                    onDateChanged!(picked);
                  }
                },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                      Text(
                        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
