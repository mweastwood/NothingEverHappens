import '../app_clock.dart';
import '../task_instance.dart';
import '../task_schedule.dart';

/// Estimates the rendered vertical height of a [TaskInstance] card in logical pixels.
double estimateTaskInstanceHeight(
  TaskInstance instance, [
  TaskSchedule? schedule,
]) {
  // Base card margins (4 top + 4 bottom = 8) + bottom item padding (8) = 16
  // Base card minimum height (ListTile with single line title, padding, actions) = ~60
  double height = 76.0;

  // Title: ~35 characters per line in a ~400-500px column
  final titleLength = instance.title.length;
  if (titleLength > 35) {
    final extraLines = (titleLength / 35).ceil() - 1;
    height += extraLines * 20.0;
  }

  // Description: markdown content
  if (instance.description.isNotEmpty) {
    height += 8.0; // Spacing before description
    final lines = instance.description.split('\n');
    for (final line in lines) {
      if (line.isEmpty) {
        height += 8.0;
      } else {
        final wrappedLines = (line.length / 45).ceil();
        height += wrappedLines * 18.0;
      }
    }
  }

  // Badges:
  int badgeCount = 1; // Due date badge is always present
  if (instance.workflowPayload != null) badgeCount++;
  final startDateTime = instance.startRelativeTime.referenceTo(
    instance.scheduledDate,
  );
  if (AppClock.now.isBefore(startDateTime)) badgeCount++;
  if (instance.isFamily) badgeCount++;
  if (instance.isFamily &&
      instance.familyCompletionMode == FamilyCompletionMode.individual) {
    badgeCount++;
  }
  if (instance.priority != TaskPriority.medium) badgeCount++;
  if (schedule?.estimatedDuration != null) badgeCount++;
  if (instance.isFamily && instance.assignedUserId != null) badgeCount++;

  // Wrap rows: ~3 badges per row in wide column
  height += 8.0; // Spacing before badges
  final badgeRows = (badgeCount / 3).ceil();
  height += badgeRows * 26.0;

  return height;
}

/// Estimates the rendered vertical height of a [TaskSchedule] card in logical pixels.
double estimateTaskScheduleHeight(
  TaskSchedule schedule, {
  bool showLastSpawnedDate = false,
}) {
  // Base card margins (4 top + 4 bottom = 8) + bottom item padding (8) = 16
  // Header row (title + copy + edit + delete buttons) = ~48
  double height = 72.0;

  // Title lines
  final titleLength = schedule.title.length;
  if (titleLength > 35) {
    final extraLines = (titleLength / 35).ceil() - 1;
    height += extraLines * 20.0;
  }

  // Family badges
  if (schedule.isFamily) {
    int familyBadges = 1;
    if (schedule.familyCompletionMode == FamilyCompletionMode.individual) {
      familyBadges++;
    }
    if (schedule.assignedUserId != null) familyBadges++;
    final rows = (familyBadges / 3).ceil();
    height += rows * 28.0;
  }

  // Description
  if (schedule.description.isNotEmpty) {
    height += 8.0;
    final lines = schedule.description.split('\n');
    for (final line in lines) {
      if (line.isEmpty) {
        height += 8.0;
      } else {
        final wrappedLines = (line.length / 45).ceil();
        height += wrappedLines * 18.0;
      }
    }
  }

  // Schedule rules
  for (final _ in schedule.schedules) {
    height += 64.0; // Box padding, interval text, times, missed policy
  }

  // Priority & Duration badges
  int footerBadges = 0;
  if (schedule.priority != TaskPriority.medium) footerBadges++;
  if (schedule.estimatedDuration != null) footerBadges++;
  if (footerBadges > 0) {
    final rows = (footerBadges / 3).ceil();
    height += rows * 28.0;
  }

  if (showLastSpawnedDate && schedule.lastSpawnedDate != null) {
    height += 24.0;
  }

  return height;
}
