import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';
import '../logic/l10n_extension.dart';
import '../logic/user_settings_repository.dart';
import '../screens/home_screen.dart';
import 'unsynced_banner.dart';

final taskListSortBarOverrideProvider = StateProvider<bool?>((ref) => null);
final scheduleListSortBarOverrideProvider = StateProvider<bool?>((ref) => null);

final showTaskListSortBarProvider = Provider<bool>((ref) {
  final override = ref.watch(taskListSortBarOverrideProvider);
  if (override != null) return override;
  final settings = ref.watch(userSettingsProvider).value;
  return settings?.showTaskListSortBar ?? true;
});

final showScheduleListSortBarProvider = Provider<bool>((ref) {
  final override = ref.watch(scheduleListSortBarOverrideProvider);
  if (override != null) return override;
  final settings = ref.watch(userSettingsProvider).value;
  return settings?.showScheduleListSortBar ?? true;
});

final showSortBarProvider = Provider<bool>((ref) {
  final tabIndex = ref.watch(homeTabIndexProvider);
  if (tabIndex == 1) {
    return ref.watch(showScheduleListSortBarProvider);
  }
  return ref.watch(showTaskListSortBarProvider);
});

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
  final List<Widget>? filterChips;
  final VoidCallback? onOpenFilterSheet;
  final int activeFilterCount;
  final VoidCallback? onClearFilters;

  const SortBar({
    super.key,
    required this.title,
    required this.sortColumn,
    required this.sortAscending,
    required this.options,
    required this.onSort,
    this.filterChips,
    this.onOpenFilterSheet,
    this.activeFilterCount = 0,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasFilters =
        onOpenFilterSheet != null ||
        (filterChips != null && filterChips!.isNotEmpty);

    final filterBtnLabel = hasFilters
        ? (activeFilterCount > 0
              ? '${context.l10n.filterButtonLabel} ($activeFilterCount)'
              : context.l10n.filterButtonLabel)
        : '';
    final clearBtnLabel = hasFilters ? context.l10n.presetClear : '';

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
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
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
            if (hasFilters) ...[
              const SizedBox(width: 4),
              SizedBox(
                height: 24,
                child: VerticalDivider(
                  width: 16,
                  thickness: 1,
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (onOpenFilterSheet != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    avatar: Icon(
                      activeFilterCount > 0
                          ? Icons.filter_alt
                          : Icons.filter_alt_outlined,
                      size: 14,
                    ),
                    label: Text(filterBtnLabel),
                    selected: activeFilterCount > 0,
                    showCheckmark: false,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => onOpenFilterSheet!(),
                  ),
                ),
              ...?filterChips,
              if (activeFilterCount > 0 && onClearFilters != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    avatar: const Icon(Icons.close, size: 14),
                    label: Text(clearBtnLabel),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    onPressed: onClearFilters,
                  ),
                ),
            ],
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

/// A reusable scroll view layout for screens that feature an [AnimatedFloatingSortBar]
/// over a [CustomScrollView].
///
/// Ensures consistent behavior between screens:
/// - When scrolled to top (offset <= 5.0), toggling sort bar visibility smoothly
///   slides content down/up via an [AnimatedContainer] top spacer.
/// - When scrolled down (offset > 5.0), toggling sort bar visibility updates the
///   top spacer instantly (duration 0) and jumps the [ScrollController] by
///   [barHeight], keeping on-screen content stationary.
class SortBarScrollView extends ConsumerWidget {
  final ScrollController controller;
  final Key? scrollKey;
  final ProviderListenable<bool> isSortBarVisibleProvider;
  final bool showSortBar;
  final double barHeight;
  final Widget sortBar;
  final List<Widget> slivers;
  final List<Widget>? leadingSlivers;

  const SortBarScrollView({
    super.key,
    required this.controller,
    this.scrollKey,
    required this.isSortBarVisibleProvider,
    this.showSortBar = true,
    this.barHeight = 56.0,
    required this.sortBar,
    required this.slivers,
    this.leadingSlivers,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSortBarVisible = ref.watch(isSortBarVisibleProvider);

    ref.listen<bool>(isSortBarVisibleProvider, (previous, next) {
      if (previous != next && showSortBar && controller.hasClients) {
        final offset = controller.offset;
        if (next && offset > 5.0) {
          controller.jumpTo(offset + barHeight);
        } else if (!next && offset > barHeight + 5.0) {
          controller.jumpTo(offset - barHeight);
        }
      }
    });

    final actualLeadingSlivers =
        leadingSlivers ?? const [SliverToBoxAdapter(child: UnsyncedBanner())];

    return Stack(
      children: [
        CustomScrollView(
          key: scrollKey,
          controller: controller,
          slivers: [
            ...actualLeadingSlivers,
            SliverToBoxAdapter(
              child: AnimatedContainer(
                duration: (controller.hasClients && controller.offset > 5.0)
                    ? Duration.zero
                    : const Duration(milliseconds: 250),
                curve: Curves.fastOutSlowIn,
                height: (showSortBar && isSortBarVisible) ? barHeight : 0.0,
              ),
            ),
            ...slivers,
          ],
        ),
        if (showSortBar)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedFloatingSortBar(
              visible: isSortBarVisible,
              child: FloatingSortCard(child: sortBar),
            ),
          ),
      ],
    );
  }
}
