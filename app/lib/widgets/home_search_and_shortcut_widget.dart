import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/task_list_screen.dart'; // for taskSearchQueryProvider
import '../screens/task_schedule_screen.dart'; // for scheduleSearchQueryProvider
import '../screens/help_screen.dart';
import '../logic/l10n_extension.dart';

import '../widgets/sort_bar.dart';

class HomeSearchAndShortcutWidget extends ConsumerStatefulWidget {
  final int currentIndex;
  final Widget Function(
    BuildContext context,
    bool isSearching,
    PreferredSizeWidget appBar,
  )
  builder;

  const HomeSearchAndShortcutWidget({
    super.key,
    required this.currentIndex,
    required this.builder,
  });

  @override
  ConsumerState<HomeSearchAndShortcutWidget> createState() =>
      _HomeSearchAndShortcutWidgetState();
}

class _HomeSearchAndShortcutWidgetState
    extends ConsumerState<HomeSearchAndShortcutWidget> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    if (widget.currentIndex == 0) {
      ref.read(taskSearchQueryProvider.notifier).state = '';
    } else if (widget.currentIndex == 1) {
      ref.read(scheduleSearchQueryProvider.notifier).state = '';
    }
  }

  void _closeSearch() {
    setState(() {
      _isSearching = false;
    });
    _clearSearch();
  }

  void _openSearch() {
    setState(() {
      _isSearching = true;
    });
    _searchFocusNode.requestFocus();
  }

  @override
  void didUpdateWidget(covariant HomeSearchAndShortcutWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex && _isSearching) {
      _closeSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(taskSearchQueryProvider, (previous, next) {
      if (widget.currentIndex == 0 && _searchController.text != next) {
        _searchController.text = next;
      }
    });
    ref.listen<String>(scheduleSearchQueryProvider, (previous, next) {
      if (widget.currentIndex == 1 && _searchController.text != next) {
        _searchController.text = next;
      }
    });

    final PreferredSizeWidget appBar = AppBar(
      title: _isSearching
          ? TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: widget.currentIndex == 0
                    ? context.l10n.searchTasksPlaceholder
                    : context.l10n.searchSchedulesPlaceholder,
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                border: InputBorder.none,
              ),
              onChanged: (value) {
                if (widget.currentIndex == 0) {
                  ref.read(taskSearchQueryProvider.notifier).state = value;
                } else if (widget.currentIndex == 1) {
                  ref.read(scheduleSearchQueryProvider.notifier).state = value;
                }
              },
            )
          : Text(context.l10n.appName),
      leading: _isSearching
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _closeSearch,
            )
          : null,
      actions: [
        if (_isSearching)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _clearSearch();
              _searchFocusNode.requestFocus();
            },
          )
        else if (widget.currentIndex == 0 || widget.currentIndex == 1) ...[
          IconButton(
            icon: Icon(
              ref.watch(showSortBarProvider) ? Icons.sort : Icons.sort_outlined,
              color: ref.watch(showSortBarProvider)
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: ref.watch(showSortBarProvider)
                ? context.l10n.hideSortOptions
                : context.l10n.showSortOptions,
            onPressed: () {
              ref.read(showSortBarProvider.notifier).state = !ref.read(
                showSortBarProvider,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: context.l10n.helpTooltip,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HelpScreen(
                    initialIndex: widget.currentIndex == 0 ? 0 : 1,
                  ),
                ),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.search), onPressed: _openSearch),
        ],
      ],
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.slash): () {
          final primaryFocus = FocusManager.instance.primaryFocus;
          final isEditableFocused =
              primaryFocus?.context?.widget is EditableText;
          if ((widget.currentIndex == 0 || widget.currentIndex == 1) &&
              !_isSearching &&
              !isEditableFocused) {
            _openSearch();
          }
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_isSearching) {
            _closeSearch();
          }
        },
      },
      child: Focus(
        autofocus: true,
        child: PopScope(
          canPop: !_isSearching,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_isSearching) {
              _closeSearch();
            }
          },
          child: widget.builder(context, _isSearching, appBar),
        ),
      ),
    );
  }
}
