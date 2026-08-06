import re

with open('app/lib/screens/dashboard_screen.dart', 'r') as f:
    content = f.read()

# Replace top imports
content = content.replace("import '../logic/auth_repository.dart';", "import '../logic/auth_repository.dart';\nimport '../widgets/weekly_capacity_chart.dart';")

# Inject _buildCapacityData
build_cap_data = """  List<DailyCapacityData> _buildCapacityData(
    List<DateTime> upcomingDays,
    UserSettings settings,
    List<TaskInstance> instances,
    Map<String, TaskSchedule> scheduleMap,
    String? currentUserId,
  ) {
    return upcomingDays.map((date) {
      final capacity = settings.getCapacityForDate(date);
      final day = CivilDay.fromDateTime(date);
      double plannedMinutes = 0.0;

      for (final inst in instances) {
        if (inst.scheduledDate == day && inst.status != 'skipped') {
          if (inst.assignedUserId != null &&
              inst.assignedUserId != currentUserId) {
            continue;
          }
          final schedule = scheduleMap[inst.scheduleId];
          if (schedule != null && schedule.estimatedDuration != null) {
            plannedMinutes += schedule.estimatedDuration!.inMinutes.toDouble();
          }
        }
      }

      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final isOverridden = settings.dailyCapacityOverrides?.containsKey(dateStr) ?? false;

      return DailyCapacityData(
        date: date,
        capacityHours: capacity,
        plannedMinutes: plannedMinutes,
        isOverridden: isOverridden,
      );
    }).toList();
  }

"""
content = content.replace("class _DashboardScreenState extends ConsumerState<DashboardScreen> {\n", "class _DashboardScreenState extends ConsumerState<DashboardScreen> {\n" + build_cap_data)

# Remove _formatForecastLabel
content = re.sub(r"  String _formatForecastLabel\(.*?\}\n\n", "", content, flags=re.DOTALL)

# Replace the graph card
graph_card_start = content.find("            // Weekly Capacity Graph Card")
graph_card_end = content.find("            // Statistics Card (Placeholder)")
if graph_card_start != -1 and graph_card_end != -1:
    new_card = """            // Weekly Capacity Graph Card
            WeeklyCapacityChart(
              daysData: _buildCapacityData(
                upcomingDays,
                settings,
                instances,
                scheduleMap,
                currentUserId,
              ),
              onDayTap: (date) => _showEditCapacityDialog(
                context,
                settings,
                date,
                isOverride: true,
              ),
              onEditDefaultCapacity: () => _showDefaultCapacityTemplateDialog(
                context,
                settings,
              ),
            ),
            const SizedBox(height: 16),

"""
    content = content[:graph_card_start] + new_card + content[graph_card_end:]

# Remove DashedRectPainter
content = re.sub(r"class DashedRectPainter extends CustomPainter \{.*?\}\n", "", content, flags=re.DOTALL)

with open('app/lib/screens/dashboard_screen.dart', 'w') as f:
    f.write(content)
