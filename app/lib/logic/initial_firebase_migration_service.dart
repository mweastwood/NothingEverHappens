import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nothing_ever_happens/logic/hive_local_data_source.dart';
import 'package:nothing_ever_happens/logic/recipes/recipe.dart';
import 'package:nothing_ever_happens/logic/task_schedule.dart';
import 'package:nothing_ever_happens/logic/task_instance.dart';
import 'package:nothing_ever_happens/logic/app_logger.dart';
import 'package:nothing_ever_happens/logic/firestore_extensions.dart';
import 'package:nothing_ever_happens/logic/firestore_paths.dart';
import 'package:nothing_ever_happens/logic/app_clock.dart';

class InitialFirebaseMigrationService {
  static final Map<String, Future<void>> _inFlightMigrations = {};

  final FirebaseFirestore _firestore;
  final HiveLocalDataSource _localDataSource;
  final String _userId;
  final bool isActivePremium;
  final AppLogger? _logger;

  InitialFirebaseMigrationService({
    FirebaseFirestore? firestore,
    required HiveLocalDataSource localDataSource,
    required String userId,
    this.isActivePremium = true,
    AppLogger? logger,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _localDataSource = localDataSource,
       _userId = userId,
       _logger = logger;

  Future<void> checkAndMigrate({bool force = false, bool? isActivePremium}) =>
      migrateIfNeeded(force: force, isActivePremium: isActivePremium);

  Future<void> migrateIfNeeded({
    bool force = false,
    bool? isActivePremium,
  }) async {
    final activeUser = _localDataSource.getActiveUserId();
    final isDifferentUser =
        activeUser != null && activeUser.isNotEmpty && activeUser != _userId;

    if (!(isActivePremium ?? this.isActivePremium)) {
      if (isDifferentUser) {
        await _localDataSource.resetAllData();
      }
      await _localDataSource.setActiveUserId(_userId);
      await _localDataSource.setIsActivePremium(false);
      _logger?.info(
        'sync',
        'Skipping initial Firebase migration for non-premium user',
        data: {'userId': _userId},
      );
      return;
    }

    final shouldForce = force || isDifferentUser;

    if (!shouldForce && _localDataSource.isMigrationCompleted()) {
      return;
    }

    final inFlight = _inFlightMigrations[_userId];
    if (inFlight != null) {
      return inFlight;
    }

    final future = _doMigrate(
      force: shouldForce,
      isDifferentUser: isDifferentUser,
    );
    _inFlightMigrations[_userId] = future;
    try {
      await future;
    } finally {
      _inFlightMigrations.remove(_userId);
    }
  }

  Future<void> _doMigrate({
    bool force = false,
    bool isDifferentUser = false,
  }) async {
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
          .collection(FirestorePaths.users)
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
      final Map<String, Recipe> recipesToMigrate = {};

      // Get personal tasks and recipes
      _logger?.debug('sync', '[Migration 2/5] Fetching personal tasks...');
      final taskStepWatch = Stopwatch()..start();
      final personalTasksSnap = await _firestore
          .collection(FirestorePaths.users)
          .doc(_userId)
          .collection(FirestorePaths.tasks)
          .safeGet();
      tasksToMigrate.addAll(
        personalTasksSnap.docs.map((doc) => TaskSchedule.fromFirestore(doc)),
      );
      final personalRecipesSnap = await _firestore
          .collection(FirestorePaths.users)
          .doc(_userId)
          .collection(FirestorePaths.recipes)
          .safeGet();
      for (final doc in personalRecipesSnap.docs) {
        if (doc.data().isNotEmpty) {
          final recipe = Recipe.fromFirestore(doc);
          recipesToMigrate[recipe.id] = recipe;
        }
      }
      _logger?.info(
        'sync',
        '[Migration 2/5] Personal tasks fetched',
        data: {
          'durationMs': taskStepWatch.elapsedMilliseconds,
          'count': personalTasksSnap.docs.length,
          'recipesCount': personalRecipesSnap.docs.length,
        },
      );

      // Get personal instances (bounded to recent instances within 90 days or limit to prevent massive payload timeouts)
      _logger?.debug('sync', '[Migration 3/5] Fetching personal instances...');
      final instanceStepWatch = Stopwatch()..start();
      final cutoffDate = AppClock.now.subtract(const Duration(days: 90));

      final personalInstancesSnap = await _fetchRecentInstances(
        _firestore
            .collection(FirestorePaths.users)
            .doc(_userId)
            .collection(FirestorePaths.instances),
        cutoffDate,
      );

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
            .collection(FirestorePaths.families)
            .doc(familyId)
            .collection(FirestorePaths.tasks)
            .safeGet(timeout: const Duration(seconds: 15));
        tasksToMigrate.addAll(
          familyTasksSnap.docs.map((doc) => TaskSchedule.fromFirestore(doc)),
        );

        final familyInstancesSnap = await _fetchRecentInstances(
          _firestore
              .collection(FirestorePaths.families)
              .doc(familyId)
              .collection(FirestorePaths.instances),
          cutoffDate,
          label: 'family instances',
        );

        instancesToMigrate.addAll(
          familyInstancesSnap.docs.map(
            (doc) => TaskInstance.fromFirestore(doc),
          ),
        );

        final familyRecipesSnap = await _firestore
            .collection(FirestorePaths.families)
            .doc(familyId)
            .collection(FirestorePaths.recipes)
            .safeGet(timeout: const Duration(seconds: 15));
        for (final doc in familyRecipesSnap.docs) {
          if (doc.data().isNotEmpty) {
            final recipe = Recipe.fromFirestore(
              doc,
            ).copyWith(isFamily: doc.data()['isFamily'] as bool? ?? true);
            recipesToMigrate[recipe.id] = recipe;
          }
        }

        _logger?.info(
          'sync',
          '[Migration 3b] Family data fetched',
          data: {
            'durationMs': familyStepWatch.elapsedMilliseconds,
            'familyTasksCount': familyTasksSnap.docs.length,
            'familyInstancesCount': familyInstancesSnap.docs.length,
            'familyRecipesCount': familyRecipesSnap.docs.length,
          },
        );
      }

      final dirtyIdsToPreserve = <String>{};
      final wasFreeTier = _localDataSource.getIsActivePremium() == false;

      if (!isDifferentUser && !force) {
        _mergeLocalUnsynced<TaskSchedule>(
          targetList: tasksToMigrate,
          localItems: _localDataSource.getTasks(),
          dirtyIdsToPreserve: dirtyIdsToPreserve,
          wasFreeTier: wasFreeTier,
          idOf: (t) => t.id,
          updatedAtOf: (t) => t.updatedAt,
          hasPendingWritesOf: (t) => t.hasPendingWrites,
          markPending: (t) => t.copyWith(hasPendingWrites: true),
        );
        _mergeLocalUnsynced<TaskInstance>(
          targetList: instancesToMigrate,
          localItems: _localDataSource.getInstances(),
          dirtyIdsToPreserve: dirtyIdsToPreserve,
          wasFreeTier: wasFreeTier,
          idOf: (i) => i.id,
          updatedAtOf: (i) => i.updatedAt,
          hasPendingWritesOf: (i) => i.hasPendingWrites,
          markPending: (i) => i.copyWith(hasPendingWrites: true),
        );
        _mergeLocalUnsynced<Recipe>(
          targetList: null,
          targetMap: recipesToMigrate,
          localItems: _localDataSource.getRecipes(),
          dirtyIdsToPreserve: dirtyIdsToPreserve,
          wasFreeTier: wasFreeTier,
          idOf: (r) => r.id,
          updatedAtOf: (r) => r.updatedAt,
          hasPendingWritesOf: (r) => r.hasPendingWrites,
          markPending: (r) => r.copyWith(hasPendingWrites: true),
          preserveUnmodifiedLocal: true,
        );
      }

      // Clean slate: clear any existing local tasks/instances and dirty queues
      // before populating from Firestore to eliminate stale offline artifacts.
      _logger?.debug('sync', '[Migration 4/5] Clearing local Hive data...');
      final clearWatch = Stopwatch()..start();
      await _localDataSource.clearAllTasksAndInstances();
      final existingRecipeIds = _localDataSource
          .getRecipes()
          .map((r) => r.id)
          .toList();
      if (existingRecipeIds.isNotEmpty) {
        await _localDataSource.deleteRecipes(existingRecipeIds);
      }
      await _localDataSource.clearAllDirty();
      _logger?.info(
        'sync',
        '[Migration 4/5] Local Hive data cleared',
        data: {'durationMs': clearWatch.elapsedMilliseconds},
      );

      // Save all fresh items to Hive in batch
      _logger?.debug('sync', '[Migration 5/5] Saving fresh items to Hive...');
      final saveWatch = Stopwatch()..start();
      await _localDataSource.saveTasks(tasksToMigrate);
      await _localDataSource.saveInstances(instancesToMigrate);
      for (final recipe in recipesToMigrate.values) {
        await _localDataSource.saveRecipe(recipe);
      }
      for (final id in dirtyIdsToPreserve) {
        await _localDataSource.markDirty(id);
      }

      await _localDataSource.setActiveUserId(_userId);
      await _localDataSource.setIsActivePremium(true);
      await _localDataSource.setMigrationCompleted(true);
      _logger?.info(
        'sync',
        'Initial Firebase migration completed',
        data: {
          'tasksCount': tasksToMigrate.length,
          'instancesCount': instancesToMigrate.length,
          'recipesCount': recipesToMigrate.length,
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
      rethrow;
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchRecentInstances(
    CollectionReference<Map<String, dynamic>> colRef,
    DateTime cutoffDate, {
    String label = 'instances',
  }) async {
    try {
      final snap = await colRef
          .where('updatedAt', isGreaterThan: cutoffDate)
          .safeGet(timeout: const Duration(seconds: 15));
      if (snap.docs.isEmpty) {
        final fallbackSnap = await colRef
            .limit(300)
            .safeGet(timeout: const Duration(seconds: 15));
        if (fallbackSnap.docs.isNotEmpty) {
          return fallbackSnap;
        }
      }
      return snap;
    } catch (e) {
      _logger?.warning(
        'sync',
        'Failed to query $label with cutoffDate, falling back to limit(300)',
        error: e,
      );
      return colRef.limit(300).safeGet(timeout: const Duration(seconds: 15));
    }
  }

  void _mergeLocalUnsynced<T>({
    required List<T>? targetList,
    Map<String, T>? targetMap,
    required Iterable<T> localItems,
    required Set<String> dirtyIdsToPreserve,
    required bool wasFreeTier,
    required String Function(T) idOf,
    required DateTime Function(T) updatedAtOf,
    required bool Function(T) hasPendingWritesOf,
    required T Function(T) markPending,
    bool preserveUnmodifiedLocal = false,
  }) {
    final map = targetMap ?? {for (final item in targetList!) idOf(item): item};
    for (final local in localItems) {
      final id = idOf(local);
      final remote = map[id];
      final shouldPreserve = preserveUnmodifiedLocal
          ? (remote == null ||
                hasPendingWritesOf(local) ||
                updatedAtOf(local).isAfter(updatedAtOf(remote)))
          : ((wasFreeTier || hasPendingWritesOf(local)) &&
                (remote == null ||
                    !updatedAtOf(remote).isAfter(updatedAtOf(local))));
      if (shouldPreserve) {
        map[id] = markPending(local);
        dirtyIdsToPreserve.add(id);
      }
    }
    if (targetList != null) {
      targetList
        ..clear()
        ..addAll(map.values);
    }
  }
}
