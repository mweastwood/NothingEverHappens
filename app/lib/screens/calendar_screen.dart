import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/app_clock.dart';
import '../logic/auth_repository.dart';
import '../logic/calendar_day_task.dart' as calendar_logic;
import '../logic/civil_day.dart';
import '../logic/l10n_extension.dart';
import '../logic/label_repository.dart';
import '../logic/task_instance.dart';
import '../logic/task_label.dart';
import '../logic/task_repository.dart';
import '../logic/task_schedule.dart';
import '../logic/user_settings.dart';
import '../logic/user_settings_repository.dart';
import '../widgets/calendar_day_pane.dart';
import '../widgets/calendar_day_timeline_view.dart';
import '../widgets/calendar_month_card.dart';

export '../logic/calendar_day_task.dart';
export '../widgets/calendar_day_details_sheet.dart';
export '../widgets/calendar_day_pane.dart';
export '../widgets/calendar_day_timeline_view.dart';
export '../widgets/calendar_month_card.dart';
export '../widgets/calendar_task_details_sheet.dart';

/// Screen displaying a split calendar view with a calm label-dot month grid
/// paired with a live selected-day Agenda / Timeline pane.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();

  /// Computes a mapping of [CivilDay] to tasks (both concrete instances and projected recurring schedules)
  /// for the specified [monthDate].
  @visibleForTesting
  static Map<CivilDay, List<calendar_logic.CalendarDayTask>>
  computeMonthTaskMap(
    DateTime monthDate,
    List<TaskInstance> instances,
    List<TaskSchedule> schedules, {
    String? currentUserId,
    CivilDay? today,
  }) {
    return calendar_logic.computeMonthTaskMap(
      monthDate: monthDate,
      instances: instances,
      schedules: schedules,
      currentUserId: currentUserId,
      today: today,
    );
  }
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  static const int _pastMonths = 12;
  static const int _futureMonths = 24;

  late final DateTime _initialNow;
  late final List<DateTime> _months;
  late final int _currentMonthIndex;
  late final PageController _monthPageController;

  late int _visibleMonthIndex;
  late CivilDay _selectedDay;
  CalendarDayPaneMode _paneMode = CalendarDayPaneMode.agenda;
  bool _isTimelineExpanded = false;

  @override
  void initState() {
    super.initState();
    _initialNow = AppClock.now;
    _months = [
      for (int i = -_pastMonths; i <= _futureMonths; i++)
        DateTime(_initialNow.year, _initialNow.month + i, 1),
    ];
    _currentMonthIndex = _pastMonths;
    _visibleMonthIndex = _currentMonthIndex;
    _selectedDay = CivilDay.fromDateTime(_initialNow);
    _monthPageController = PageController(initialPage: _currentMonthIndex);
  }

  @override
  void dispose() {
    _monthPageController.dispose();
    super.dispose();
  }

  int _getWeeksInMonth(DateTime monthDate, FirstDayOfWeek firstDayOfWeek) {
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final firstWeekday = DateTime(
      monthDate.year,
      monthDate.month,
      1,
    ).weekday; // 1=Mon, 7=Sun
    final leadingEmptyCount = firstDayOfWeek.getLeadingEmptySlots(firstWeekday);
    final totalSlots = leadingEmptyCount + daysInMonth;
    return (totalSlots / 7).ceil();
  }

  int? _indexForMonth(int year, int month) {
    for (int i = 0; i < _months.length; i++) {
      if (_months[i].year == year && _months[i].month == month) {
        return i;
      }
    }
    return null;
  }

  void _selectDay(CivilDay day) {
    setState(() {
      _selectedDay = day;
    });
  }

  void _onTimelineDayChanged(CivilDay day) {
    final targetMonthIdx = _indexForMonth(day.year, day.month);
    setState(() {
      _selectedDay = day;
      if (targetMonthIdx != null) {
        _visibleMonthIndex = targetMonthIdx;
      }
    });
    if (targetMonthIdx != null &&
        _monthPageController.hasClients &&
        _monthPageController.page?.round() != targetMonthIdx) {
      _monthPageController.jumpToPage(targetMonthIdx);
    }
  }

  void _onMonthPageChanged(int index, CivilDay today) {
    final monthDate = _months[index];
    CivilDay nextSelected = _selectedDay;
    if (_selectedDay.year != monthDate.year ||
        _selectedDay.month != monthDate.month) {
      if (monthDate.year == today.year && monthDate.month == today.month) {
        nextSelected = today;
      } else {
        final daysInMonth = DateTime(
          monthDate.year,
          monthDate.month + 1,
          0,
        ).day;
        final clampedDay = _selectedDay.day.clamp(1, daysInMonth);
        nextSelected = CivilDay(
          year: monthDate.year,
          month: monthDate.month,
          day: clampedDay,
        );
      }
    }
    setState(() {
      _visibleMonthIndex = index;
      _selectedDay = nextSelected;
    });
  }

  void _goToMonthIndex(int targetIndex, {bool animate = true}) {
    final clamped = targetIndex.clamp(0, _months.length - 1);
    if (!_monthPageController.hasClients) {
      setState(() => _visibleMonthIndex = clamped);
      return;
    }
    if (animate) {
      _monthPageController.animateToPage(
        clamped,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } else {
      _monthPageController.jumpToPage(clamped);
    }
  }

  void _jumpToToday(CivilDay today) {
    final targetIndex =
        _indexForMonth(today.year, today.month) ?? _currentMonthIndex;
    setState(() {
      _selectedDay = today;
      _visibleMonthIndex = targetIndex;
    });
    _goToMonthIndex(targetIndex, animate: true);
  }

  void _expandTimeline() {
    setState(() {
      _isTimelineExpanded = true;
    });
  }

  void _collapseTimeline() {
    setState(() {
      _isTimelineExpanded = false;
    });
  }

  Map<CivilDay, List<calendar_logic.CalendarDayTask>> _getMonthTaskMap(
    DateTime monthDate,
    List<TaskInstance> instances,
    List<TaskSchedule> schedules, {
    required CivilDay today,
    String? currentUserId,
  }) {
    final cache = ref.read(calendar_logic.calendarMonthTaskCacheProvider);
    return cache.getMonthTaskMap(
      monthDate: monthDate,
      instances: instances,
      schedules: schedules,
      currentUserId: currentUserId,
      today: today,
    );
  }

  @override
  Widget build(BuildContext context) {
    final instancesVal = ref.watch(taskInstancesProvider);
    final schedulesVal = ref.watch(taskSchedulesProvider);
    final settingsVal = ref.watch(userSettingsProvider);

    if (instancesVal.isLoading || schedulesVal.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final instances = instancesVal.value ?? [];
    final schedules = schedulesVal.value ?? [];
    final currentUserId = ref.watch(authStateProvider).value?.uid;
    final userSettings = settingsVal.value;
    final firstDayOfWeek =
        userSettings?.firstDayOfWeek ?? FirstDayOfWeek.sunday;
    final labelsMap = ref.watch(allLabelsMapProvider);

    final today = CivilDay.fromDateTime(AppClock.now);
    final monthCache = ref.read(calendar_logic.calendarMonthTaskCacheProvider);

    final selectedMonthDate = DateTime(_selectedDay.year, _selectedDay.month);
    final selectedMonthMap = _getMonthTaskMap(
      selectedMonthDate,
      instances,
      schedules,
      today: today,
      currentUserId: currentUserId,
    );
    final selectedDayTasks = selectedMonthMap[_selectedDay] ?? const [];

    final dayPane = CalendarDayPane(
      selectedDay: _selectedDay,
      today: today,
      dayTasks: selectedDayTasks,
      instances: instances,
      schedules: schedules,
      currentUserId: currentUserId,
      labelsMap: labelsMap,
      userSettings: userSettings,
      monthTaskCache: monthCache,
      mode: _paneMode,
      onModeChanged: (mode) => setState(() => _paneMode = mode),
      onDayChanged: _onTimelineDayChanged,
      onExpandTimeline: _expandTimeline,
    );

    return PopScope(
      canPop: !_isTimelineExpanded,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isTimelineExpanded) {
          _collapseTimeline();
        }
      },
      child: Stack(
        children: [
          Offstage(
            offstage: _isTimelineExpanded,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final useHorizontalSplit = constraints.maxWidth >= 640.0;
                final monthPane = _buildMonthPane(
                  context,
                  instances: instances,
                  schedules: schedules,
                  today: today,
                  currentUserId: currentUserId,
                  firstDayOfWeek: firstDayOfWeek,
                  labelsMap: labelsMap,
                  userSettings: userSettings,
                  isWide: useHorizontalSplit,
                );

                if (useHorizontalSplit) {
                  final leftWidth = (constraints.maxWidth * 0.42).clamp(
                    280.0,
                    380.0,
                  );
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: leftWidth,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                          child: monthPane,
                        ),
                      ),
                      const VerticalDivider(width: 1, thickness: 0.5),
                      Expanded(child: dayPane),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                      child: monthPane,
                    ),
                    const Divider(height: 1, thickness: 0.5),
                    Expanded(child: dayPane),
                  ],
                );
              },
            ),
          ),
          if (_isTimelineExpanded)
            CalendarDayTimelineView(
              initialDay: _selectedDay,
              onBackToMonth: _collapseTimeline,
              onDayChanged: _onTimelineDayChanged,
              instances: instances,
              schedules: schedules,
              currentUserId: currentUserId,
              today: today,
              monthTaskCache: monthCache,
            ),
        ],
      ),
    );
  }

  Widget _buildMonthPane(
    BuildContext context, {
    required List<TaskInstance> instances,
    required List<TaskSchedule> schedules,
    required CivilDay today,
    required String? currentUserId,
    required FirstDayOfWeek firstDayOfWeek,
    required Map<String, TaskLabel> labelsMap,
    required UserSettings? userSettings,
    required bool isWide,
  }) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final activeMonth = _months[_visibleMonthIndex];
    final monthTitle = DateFormat.yMMMM(locale).format(activeMonth);
    final isCurrentMonth =
        activeMonth.year == today.year && activeMonth.month == today.month;

    final rowCount = _getWeeksInMonth(activeMonth, firstDayOfWeek);
    final cellHeight = isWide
        ? CalendarMonthCard.wideCellHeight
        : CalendarMonthCard.narrowCellHeight;
    // Weekday headers + divider + vertical padding + day rows
    final gridHeight = 36.0 + (rowCount * cellHeight);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Month Navigation Header
        Row(
          children: [
            IconButton(
              key: const Key('calendar_previous_month_button'),
              icon: const Icon(Icons.chevron_left, size: 22),
              visualDensity: VisualDensity.compact,
              tooltip: context.l10n.calendarPreviousMonth,
              onPressed: _visibleMonthIndex > 0
                  ? () => _goToMonthIndex(_visibleMonthIndex - 1)
                  : null,
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      monthTitle,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isCurrentMonth
                            ? theme.colorScheme.primary
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              key: const Key('calendar_next_month_button'),
              icon: const Icon(Icons.chevron_right, size: 22),
              visualDensity: VisualDensity.compact,
              tooltip: context.l10n.calendarNextMonth,
              onPressed: _visibleMonthIndex < _months.length - 1
                  ? () => _goToMonthIndex(_visibleMonthIndex + 1)
                  : null,
            ),
            TextButton(
              key: const Key('calendar_jump_to_today_button'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 32),
              ),
              onPressed: () => _jumpToToday(today),
              child: Text(context.l10n.calendarJumpToToday),
            ),
          ],
        ),
        // Swipeable Month Grid
        SizedBox(
          height: gridHeight,
          child: PageView.builder(
            key: const PageStorageKey<String>('calendar_month_pager'),
            controller: _monthPageController,
            itemCount: _months.length,
            onPageChanged: (index) => _onMonthPageChanged(index, today),
            itemBuilder: (context, index) {
              final monthDate = _months[index];
              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: CalendarMonthCard(
                  monthDate: monthDate,
                  dayTaskMap: _getMonthTaskMap(
                    monthDate,
                    instances,
                    schedules,
                    today: today,
                    currentUserId: currentUserId,
                  ),
                  today: today,
                  selectedDay: _selectedDay,
                  isWide: isWide,
                  showMonthHeader: false,
                  firstDayOfWeek: firstDayOfWeek,
                  labelsMap: labelsMap,
                  userSettings: userSettings,
                  onDayTap: _selectDay,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
