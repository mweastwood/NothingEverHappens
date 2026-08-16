import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/app_logger.dart';
import 'package:nothing_ever_happens/logic/firestore_extensions.dart';

class InitialFirebaseMigrationService {
  static final Map<String, Future<void>> _inFlightMigrations = {};

  final FirebaseFirestore _firestore;
  final HiveLocalDataSource _localDataSource;
  final String _userId;
  final AppLogger? _logger;

  InitialFirebaseMigrationService({
    FirebaseFirestore? firestore,
    required HiveLocalDataSource localDataSource,
    required String userId,
    AppLogger? logger,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _localDataSource = localDataSource,
       _userId = userId,
       _logger = logger;

  Future<void> migrateIfNeeded({bool force = false}) async {
    if (!force && _localDataSource.isMigrationCompleted()) {
      return;
    }

    final inFlight = _inFlightMigrations[_userId];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _doMigrate(force: force);
    _inFlightMigrations[_userId] = future;
    try {
      await future;
    } finally {
      _inFlightMigrations.remove(_userId);
    }
  }

  Future<void> _doMigrate({bool force = false}) async {
    final totalWatch = Stopwatch()..start();
    try {
      _logger?.info(
        'sync',
        'Initial Firebase migration started',
        data: {'force': force, 'userId': _userId},
      );

      _logger?.debug('sync', '[Migration 1/5] Fetching user profile doc...');
      final userStepWatch = Stopwatch()..start();
      final userDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .safeGet();
      final familyId = userDoc.data()?['familyId'] as String?;
      _logger?.info(
        'sync',
        '[Migration 1/5] User profile fetched',
        data: {
          'durationMs': userStepWatch.elapsedMilliseconds,
          'exists': userDoc.exists,
          'familyId': familyId,
        },
      );

      final List<TaskSchedule> tasksToMigrate = [];
      final List<TaskInstance> instancesToMigrate = [];

      // Get personal tasks
      _logger?.debug('sync', '[Migration 2/5] Fetching personal tasks...');
      final taskStepWatch = Stopwatch()..start();
      final personalTasksSnap = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('tasks')
          .safeGet();
      tasksToMigrate.addAll(
        personalTasksSnap.docs.map((doc) => TaskSchedule.fromFirestore(doc)),
      );
      _logger?.info(
        'sync',
        '[Migration 2/5] Personal tasks fetched',
        data: {
          'durationMs': taskStepWatch.elapsedMilliseconds,
          'count': personalTasksSnap.docs.length,
        },
      );

      // Get personal instances
      _logger?.debug('sync', '[Migration 3/5] Fetching personal instances...');
      final instanceStepWatch = Stopwatch()..start();
      final personalInstancesSnap = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('instances')
          .safeGet();
      instancesToMigrate.addAll(
        personalInstancesSnap.docs.map(
          (doc) => TaskInstance.fromFirestore(doc),
        ),
      );
      _logger?.info(
        'sync',
        '[Migration 3/5] Personal instances fetched',
        data: {
          'durationMs': instanceStepWatch.elapsedMilliseconds,
          'count': personalInstancesSnap.docs.length,
        },
      );

      // Get family tasks and instances if applicable
      if (familyId != null && familyId.isNotEmpty) {
        _logger?.debug('sync', '[Migration 3b] Fetching family data...');
        final familyStepWatch = Stopwatch()..start();
        final familyTasksSnap = await _firestore
            .collection('families')
            .doc(familyId)
            .collection('tasks')
            .safeGet();
        tasksToMigrate.addAll(
          familyTasksSnap.docs.map((doc) => TaskSchedule.fromFirestore(doc)),
        );

        final familyInstancesSnap = await _firestore
            .collection('families')
            .doc(familyId)
            .collection('instances')
            .safeGet();
        instancesToMigrate.addAll(
          familyInstancesSnap.docs.map(
            (doc) => TaskInstance.fromFirestore(doc),
          ),
        );
        _logger?.info(
          'sync',
          '[Migration 3b] Family data fetched',
          data: {
            'durationMs': familyStepWatch.elapsedMilliseconds,
            'familyTasksCount': familyTasksSnap.docs.length,
            'familyInstancesCount': familyInstancesSnap.docs.length,
          },
        );
      }

      // Clean slate: clear any existing local tasks/instances and dirty queues
      // before populating from Firestore to eliminate stale offline artifacts.
      _logger?.debug('sync', '[Migration 4/5] Clearing local Hive data...');
      final clearWatch = Stopwatch()..start();
      await _localDataSource.clearAllTasksAndInstances();
      await _localDataSource.clearAllDirty();
      _logger?.info(
        'sync',
        '[Migration 4/5] Local Hive data cleared',
        data: {'durationMs': clearWatch.elapsedMilliseconds},
      );

      // Save all fresh items to Hive
      _logger?.debug('sync', '[Migration 5/5] Saving fresh items to Hive...');
      final saveWatch = Stopwatch()..start();
      for (final task in tasksToMigrate) {
        await _localDataSource.saveTask(task);
      }

      for (final instance in instancesToMigrate) {
        await _localDataSource.saveInstance(instance);
      }

      await _localDataSource.setMigrationCompleted(true);
      _logger?.info(
        'sync',
        'Initial Firebase migration completed',
        data: {
          'tasksCount': tasksToMigrate.length,
          'instancesCount': instancesToMigrate.length,
          'force': force,
          'saveDurationMs': saveWatch.elapsedMilliseconds,
          'totalDurationMs': totalWatch.elapsedMilliseconds,
        },
      );
    } catch (e, st) {
      _logger?.error(
        'sync',
        'Initial Firebase migration failed',
        error: e,
        stackTrace: st,
        data: {
          'totalDurationMs': totalWatch.elapsedMilliseconds,
          'errorType': e.runtimeType.toString(),
        },
      );
      // ignore: avoid_print
      print('Migration failed: $e');
      rethrow;
    }
  }
}
