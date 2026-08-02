import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final showSortBarProvider = StateProvider<bool>((ref) => true);

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
      width: double.infinity,
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

class FloatingSortCard extends StatelessWidget {
  final Widget child;

  const FloatingSortCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 0.0),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 4.0,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        color: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class AnimatedFloatingSortBar extends StatefulWidget {
  final bool visible;
  final Widget child;

  const AnimatedFloatingSortBar({
    super.key,
    required this.visible,
    required this.child,
  });

  @override
  State<AnimatedFloatingSortBar> createState() =>
      _AnimatedFloatingSortBarState();
}

class _AnimatedFloatingSortBarState extends State<AnimatedFloatingSortBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );
    if (widget.visible) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedFloatingSortBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _animation,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: _animation, child: widget.child),
    );
  }
}
