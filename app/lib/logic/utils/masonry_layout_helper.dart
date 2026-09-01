import '../task_instance.dart';
import '../task_schedule.dart';

const double _kBaseInstanceHeight = 76.0;
const double _kBaseScheduleHeight = 72.0;
const int _kCharsPerTitleLine = 35;
const double _kTitleLineHeight = 20.0;
const int _kCharsPerDescriptionLine = 45;
const double _kDescriptionLineHeight = 18.0;
const double _kSectionSpacing = 8.0;
const double _kEmptyLineHeight = 8.0;
const int _kBadgesPerRow = 3;
const double _kInstanceBadgeRowHeight = 26.0;
const double _kScheduleBadgeRowHeight = 28.0;
const double _kScheduleRuleHeight = 64.0;
const double _kLastSpawnedDateHeight = 24.0;

/// Estimates the rendered vertical height of a [TaskInstance] card in logical pixels.
///
/// If [now] is provided, it is used to determine whether the task has not yet
/// started and requires a pending badge. Providing [now] explicitly ensures
/// deterministic height estimation.
double estimateTaskInstanceHeight(
  TaskInstance instance, [
  TaskSchedule? schedule,
  DateTime? now,
]) {
  // Base card margins (4 top + 4 bottom = 8) + bottom item padding (8) = 16
  // Base card minimum height (ListTile with single line title, padding, actions) = ~60
  double height = _kBaseInstanceHeight;

  // Title: ~35 characters per line in a ~400-500px column
  final titleLength = instance.title.length;
  if (titleLength > _kCharsPerTitleLine) {
    final extraLines = (titleLength / _kCharsPerTitleLine).ceil() - 1;
    height += extraLines * _kTitleLineHeight;
  }

  // Description: markdown content
  if (instance.description.isNotEmpty) {
    height += _kSectionSpacing; // Spacing before description
    final lines = instance.description.split('\n');
    for (final line in lines) {
      if (line.isEmpty) {
        height += _kEmptyLineHeight;
      } else {
        final wrappedLines = (line.length / _kCharsPerDescriptionLine).ceil();
        height += wrappedLines * _kDescriptionLineHeight;
      }
    }
  }

  // Badges:
  int badgeCount = 1; // Due date badge is always present
  if (instance.workflowPayload != null) badgeCount++;
  if (now != null) {
    final startDateTime = instance.startRelativeTime.referenceTo(
      instance.scheduledDate,
    );
    if (now.isBefore(startDateTime)) badgeCount++;
  }
  if (instance.isFamily) badgeCount++;
  if (instance.isFamily &&
      instance.familyCompletionMode == FamilyCompletionMode.individual) {
    badgeCount++;
  }
  if (instance.priority != TaskPriority.medium) badgeCount++;
  if (schedule?.estimatedDuration != null) badgeCount++;
  if (instance.isFamily && instance.assignedUserId != null) badgeCount++;

  // Wrap rows: ~3 badges per row in wide column
  height += _kSectionSpacing; // Spacing before badges
  final badgeRows = (badgeCount / _kBadgesPerRow).ceil();
  height += badgeRows * _kInstanceBadgeRowHeight;

  return height;
}

/// Estimates the rendered vertical height of a [TaskSchedule] card in logical pixels.
double estimateTaskScheduleHeight(
  TaskSchedule schedule, {
  bool showLastSpawnedDate = false,
}) {
  // Base card margins (4 top + 4 bottom = 8) + bottom item padding (8) = 16
  // Header row (title + copy + edit + delete buttons) = ~48
  double height = _kBaseScheduleHeight;

  // Title lines
  final titleLength = schedule.title.length;
  if (titleLength > _kCharsPerTitleLine) {
    final extraLines = (titleLength / _kCharsPerTitleLine).ceil() - 1;
    height += extraLines * _kTitleLineHeight;
  }

  // Family badges
  if (schedule.isFamily) {
    int familyBadges = 1;
    if (schedule.familyCompletionMode == FamilyCompletionMode.individual) {
      familyBadges++;
    }
    if (schedule.assignedUserId != null) familyBadges++;
    final rows = (familyBadges / _kBadgesPerRow).ceil();
    height += rows * _kScheduleBadgeRowHeight;
  }

  // Description
  if (schedule.description.isNotEmpty) {
    height += _kSectionSpacing;
    final lines = schedule.description.split('\n');
    for (final line in lines) {
      if (line.isEmpty) {
        height += _kEmptyLineHeight;
      } else {
        final wrappedLines = (line.length / _kCharsPerDescriptionLine).ceil();
        height += wrappedLines * _kDescriptionLineHeight;
      }
    }
  }

  // Schedule rules
  for (final _ in schedule.schedules) {
    height +=
        _kScheduleRuleHeight; // Box padding, interval text, times, missed policy
  }

  // Priority & Duration badges
  int footerBadges = 0;
  if (schedule.priority != TaskPriority.medium) footerBadges++;
  if (schedule.estimatedDuration != null) footerBadges++;
  if (footerBadges > 0) {
    final rows = (footerBadges / _kBadgesPerRow).ceil();
    height += rows * _kScheduleBadgeRowHeight;
  }

  if (showLastSpawnedDate && schedule.lastSpawnedDate != null) {
    height += _kLastSpawnedDateHeight;
  }

  return height;
}
