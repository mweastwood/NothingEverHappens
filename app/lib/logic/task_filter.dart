import 'package:flutter_riverpod/legacy.dart';
import 'task_instance.dart';
import 'task_schedule.dart';

enum TaskUrgencyFilter { overdue, dueToday, upcoming }

class TaskFilterState {
  final Set<String> selectedLabelIds;
  final Set<TaskPriority> selectedPriorities;
  final Set<TaskUrgencyFilter> selectedUrgencies;

  const TaskFilterState({
    this.selectedLabelIds = const {},
    this.selectedPriorities = const {},
    this.selectedUrgencies = const {},
  });

  bool get isEmpty =>
      selectedLabelIds.isEmpty &&
      selectedPriorities.isEmpty &&
      selectedUrgencies.isEmpty;

  bool get isNotEmpty => !isEmpty;

  int get activeFilterCount =>
      selectedLabelIds.length +
      selectedPriorities.length +
      selectedUrgencies.length;

  TaskFilterState copyWith({
    Set<String>? selectedLabelIds,
    Set<TaskPriority>? selectedPriorities,
    Set<TaskUrgencyFilter>? selectedUrgencies,
  }) {
    return TaskFilterState(
      selectedLabelIds: selectedLabelIds ?? this.selectedLabelIds,
      selectedPriorities: selectedPriorities ?? this.selectedPriorities,
      selectedUrgencies: selectedUrgencies ?? this.selectedUrgencies,
    );
  }

  TaskFilterState toggleLabel(String id) {
    final next = Set<String>.from(selectedLabelIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    return copyWith(selectedLabelIds: next);
  }

  TaskFilterState togglePriority(TaskPriority priority) {
    final next = Set<TaskPriority>.from(selectedPriorities);
    if (next.contains(priority)) {
      next.remove(priority);
    } else {
      next.add(priority);
    }
    return copyWith(selectedPriorities: next);
  }

  TaskFilterState toggleUrgency(TaskUrgencyFilter urgency) {
    final next = Set<TaskUrgencyFilter>.from(selectedUrgencies);
    if (next.contains(urgency)) {
      next.remove(urgency);
    } else {
      next.add(urgency);
    }
    return copyWith(selectedUrgencies: next);
  }

  TaskFilterState clear() => const TaskFilterState();

  bool matches({
    required TaskInstance instance,
    TaskSchedule? schedule,
    required DateTime now,
  }) {
    if (selectedPriorities.isNotEmpty &&
        !selectedPriorities.contains(instance.priority)) {
      return false;
    }

    if (selectedLabelIds.isNotEmpty) {
      final taskLabelIds = instance.labelIds.isNotEmpty
          ? instance.labelIds
          : (schedule?.labelIds ?? const <String>[]);
      final hasMatchingLabel = selectedLabelIds.any(
        (id) => taskLabelIds.contains(id),
      );
      if (!hasMatchingLabel) return false;
    }

    if (selectedUrgencies.isNotEmpty) {
      final dueDateTime = instance.dueRelativeTime.referenceTo(
        instance.scheduledDate,
      );
      final isOverdue = dueDateTime.isBefore(now);
      final isToday =
          dueDateTime.year == now.year &&
          dueDateTime.month == now.month &&
          dueDateTime.day == now.day;
      final startOfTomorrow = DateTime(now.year, now.month, now.day + 1);
      final isUpcoming = !dueDateTime.isBefore(startOfTomorrow);

      final matchesUrgency =
          (selectedUrgencies.contains(TaskUrgencyFilter.overdue) &&
              isOverdue) ||
          (selectedUrgencies.contains(TaskUrgencyFilter.dueToday) && isToday) ||
          (selectedUrgencies.contains(TaskUrgencyFilter.upcoming) &&
              isUpcoming);

      if (!matchesUrgency) return false;
    }

    return true;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskFilterState &&
          runtimeType == other.runtimeType &&
          _setEquals(selectedLabelIds, other.selectedLabelIds) &&
          _setEquals(selectedPriorities, other.selectedPriorities) &&
          _setEquals(selectedUrgencies, other.selectedUrgencies);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(selectedLabelIds),
    Object.hashAllUnordered(selectedPriorities),
    Object.hashAllUnordered(selectedUrgencies),
  );

  static bool _setEquals<T>(Set<T> a, Set<T> b) {
    if (a.length != b.length) return false;
    return a.containsAll(b);
  }
}

final taskFilterProvider = StateProvider<TaskFilterState>((ref) {
  return const TaskFilterState();
});
