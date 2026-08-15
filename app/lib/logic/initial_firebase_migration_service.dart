import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/app_logger.dart';

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
    try {
      _logger?.info(
        'sync',
        'Initial Firebase migration started',
        data: {'force': force},
      );
      final userDoc = await _firestore.collection('users').doc(_userId).get();
      final familyId = userDoc.data()?['familyId'] as String?;

      final List<TaskSchedule> tasksToMigrate = [];
      final List<TaskInstance> instancesToMigrate = [];

      // Get personal tasks
      final personalTasksSnap = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('tasks')
          .get();
      tasksToMigrate.addAll(
        personalTasksSnap.docs.map((doc) => TaskSchedule.fromFirestore(doc)),
      );

      // Get personal instances
      final personalInstancesSnap = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('instances')
          .get();
      instancesToMigrate.addAll(
        personalInstancesSnap.docs.map(
          (doc) => TaskInstance.fromFirestore(doc),
        ),
      );

      // Get family tasks and instances if applicable
      if (familyId != null && familyId.isNotEmpty) {
        final familyTasksSnap = await _firestore
            .collection('families')
            .doc(familyId)
            .collection('tasks')
            .get();
        tasksToMigrate.addAll(
          familyTasksSnap.docs.map((doc) => TaskSchedule.fromFirestore(doc)),
        );

        final familyInstancesSnap = await _firestore
            .collection('families')
            .doc(familyId)
            .collection('instances')
            .get();
        instancesToMigrate.addAll(
          familyInstancesSnap.docs.map(
            (doc) => TaskInstance.fromFirestore(doc),
          ),
        );
      }

      // Clean slate: clear any existing local tasks/instances and dirty queues
      // before populating from Firestore to eliminate stale offline artifacts.
      await _localDataSource.clearAllTasksAndInstances();
      await _localDataSource.clearAllDirty();

      // Save all fresh items to Hive
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
        },
      );
    } catch (e) {
      _logger?.error('sync', 'Initial Firebase migration failed', error: e);
      // ignore: avoid_print
      print('Migration failed: $e');
      rethrow;
    }
  }
}
