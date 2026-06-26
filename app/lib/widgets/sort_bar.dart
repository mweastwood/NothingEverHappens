import 'package:flutter/material.dart';

class SortOption {
  final String key;
  final String label;

  const SortOption({required this.key, required this.label});
}

class SortBar extends StatelessWidget {
  final String title;
  final String sortColumn;
  final bool sortAscending;
  final List<SortOption> options;
  final ValueChanged<String> onSort;

  const SortBar({
    super.key,
    required this.title,
    required this.sortColumn,
    required this.sortAscending,
    required this.options,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 48.0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Row(
          children: [
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            ...options.map((option) {
              final isSelected = sortColumn == option.key;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(option.label),
                  selected: isSelected,
                  showCheckmark: false,
                  avatar: isSelected
                      ? Icon(
                          sortAscending
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          size: 14,
                        )
                      : null,
                  onSelected: (_) => onSort(option.key),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
