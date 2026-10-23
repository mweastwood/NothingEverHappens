import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nothing_ever_happens/logic/firestore_paths.dart';
import 'package:nothing_ever_happens/logic/task_label.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('FirestorePaths constants', () {
    test('defines all collection path names correctly', () {
      expect(FirestorePaths.users, equals('users'));
      expect(FirestorePaths.families, equals('families'));
      expect(FirestorePaths.tasks, equals('tasks'));
      expect(FirestorePaths.instances, equals('instances'));
      expect(FirestorePaths.settings, equals('settings'));
      expect(FirestorePaths.history, equals('history'));
      expect(FirestorePaths.invites, equals('invites'));
      expect(FirestorePaths.recipes, equals('recipes'));
      expect(FirestorePaths.labels, equals('labels'));
    });
  });

  group('FirestoreCollections helpers', () {
    final testLabel = TaskLabel.create(
      id: 'L-test-1',
      name: 'Errands',
      colorKey: 'coral',
      iconKey: 'tag',
    );

    test(
      'userLabels provides typed CollectionReference with converter',
      () async {
        final collection = FirestoreCollections.userLabels(
          fakeFirestore,
          'user123',
        );
        expect(collection.path, equals('users/user123/labels'));

        await collection.doc(testLabel.id).set(testLabel);

        final snap = await collection.doc(testLabel.id).get();
        expect(snap.exists, isTrue);
        expect(snap.data(), isNotNull);
        expect(snap.data()!.id, equals('L-test-1'));
        expect(snap.data()!.name, equals('Errands'));
        expect(snap.data()!.colorKey, equals('coral'));
        expect(snap.data()!.iconKey, equals('tag'));
      },
    );

    test(
      'familyLabels provides typed CollectionReference with converter',
      () async {
        final collection = FirestoreCollections.familyLabels(
          fakeFirestore,
          'fam456',
        );
        expect(collection.path, equals('families/fam456/labels'));

        final familyLabel = testLabel.copyWith(scope: TaskLabelScope.family);
        await collection.doc(familyLabel.id).set(familyLabel);

        final snap = await collection.doc(familyLabel.id).get();
        expect(snap.exists, isTrue);
        expect(snap.data(), isNotNull);
        expect(snap.data()!.id, equals('L-test-1'));
        expect(snap.data()!.name, equals('Errands'));
        expect(snap.data()!.scope, equals(TaskLabelScope.family));
      },
    );
  });
}
