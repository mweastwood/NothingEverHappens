import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logic/app_clock.dart';
import '../logic/auth_repository.dart';
import '../logic/calendar_day_task.dart';
import '../logic/civil_day.dart';
import '../logic/l10n_extension.dart';
import '../logic/task_instance.dart';
import '../logic/task_repository.dart';
import '../logic/task_schedule.dart';
import '../logic/utils/layout_breakpoints.dart';
import '../widgets/calendar_month_card.dart';

export '../logic/calendar_day_task.dart';
export '../widgets/calendar_day_details_sheet.dart';
export '../widgets/calendar_month_card.dart';

/// Screen displaying a scrollable calendar view of past and future months.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late final ScrollController _scrollController;
  late final DateTime _initialNow;
  late final List<DateTime> _months;
  late final int _currentMonthIndex;
  bool _hasScrolledToCurrentMonth = false;

  final Map<DateTime, Map<CivilDay, List<CalendarDayTask>>> _monthTaskMapCache =
      {};
  List<TaskInstance>? _cachedInstances;
  List<TaskSchedule>? _cachedSchedules;
  String? _cachedUserId;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
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
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _getWeeksInMonth(DateTime monthDate) {
    final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;
    final firstWeekday = DateTime(
      monthDate.year,
      monthDate.month,
      1,
    ).weekday; // 1=Mon, 7=Sun
    final leadingEmptyCount = firstWeekday - 1;
    final totalSlots = leadingEmptyCount + daysInMonth;
    return (totalSlots / 7).ceil();
  }

  double _calculateTargetOffset({required bool isWide}) {
    if (isWide) {
      double offset = 16.0; // list top padding
      final targetRow = _currentMonthIndex ~/ 2;
      for (int r = 0; r < targetRow; r++) {
        final idx1 = r * 2;
        final idx2 = idx1 + 1;
        final weeks1 = _getWeeksInMonth(_months[idx1]);
        final weeks2 = idx2 < _months.length
            ? _getWeeksInMonth(_months[idx2])
            : 0;
        final maxWeeks = weeks1 > weeks2 ? weeks1 : weeks2;
        offset += 83.0 + (maxWeeks * 62.0) + 20.0;
      }
      return offset;
    } else {
      double offset = 12.0; // list top padding
      for (int i = 0; i < _currentMonthIndex; i++) {
        final weeks = _getWeeksInMonth(_months[i]);
        offset += 83.0 + (weeks * 54.0) + 16.0;
      }
      return offset;
    }
  }

  void _scrollToCurrentMonth({bool animate = false}) {
    if (!mounted) return;
    if (!_scrollController.hasClients) return;
    final isWide = isWideScreen(context);
    final targetOffset = _calculateTargetOffset(isWide: isWide);

    if (animate) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(targetOffset);
    }
  }

  Map<CivilDay, List<CalendarDayTask>> _getMonthTaskMap(
    DateTime monthDate,
    List<TaskInstance> instances,
    List<TaskSchedule> schedules, {
    String? currentUserId,
  }) {
    if (!identical(instances, _cachedInstances) ||
        !identical(schedules, _cachedSchedules) ||
        currentUserId != _cachedUserId) {
      _monthTaskMapCache.clear();
      _cachedInstances = instances;
      _cachedSchedules = schedules;
      _cachedUserId = currentUserId;
    }

    final monthKey = DateTime(monthDate.year, monthDate.month, 1);
    return _monthTaskMapCache.putIfAbsent(
      monthKey,
      () => computeMonthTaskMap(
        monthDate: monthDate,
        instances: instances,
        schedules: schedules,
        currentUserId: currentUserId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final instancesVal = ref.watch(taskInstancesProvider);
    final schedulesVal = ref.watch(taskSchedulesProvider);

    if (instancesVal.isLoading || schedulesVal.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final instances = instancesVal.value ?? [];
    final schedules = schedulesVal.value ?? [];
    final currentUserId = ref.watch(authStateProvider).value?.uid;

    if (!identical(instances, _cachedInstances) ||
        !identical(schedules, _cachedSchedules) ||
        currentUserId != _cachedUserId) {
      _monthTaskMapCache.clear();
      _cachedInstances = instances;
      _cachedSchedules = schedules;
      _cachedUserId = currentUserId;
    }

    final isWide = isWideScreen(context);
    final now = AppClock.now;
    final today = CivilDay.fromDateTime(now);

    if (!_hasScrolledToCurrentMonth) {
      _hasScrolledToCurrentMonth = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentMonth();
      });
    }

    return Stack(
      children: [
        isWide
            ? _buildWideMonthList(
                instances,
                schedules,
                today,
                currentUserId: currentUserId,
              )
            : _buildNarrowMonthList(
                instances,
                schedules,
                today,
                currentUserId: currentUserId,
              ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            key: const Key('calendar_jump_to_today_button'),
            heroTag: 'calendar_jump_to_today_fab',
            tooltip: context.l10n.calendarJumpToToday,
            onPressed: () => _scrollToCurrentMonth(animate: true),
            child: const Icon(Icons.today),
          ),
        ),
      ],
    );
  }

  Widget _buildWideMonthList(
    List<TaskInstance> instances,
    List<TaskSchedule> schedules,
    CivilDay today, {
    String? currentUserId,
  }) {
    final rowCount = (_months.length / 2).ceil();

    return ListView.builder(
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
                    currentUserId: currentUserId,
                  ),
                  today: today,
                  isWide: true,
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
                          currentUserId: currentUserId,
                        ),
                        today: today,
                        isWide: true,
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
  }) {
    return ListView.builder(
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
              currentUserId: currentUserId,
            ),
            today: today,
            isWide: false,
          ),
        );
      },
    );
  }
}
