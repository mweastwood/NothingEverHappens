import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/app_clock.dart';
import '../logic/auth_repository.dart';
import '../logic/calendar_day_task.dart' as calendar_logic;
import '../logic/civil_day.dart';
import '../logic/l10n_extension.dart';
import '../logic/task_instance.dart';
import '../logic/task_repository.dart';
import '../logic/task_schedule.dart';
import '../logic/user_settings.dart';
import '../logic/user_settings_repository.dart';
import '../logic/utils/layout_breakpoints.dart';
import '../widgets/calendar_day_timeline_view.dart';
import '../widgets/calendar_month_card.dart';

export '../logic/calendar_day_task.dart';
export '../widgets/calendar_day_details_sheet.dart';
export '../widgets/calendar_day_timeline_view.dart';
export '../widgets/calendar_month_card.dart';

/// Screen displaying a scrollable calendar view of past and future months.
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
  ScrollController? _scrollController;
  late final DateTime _initialNow;
  late final List<DateTime> _months;
  late final int _currentMonthIndex;

  CivilDay? _zoomedDay;

  void _zoomToDay(CivilDay day) {
    setState(() {
      _zoomedDay = day;
    });
  }

  void _zoomOutToMonth() {
    setState(() {
      _zoomedDay = null;
    });
  }

  @override
  void initState() {
    super.initState();
    _initialNow = AppClock.now;

    // Generate 12 months in the past to 24 months in the future
    _months = [];
    const pastMonths = 12;
    const futureMonths = 24;

    for (int i = -pastMonths; i <= futureMonths; i++) {
      _months.add(DateTime(_initialNow.year, _initialNow.month + i, 1));
    }
    _currentMonthIndex = pastMonths;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scrollController == null) {
      final isWide = isWideScreen(context);
      final firstDayOfWeek =
          ref.read(userSettingsProvider).value?.firstDayOfWeek ??
          FirstDayOfWeek.sunday;
      final targetOffset = _calculateTargetOffset(
        isWide: isWide,
        firstDayOfWeek: firstDayOfWeek,
      );
      _scrollController = ScrollController(initialScrollOffset: targetOffset);
    }
  }

  @override
  void dispose() {
    _scrollController?.dispose();
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

  double _calculateTargetOffset({
    required bool isWide,
    required FirstDayOfWeek firstDayOfWeek,
  }) {
    if (isWide) {
      double offset = 16.0; // list top padding
      final targetRow = _currentMonthIndex ~/ 2;
      for (int r = 0; r < targetRow; r++) {
        final idx1 = r * 2;
        final idx2 = idx1 + 1;
        final weeks1 = _getWeeksInMonth(_months[idx1], firstDayOfWeek);
        final weeks2 = idx2 < _months.length
            ? _getWeeksInMonth(_months[idx2], firstDayOfWeek)
            : 0;
        final maxWeeks = weeks1 > weeks2 ? weeks1 : weeks2;
        offset += 83.0 + (maxWeeks * 62.0) + 20.0;
      }
      return offset;
    } else {
      double offset = 12.0; // list top padding
      for (int i = 0; i < _currentMonthIndex; i++) {
        final weeks = _getWeeksInMonth(_months[i], firstDayOfWeek);
        offset += 83.0 + (weeks * 54.0) + 16.0;
      }
      return offset;
    }
  }

  void _scrollToCurrentMonth({
    bool animate = false,
    required FirstDayOfWeek firstDayOfWeek,
  }) {
    if (!mounted) return;
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return;
    final isWide = isWideScreen(context);
    final targetOffset = _calculateTargetOffset(
      isWide: isWide,
      firstDayOfWeek: firstDayOfWeek,
    );

    if (animate) {
      controller.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      controller.jumpTo(targetOffset);
    }
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
    final firstDayOfWeek =
        settingsVal.value?.firstDayOfWeek ?? FirstDayOfWeek.sunday;

    final isWide = isWideScreen(context);
    final today = CivilDay.fromDateTime(AppClock.now);

    return PopScope(
      canPop: _zoomedDay == null,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _zoomedDay != null) {
          _zoomOutToMonth();
        }
      },
      child: Stack(
        children: [
          Offstage(
            offstage: _zoomedDay != null,
            child: Stack(
              children: [
                isWide
                    ? _buildWideMonthList(
                        instances,
                        schedules,
                        today,
                        currentUserId: currentUserId,
                        firstDayOfWeek: firstDayOfWeek,
                      )
                    : _buildNarrowMonthList(
                        instances,
                        schedules,
                        today,
                        currentUserId: currentUserId,
                        firstDayOfWeek: firstDayOfWeek,
                      ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton(
                    key: const Key('calendar_jump_to_today_button'),
                    heroTag: 'calendar_jump_to_today_fab',
                    tooltip: context.l10n.calendarJumpToToday,
                    onPressed: () => _scrollToCurrentMonth(
                      animate: true,
                      firstDayOfWeek: firstDayOfWeek,
                    ),
                    child: const Icon(Icons.today),
                  ),
                ),
              ],
            ),
          ),
          if (_zoomedDay != null)
            CalendarDayTimelineView(
              initialDay: _zoomedDay!,
              onBackToMonth: _zoomOutToMonth,
              instances: instances,
              schedules: schedules,
              currentUserId: currentUserId,
              today: today,
              monthTaskCache: ref.read(
                calendar_logic.calendarMonthTaskCacheProvider,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWideMonthList(
    List<TaskInstance> instances,
    List<TaskSchedule> schedules,
    CivilDay today, {
    String? currentUserId,
    required FirstDayOfWeek firstDayOfWeek,
  }) {
    final rowCount = (_months.length / 2).ceil();

    return ListView.builder(
      key: const PageStorageKey<String>('calendar_month_list'),
      controller: _scrollController,
      scrollCacheExtent: const ScrollCacheExtent.viewport(1.0),
      padding: const EdgeInsets.all(16),
      itemCount: rowCount,
      itemBuilder: (context, rowIndex) {
        final idx1 = rowIndex * 2;
        final idx2 = idx1 + 1;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CalendarMonthCard(
                  monthDate: _months[idx1],
                  dayTaskMap: _getMonthTaskMap(
                    _months[idx1],
                    instances,
                    schedules,
                    today: today,
                    currentUserId: currentUserId,
                  ),
                  today: today,
                  isWide: true,
                  firstDayOfWeek: firstDayOfWeek,
                  onDayTap: _zoomToDay,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: idx2 < _months.length
                    ? CalendarMonthCard(
                        monthDate: _months[idx2],
                        dayTaskMap: _getMonthTaskMap(
                          _months[idx2],
                          instances,
                          schedules,
                          today: today,
                          currentUserId: currentUserId,
                        ),
                        today: today,
                        isWide: true,
                        firstDayOfWeek: firstDayOfWeek,
                        onDayTap: _zoomToDay,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNarrowMonthList(
    List<TaskInstance> instances,
    List<TaskSchedule> schedules,
    CivilDay today, {
    String? currentUserId,
    required FirstDayOfWeek firstDayOfWeek,
  }) {
    return ListView.builder(
      key: const PageStorageKey<String>('calendar_month_list'),
      controller: _scrollController,
      scrollCacheExtent: const ScrollCacheExtent.viewport(1.0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: _months.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: CalendarMonthCard(
            monthDate: _months[index],
            dayTaskMap: _getMonthTaskMap(
              _months[index],
              instances,
              schedules,
              today: today,
              currentUserId: currentUserId,
            ),
            today: today,
            isWide: false,
            firstDayOfWeek: firstDayOfWeek,
            onDayTap: _zoomToDay,
          ),
        );
      },
    );
  }
}
