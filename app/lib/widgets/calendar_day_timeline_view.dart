import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/app_clock.dart';
import '../logic/calendar_day_task.dart';
import '../logic/civil_day.dart';
import '../logic/l10n_extension.dart';
import '../logic/task_instance.dart';
import '../logic/task_repository.dart';
import '../logic/task_schedule.dart';
import '../screens/create_task_screen.dart';
import 'app_snackbar.dart';
import 'calendar_day_details_sheet.dart';
import 'calendar_month_card.dart';

/// Interactive daily timeline view displaying tasks from midnight to midnight (00:00 - 24:00).
/// Supports horizontal swiping between days with peeking on mobile and multi-day (up to 7 days)
/// side-by-side display on wide screens.
class CalendarDayTimelineView extends ConsumerStatefulWidget {
  final CivilDay initialDay;
  final VoidCallback onBackToMonth;
  final List<TaskInstance> instances;
  final List<TaskSchedule> schedules;
  final String? currentUserId;
  final CivilDay today;

  const CalendarDayTimelineView({
    super.key,
    required this.initialDay,
    required this.onBackToMonth,
    required this.instances,
    required this.schedules,
    this.currentUserId,
    required this.today,
  });

  @override
  ConsumerState<CalendarDayTimelineView> createState() =>
      CalendarDayTimelineViewState();
}

class CalendarDayTimelineViewState
    extends ConsumerState<CalendarDayTimelineView> {
  static final DateTime _anchorDate = DateTime.utc(2000, 1, 1);
  static const double _hourHeight = 60.0;
  static const double _hourGutterWidth = 52.0;

  late int _currentPageIndex;
  late ScrollController _verticalScrollController;
  PageController? _pageController;
  PageController? _headerController;

  int _visibleDays = 1;
  double _viewportFraction = 0.85;
  bool _hasScrolledInitially = false;

  final Map<DateTime, Map<CivilDay, List<CalendarDayTask>>> _monthTaskMapCache =
      {};

  static int dayToIndex(CivilDay day) {
    return day.toUtcDateTime().difference(_anchorDate).inDays;
  }

  static CivilDay indexToDay(int index) {
    final dt = _anchorDate.add(Duration(days: index));
    return CivilDay.fromDateTime(dt);
  }

  @override
  void initState() {
    super.initState();
    _currentPageIndex = dayToIndex(widget.initialDay);
    _verticalScrollController = ScrollController();
    _pageController = PageController(
      initialPage: _currentPageIndex,
      viewportFraction: _viewportFraction,
    );
    _headerController = PageController(
      initialPage: _currentPageIndex,
      viewportFraction: _viewportFraction,
    );
    _pageController!.addListener(_onPageScroll);
  }

  @visibleForTesting
  int get visibleDays => _visibleDays;

  @visibleForTesting
  double get viewportFraction => _viewportFraction;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenWidth = MediaQuery.sizeOf(context).width;
    _updateControllers(screenWidth);
  }

  @override
  void didUpdateWidget(covariant CalendarDayTimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.instances, oldWidget.instances) ||
        !identical(widget.schedules, oldWidget.schedules) ||
        widget.currentUserId != oldWidget.currentUserId ||
        widget.today != oldWidget.today) {
      _monthTaskMapCache.clear();
    }
  }

  @override
  void dispose() {
    _pageController?.removeListener(_onPageScroll);
    _verticalScrollController.dispose();
    _pageController?.dispose();
    _headerController?.dispose();
    super.dispose();
  }

  void _updateControllers(double screenWidth) {
    final int newVisibleDays;
    final double newViewportFraction;

    if (screenWidth >= 1150) {
      newVisibleDays = 7;
      newViewportFraction = 1.0 / 7;
    } else if (screenWidth >= 850) {
      newVisibleDays = 5;
      newViewportFraction = 1.0 / 5;
    } else if (screenWidth >= 600) {
      newVisibleDays = 3;
      newViewportFraction = 1.0 / 3;
    } else {
      newVisibleDays = 1;
      newViewportFraction = 0.85;
    }

    if (_visibleDays != newVisibleDays ||
        (_viewportFraction - newViewportFraction).abs() > 0.001) {
      _visibleDays = newVisibleDays;
      _viewportFraction = newViewportFraction;

      final oldPageController = _pageController;
      final oldHeaderController = _headerController;
      oldPageController?.removeListener(_onPageScroll);

      _pageController = PageController(
        initialPage: _currentPageIndex,
        viewportFraction: _viewportFraction,
      );
      _headerController = PageController(
        initialPage: _currentPageIndex,
        viewportFraction: _viewportFraction,
      );

      _pageController!.addListener(_onPageScroll);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldPageController?.dispose();
        oldHeaderController?.dispose();
      });
    }
  }

  void _onPageScroll() {
    if (_headerController != null &&
        _headerController!.hasClients &&
        _pageController != null &&
        _pageController!.hasClients) {
      if ((_headerController!.offset - _pageController!.offset).abs() > 0.1) {
        _headerController!.jumpTo(_pageController!.offset);
      }
    }
  }

  List<CalendarDayTask> _getTasksForDay(CivilDay day) {
    final monthDate = DateTime(day.year, day.month, 1);
    final monthMap = _monthTaskMapCache.putIfAbsent(
      monthDate,
      () => computeMonthTaskMap(
        monthDate: monthDate,
        instances: widget.instances,
        schedules: widget.schedules,
        currentUserId: widget.currentUserId,
        today: widget.today,
      ),
    );
    return monthMap[day] ?? const [];
  }

  void _initialScrollToRelevantTime() {
    if (_hasScrolledInitially || !_verticalScrollController.hasClients) return;
    _hasScrolledInitially = true;

    final initialDay = widget.initialDay;
    final isToday = initialDay == widget.today;
    final tasks = _getTasksForDay(initialDay);

    int earliestMinute = 7 * 60; // default 7:00 AM
    if (isToday) {
      final now = AppClock.now;
      final curMinute = now.hour * 60 + now.minute;
      earliestMinute = curMinute;
    }

    if (tasks.isNotEmpty) {
      final taskMins = tasks.map(_getStartMinute).toList()..sort();
      final earliestTaskMin = taskMins.first;
      if (isToday) {
        earliestMinute = min(earliestMinute, earliestTaskMin);
      } else {
        earliestMinute = earliestTaskMin;
      }
    }

    // Scroll ~60 minutes before the earliest time
    final maxScroll = _verticalScrollController.hasClients
        ? _verticalScrollController.position.maxScrollExtent
        : (24 * _hourHeight);
    final targetOffset = (earliestMinute - 60.0).clamp(0.0, maxScroll);
    _verticalScrollController.jumpTo(targetOffset);
  }

  void jumpToToday() {
    final todayIndex = dayToIndex(widget.today);
    _goToDayIndex(todayIndex);

    if (_verticalScrollController.hasClients) {
      final now = AppClock.now;
      final curMinute = now.hour * 60 + now.minute;
      final maxScroll = _verticalScrollController.position.maxScrollExtent;
      final targetOffset = (curMinute - 60.0).clamp(0.0, maxScroll);
      _verticalScrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _goToDayIndex(int index) {
    if (_pageController != null && _pageController!.hasClients) {
      _pageController!.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    } else {
      setState(() {
        _currentPageIndex = index;
      });
    }
  }

  void _goToPrevious() {
    final step = _visibleDays == 1 ? 1 : _visibleDays;
    _goToDayIndex(max(0, _currentPageIndex - step));
  }

  void _goToNext() {
    final step = _visibleDays == 1 ? 1 : _visibleDays;
    _goToDayIndex(_currentPageIndex + step);
  }

  int _getStartMinute(CalendarDayTask task) {
    if (task.instance != null) {
      final start = task.instance!.startRelativeTime;
      if (start.dayOffset < 0) return 0;
      if (start.dayOffset > 0) return 1440;
      return (start.hour * 60 + start.minute).clamp(0, 1440);
    } else if (task.matchingRule != null) {
      final start = task.matchingRule!.startRelativeTime;
      if (start.dayOffset < 0) return 0;
      if (start.dayOffset > 0) return 1440;
      return (start.hour * 60 + start.minute).clamp(0, 1440);
    }
    return 9 * 60;
  }

  int _getDueMinute(CalendarDayTask task) {
    if (task.instance != null) {
      final due = task.instance!.dueRelativeTime;
      if (due.dayOffset > 0) return 1440;
      if (due.dayOffset < 0) return 0;
      return (due.hour * 60 + due.minute).clamp(0, 1440);
    } else if (task.matchingRule != null) {
      final due = task.matchingRule!.dueRelativeTime;
      if (due.dayOffset > 0) return 1440;
      if (due.dayOffset < 0) return 0;
      return (due.hour * 60 + due.minute).clamp(0, 1440);
    }
    return 10 * 60;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final currentDay = indexToDay(_currentPageIndex);
    final monthYearTitle = DateFormat.yMMMM(
      locale,
    ).format(currentDay.toDateTime());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialScrollToRelevantTime();
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Column(
        children: [
          // Top Toolbar
          _buildTopToolbar(theme, monthYearTitle),
          const Divider(height: 1, thickness: 0.5),

          // Pinned Day Headers Row
          _buildPinnedDayHeaders(theme, locale),
          const Divider(height: 1, thickness: 0.5),

          // Vertical Scrollable 24-Hour Timeline
          Expanded(
            child: SingleChildScrollView(
              controller: _verticalScrollController,
              child: SizedBox(
                height: 24 * _hourHeight,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Hour Gutter
                    _buildHourGutter(theme, locale),

                    // Horizontal Day Pages
                    Expanded(
                      child: PageView.builder(
                        key: const Key('calendar_day_timeline_pageview'),
                        controller: _pageController,
                        onPageChanged: (pageIndex) {
                          setState(() {
                            _currentPageIndex = pageIndex;
                          });
                        },
                        itemBuilder: (context, dayIndex) {
                          final day = indexToDay(dayIndex);
                          final isToday = day == widget.today;
                          final tasks = _getTasksForDay(day);

                          return _buildDayColumn(theme, day, isToday, tasks);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopToolbar(ThemeData theme, String monthYearTitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          IconButton(
            key: const Key('calendar_back_to_month_button'),
            icon: const Icon(Icons.arrow_back),
            tooltip: context.l10n.calendarBackToMonth,
            onPressed: widget.onBackToMonth,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              monthYearTitle,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            tooltip: context.l10n.calendarPreviousDay,
            onPressed: _goToPrevious,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            tooltip: context.l10n.calendarNextDay,
            onPressed: _goToNext,
          ),
          TextButton.icon(
            key: const Key('calendar_timeline_today_button'),
            icon: const Icon(Icons.today, size: 18),
            label: Text(context.l10n.calendarJumpToToday),
            onPressed: jumpToToday,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: context.l10n.addTaskTooltip,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const CreateTaskScreen(defaultToRepeating: false),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedDayHeaders(ThemeData theme, String locale) {
    return SizedBox(
      height: 58,
      child: Row(
        children: [
          SizedBox(
            width: _hourGutterWidth,
            child: Center(
              child: Icon(
                Icons.schedule,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
              ),
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _headerController,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, dayIndex) {
                final day = indexToDay(dayIndex);
                final isToday = day == widget.today;
                final tasks = _getTasksForDay(day);

                final weekdayStr = DateFormat.E(
                  locale,
                ).format(day.toDateTime());

                return InkWell(
                  key: Key(
                    'timeline_day_header_${day.year}_${day.month}_${day.day}',
                  ),
                  onTap: () => CalendarDayDetailsSheet.show(context, day: day),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: isToday
                            ? theme.colorScheme.primaryContainer.withValues(
                                alpha: 0.3,
                              )
                            : null,
                        border: isToday
                            ? Border.all(
                                color: theme.colorScheme.primary,
                                width: 1.5,
                              )
                            : Border.all(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            weekdayStr.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isToday
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${day.day}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.w600,
                                  color: isToday
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                              if (tasks.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${tasks.length}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: theme
                                          .colorScheme
                                          .onSecondaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourGutter(ThemeData theme, String locale) {
    return SizedBox(
      width: _hourGutterWidth,
      height: 24 * _hourHeight,
      child: Stack(
        children: [
          for (int h = 0; h <= 24; h++) ...[
            Positioned(
              top: h * _hourHeight - 8,
              left: 4,
              right: 4,
              child: Text(
                _formatHour(h, locale),
                textAlign: TextAlign.right,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatHour(int hour, String locale) {
    final dt = DateTime(2000, 1, 1, hour % 24);
    return DateFormat.j(locale).format(dt);
  }

  Widget _buildDayColumn(
    ThemeData theme,
    CivilDay day,
    bool isToday,
    List<CalendarDayTask> tasks,
  ) {
    final isMobilePeeking = _visibleDays == 1;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobilePeeking ? 4.0 : 2.0),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: isMobilePeeking ? BorderRadius.circular(12) : null,
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.5,
            ),
            right: isMobilePeeking
                ? BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.3,
                    ),
                    width: 0.5,
                  )
                : BorderSide.none,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columnWidth = constraints.maxWidth;

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Hour Grid Lines
                for (int h = 0; h <= 24; h++) ...[
                  Positioned(
                    top: h * _hourHeight,
                    left: 0,
                    right: 0,
                    child: Divider(
                      height: 1,
                      thickness: 0.5,
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.35,
                      ),
                    ),
                  ),
                  if (h < 24)
                    Positioned(
                      top: (h + 0.5) * _hourHeight,
                      left: 0,
                      right: 0,
                      child: Divider(
                        height: 1,
                        thickness: 0.25,
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.15,
                        ),
                      ),
                    ),
                ],

                // Current Time Red/Primary Indicator Line
                if (isToday) _buildCurrentTimeIndicator(theme),

                // Layout Overlapping Tasks
                ..._layoutTimelineTasks(theme, day, tasks, columnWidth),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCurrentTimeIndicator(ThemeData theme) {
    final now = AppClock.now;
    final curMin = now.hour * 60 + now.minute;
    final top = curMin * 1.0;

    return Positioned(
      top: top - 4,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.primary,
            ),
          ),
          Expanded(
            child: Container(height: 2, color: theme.colorScheme.primary),
          ),
        ],
      ),
    );
  }

  List<Widget> _layoutTimelineTasks(
    ThemeData theme,
    CivilDay day,
    List<CalendarDayTask> tasks,
    double availableWidth,
  ) {
    if (tasks.isEmpty) return const [];

    // Calculate start, due and effective duration for each task
    final List<_TaskTimeBounds> bounds = [];
    for (final task in tasks) {
      final startMin = _getStartMinute(task);
      int dueMin = _getDueMinute(task);
      if (dueMin <= startMin) {
        dueMin = (startMin + 30).clamp(0, 1440);
      }
      bounds.add(
        _TaskTimeBounds(task: task, startMinute: startMin, dueMinute: dueMin),
      );
    }

    // Sort by start minute, then duration descending
    bounds.sort((a, b) {
      final cmp = a.startMinute.compareTo(b.startMinute);
      if (cmp != 0) return cmp;
      return (b.dueMinute - b.startMinute).compareTo(
        a.dueMinute - a.startMinute,
      );
    });

    // Group into clusters of overlapping tasks
    final List<List<_TaskTimeBounds>> clusters = [];
    List<_TaskTimeBounds> currentCluster = [];
    int clusterEnd = -1;

    for (final b in bounds) {
      if (currentCluster.isEmpty || b.startMinute < clusterEnd) {
        currentCluster.add(b);
        clusterEnd = max(clusterEnd, b.dueMinute);
      } else {
        clusters.add(currentCluster);
        currentCluster = [b];
        clusterEnd = b.dueMinute;
      }
    }
    if (currentCluster.isNotEmpty) {
      clusters.add(currentCluster);
    }

    final List<Widget> widgets = [];

    for (final cluster in clusters) {
      // Allocate columns within cluster
      final List<int> columnEndTimes = [];
      final Map<_TaskTimeBounds, int> columnAssignments = {};

      for (final b in cluster) {
        int assignedCol = -1;
        for (int c = 0; c < columnEndTimes.length; c++) {
          if (columnEndTimes[c] <= b.startMinute) {
            assignedCol = c;
            columnEndTimes[c] = b.dueMinute;
            break;
          }
        }
        if (assignedCol == -1) {
          assignedCol = columnEndTimes.length;
          columnEndTimes.add(b.dueMinute);
        }
        columnAssignments[b] = assignedCol;
      }

      final totalCols = max(1, columnEndTimes.length);
      final colWidth = (availableWidth - 4.0) / totalCols;

      for (final b in cluster) {
        final colIndex = columnAssignments[b] ?? 0;
        final left = 2.0 + colIndex * colWidth;
        final width = max(30.0, colWidth - 2.0);

        final rawHeight = (b.dueMinute - b.startMinute) * 1.0;
        final height = max(36.0, rawHeight);
        final top = (b.startMinute * 1.0)
            .clamp(0.0, max(0.0, 1440.0 - height))
            .toDouble();

        widgets.add(
          Positioned(
            left: left,
            width: width,
            top: top,
            height: height,
            child: _buildTaskCard(theme, day, b.task, height, width),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildTaskCard(
    ThemeData theme,
    CivilDay day,
    CalendarDayTask task,
    double cardHeight,
    double cardWidth,
  ) {
    final priorityColor = getPriorityColor(theme.colorScheme, task.priority);
    final timeWindow = task.getTimeWindow(context);

    return Card(
      key: Key('timeline_task_${task.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 1.0, vertical: 1.0),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: priorityColor.withValues(alpha: 0.5), width: 1),
      ),
      color: task.isCompleted
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
          : priorityColor.withValues(alpha: 0.12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => CalendarDayDetailsSheet.show(context, day: day),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left priority stripe
            Container(width: 4, color: priorityColor),
            const SizedBox(width: 4),

            // Checkbox / Repeat Icon
            if (cardWidth >= 50) ...[
              Center(
                child: task.isInstance
                    ? IconButton(
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: const Size(20, 20),
                          padding: EdgeInsets.zero,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          maxWidth: 24,
                          minHeight: 20,
                          maxHeight: 24,
                        ),
                        icon: Icon(
                          task.isCompleted
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 16,
                          color: task.isCompleted
                              ? theme.colorScheme.primary
                              : priorityColor,
                        ),
                        onPressed: () async {
                          final repo = ref.read(taskRepositoryProvider);
                          if (repo != null && task.instance != null) {
                            try {
                              if (task.isCompleted) {
                                await repo.uncompleteTaskInstance(
                                  task.instance!.id,
                                );
                              } else {
                                await repo.completeTaskInstance(
                                  task.instance!.id,
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                AppSnackBar.show(
                                  context,
                                  content: Text(
                                    '${context.l10n.somethingWentWrong} $e',
                                  ),
                                );
                              }
                            }
                          }
                        },
                      )
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Icon(
                          Icons.event_repeat,
                          size: 14,
                          color: priorityColor,
                        ),
                      ),
              ),
              const SizedBox(width: 2),
            ],

            // Title and Time info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 2, right: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: cardWidth < 80 ? 10 : 11,
                        fontWeight: FontWeight.bold,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.isCompleted
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (timeWindow != null && cardHeight >= 42) ...[
                      const SizedBox(height: 1),
                      Text(
                        timeWindow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 9,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskTimeBounds {
  final CalendarDayTask task;
  final int startMinute;
  final int dueMinute;

  _TaskTimeBounds({
    required this.task,
    required this.startMinute,
    required this.dueMinute,
  });
}
