import 'package:flutter/material.dart';

class ServingsStepperRow extends StatelessWidget {
  final int servings;
  final ValueChanged<int> onChanged;
  final String label;
  final int minServings;
  final double iconSpacing;

  const ServingsStepperRow({
    super.key,
    required this.servings,
    required this.onChanged,
    this.label = 'Servings:',
    this.minServings = 1,
    this.iconSpacing = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Icon(Icons.people_outline),
        SizedBox(width: iconSpacing),
        Text(label, style: theme.textTheme.titleMedium),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: servings > minServings
              ? () => onChanged(servings - 1)
              : null,
        ),
        Text(
          '$servings',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onChanged(servings + 1),
        ),
      ],
    );
  }
}

class ServingsStepperCard extends StatelessWidget {
  final int servings;
  final ValueChanged<int> onChanged;
  final String label;
  final int minServings;
  final EdgeInsetsGeometry padding;
  final double iconSpacing;

  const ServingsStepperCard({
    super.key,
    required this.servings,
    required this.onChanged,
    this.label = 'Servings:',
    this.minServings = 1,
    this.padding = const EdgeInsets.all(12),
    this.iconSpacing = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: ServingsStepperRow(
          servings: servings,
          onChanged: onChanged,
          label: label,
          minServings: minServings,
          iconSpacing: iconSpacing,
        ),
      ),
    );
  }
}
