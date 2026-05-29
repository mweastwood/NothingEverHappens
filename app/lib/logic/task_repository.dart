import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'app_clock.dart';
import 'civil_day.dart';
import 'relative_time.dart';
import 'task.dart';
import 'task_delta.dart';
import 'task_list.dart';
import 'notification_service.dart';

class TaskRepository {
  final FirebaseFirestore _firestore;
  final String _userId;
  final NotificationService? _notificationService;

  String get userId => _userId;

  TaskRepository({
    FirebaseFirestore? firestore,
    required String userId,
    NotificationService? notificationService,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _userId = userId,
       _notificationService = notificationService;

  CollectionReference<Task> get _tasksRef {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('tasks')
        .withConverter<Task>(
          fromFirestore: (snapshot, _) => Task.fromFirestore(snapshot),
          toFirestore: (task, _) => task.toFirestore(),
        );
  }

  CollectionReference<TaskDelta> get _historyRef {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('history')
        .withConverter<TaskDelta>(
          fromFirestore: (snapshot, _) => TaskDelta.fromJson(snapshot.data()!),
          toFirestore: (delta, _) => delta.toJson(),
        );
  }

  Stream<List<Task>> getTasks() {
    return _tasksRef.snapshots().map((snapshot) {
      final tasks = snapshot.docs.map((doc) => doc.data()).toList();
      _checkAndProcessMissedPolicies(tasks);
      return tasks;
    });
  }

  void _checkAndProcessMissedPolicies(List<Task> tasks) async {
    final now = AppClock.now;
    final today = CivilDay.fromDateTime(now);
    
    final batch = _firestore.batch();
    bool hasChanges = false;
    
    for (final task in tasks) {
      // 1. Skip policy
      if (task.schedule is! OneOffSchedule &&
          task.missedPolicy == MissedPolicy.skip &&
          task.isOverdue(now)) {
        
        final deltaId = const Uuid().v4();
        final delta = TaskDelta(
          id: deltaId,
          taskId: task.id,
          timestamp: now,
          expiresAt: now.add(const Duration(days: 90)),
          operation: 'skipped',
          changedFields: {},
          userId: _userId,
        );
        batch.set(_historyRef.doc(deltaId), delta);
        
        final nextOccur = task.schedule.nextOccurrenceAfter(task.schedule.scheduledDate);
        TaskSchedule newSchedule;
        if (task.schedule is DailySchedule) {
          final ds = task.schedule as DailySchedule;
          newSchedule = DailySchedule(startDate: nextOccur, interval: ds.interval);
        } else if (task.schedule is WeeklySchedule) {
          final ws = task.schedule as WeeklySchedule;
          newSchedule = WeeklySchedule(
            startDate: nextOccur,
            interval: ws.interval,
            daysOfWeek: ws.daysOfWeek,
          );
        } else {
          newSchedule = task.schedule;
        }
        
        final firstOccurStart = task.dailyTimes.isNotEmpty
            ? RelativeTime(dayOffset: 0, time: task.dailyTimes[0].startTime)
            : task.startRelativeTime;
        final firstOccurDue = task.dailyTimes.isNotEmpty
            ? RelativeTime(dayOffset: 0, time: task.dailyTimes[0].dueTime)
            : task.dueRelativeTime;
            
        final updatedTask = Task(
          id: task.id,
          title: task.title,
          description: task.description,
          startRelativeTime: firstOccurStart,
          dueRelativeTime: firstOccurDue,
          schedule: newSchedule,
          dailyTimes: task.dailyTimes,
          activeOccurrenceIndex: 0,
          missedPolicy: task.missedPolicy,
          isMaster: task.isMaster,
          lastSpawnedDate: task.lastSpawnedDate,
          parentTaskId: task.parentTaskId,
          estimatedDuration: task.estimatedDuration,
        );
        
        batch.set(_tasksRef.doc(task.id), updatedTask);
        hasChanges = true;
      }
      
      // 2. Stack policy
      if (task.isMaster && task.missedPolicy == MissedPolicy.stack) {
        final startDate = task.schedule.scheduledDate;
        final lastSpawned = task.lastSpawnedDate;
        
        CivilDay checkDate = lastSpawned != null
            ? lastSpawned.addDays(1)
            : startDate;
            
        List<CivilDay> datesToSpawn = [];
        while (checkDate.isBefore(today) || checkDate == today) {
          if (task.schedule.occursOn(checkDate)) {
            datesToSpawn.add(checkDate);
          }
          checkDate = checkDate.addDays(1);
        }
        
        if (datesToSpawn.isNotEmpty) {
          for (final date in datesToSpawn) {
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            final spawnedId = '${task.id}_$dateStr';
            
            if (task.dailyTimes.isNotEmpty) {
              for (int i = 0; i < task.dailyTimes.length; i++) {
                final timeSlot = task.dailyTimes[i];
                final slotId = '${spawnedId}_$i';
                
                final spawnedTask = Task(
                  id: slotId,
                  title: task.title,
                  description: task.description,
                  startRelativeTime: RelativeTime(dayOffset: 0, time: timeSlot.startTime),
                  dueRelativeTime: RelativeTime(dayOffset: 0, time: timeSlot.dueTime),
                  schedule: OneOffSchedule(date: date),
                  parentTaskId: task.id,
                  missedPolicy: task.missedPolicy,
                  estimatedDuration: task.estimatedDuration,
                );
                batch.set(_tasksRef.doc(slotId), spawnedTask);
              }
            } else {
              final spawnedTask = Task(
                id: spawnedId,
                title: task.title,
                description: task.description,
                startRelativeTime: task.startRelativeTime,
                dueRelativeTime: task.dueRelativeTime,
                schedule: OneOffSchedule(date: date),
                parentTaskId: task.id,
                missedPolicy: task.missedPolicy,
                estimatedDuration: task.estimatedDuration,
              );
              batch.set(_tasksRef.doc(spawnedId), spawnedTask);
            }
          }
          
          final updatedMaster = Task(
            id: task.id,
            title: task.title,
            description: task.description,
            startRelativeTime: task.startRelativeTime,
            dueRelativeTime: task.dueRelativeTime,
            schedule: task.schedule,
            dailyTimes: task.dailyTimes,
            activeOccurrenceIndex: task.activeOccurrenceIndex,
            missedPolicy: task.missedPolicy,
            isMaster: true,
            lastSpawnedDate: today,
            estimatedDuration: task.estimatedDuration,
          );
          batch.set(_tasksRef.doc(task.id), updatedMaster);
          hasChanges = true;
        }
      }
    }
    
    if (hasChanges) {
      try {
        await batch.commit();
      } catch (e) {
        print('Error in auto-processing missed policies: $e');
      }
    }
  }

  Stream<List<TaskDelta>> getHistory() {
    return _historyRef.orderBy('timestamp', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) => doc.data()).toList();
    });
  }

  Future<void> addTask(Task task) async {
    final newState = const TaskList([]).add(task, _userId);
    final delta = newState.history.last;

    final batch = _firestore.batch();

    batch.set(_tasksRef.doc(task.id), task);
    batch.set(_historyRef.doc(delta.id), delta);

    await batch.commit();
    await _notificationService?.scheduleNotifications(task);
  }

  Future<void> updateTask(TaskModification modification) async {
    final batch = _firestore.batch();

    batch.set(_tasksRef.doc(modification.newTask.id), modification.newTask);
    batch.set(_historyRef.doc(modification.delta.id), modification.delta);

    await batch.commit();
    await _notificationService?.scheduleNotifications(modification.newTask);
  }

  Future<void> deleteTask(String id) async {
    final newState = const TaskList([]).delete(id, _userId);
    final delta = newState.history.last;

    final batch = _firestore.batch();

    batch.delete(_tasksRef.doc(id));
    batch.set(_historyRef.doc(delta.id), delta);

    final spawnedDocs = await _tasksRef.where('parentTaskId', isEqualTo: id).get();
    for (final doc in spawnedDocs.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    await _notificationService?.cancelNotifications(id);
  }

  Future<void> completeTask(String id) async {
    final doc = await _tasksRef.doc(id).get();
    if (!doc.exists) return;
    final task = doc.data()!;

    final isRecurring = task.schedule is! OneOffSchedule;
    final newState = TaskList([task]).complete(id, _userId);
    final delta = newState.history.last;

    final batch = _firestore.batch();

    Task? updatedTask;
    if (isRecurring) {
      updatedTask = newState.activeTasks.firstWhere((t) => t.id == id);
      batch.set(_tasksRef.doc(id), updatedTask);
    } else {
      batch.delete(_tasksRef.doc(id));
    }

    batch.set(_historyRef.doc(delta.id), delta);

    await batch.commit();

    if (isRecurring && updatedTask != null) {
      await _notificationService?.scheduleNotifications(updatedTask);
    } else {
      await _notificationService?.cancelNotifications(id);
    }
  }
}
