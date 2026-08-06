import os

def replace_in_file(path, old, new):
    with open(path, 'r') as f:
        content = f.read()
    content = content.replace(old, new)
    with open(path, 'w') as f:
        f.write(content)

# 1. family.dart
old_family = "import 'package:cloud_firestore/cloud_firestore.dart';"
new_family = """import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyProfile {
  final String familyId;
  final String familyRole;

  const FamilyProfile({
    required this.familyId,
    required this.familyRole,
  });

  factory FamilyProfile.fromJson(Map<String, dynamic> json) {
    return FamilyProfile(
      familyId: json['familyId'] as String? ?? '',
      familyRole: json['familyRole'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'familyId': familyId,
      'familyRole': familyRole,
    };
  }
}"""
replace_in_file('app/lib/logic/family.dart', old_family, new_family)

# 2. family_repository.dart
old_repo = """  Stream<DocumentSnapshot<Map<String, dynamic>>> getProfile() {
    return _firestore.collection('users').doc(_userId).snapshots();
  }"""
new_repo = """  Stream<FamilyProfile> getProfile() {
    return _firestore.collection('users').doc(_userId).snapshots().map(
      (snapshot) => FamilyProfile.fromJson(snapshot.data() ?? {}),
    );
  }"""
replace_in_file('app/lib/logic/family_repository.dart', old_repo, new_repo)

# 3. family_screen.dart
old_screen1 = """    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: familyRepo.getProfile(),"""
new_screen1 = """    return StreamBuilder<FamilyProfile>(
      stream: familyRepo.getProfile(),"""

old_screen2 = """        final profileData = profileSnapshot.data?.data() ?? {};
        final familyId = profileData['familyId'] as String? ?? '';
        final familyRole = profileData['familyRole'] as String? ?? '';"""
new_screen2 = """        final profile = profileSnapshot.data ?? const FamilyProfile(familyId: '', familyRole: '');
        final familyId = profile.familyId;
        final familyRole = profile.familyRole;"""

replace_in_file('app/lib/screens/family_screen.dart', old_screen1, new_screen1)
replace_in_file('app/lib/screens/family_screen.dart', old_screen2, new_screen2)

# 4. create_task_screen.dart
old_create1 = """import '../logic/family_repository.dart';
import '../logic/undo_notifier.dart';"""
new_create1 = """import '../logic/family_repository.dart';
import '../logic/family.dart';
import '../logic/undo_notifier.dart';"""

old_create2 = """    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: familyRepo?.getProfile() ?? const Stream.empty(),
      builder: (context, snapshot) {
        final profileData = snapshot.data?.data() ?? {};
        final familyId = profileData['familyId'] as String? ?? '';
        final familyRole = profileData['familyRole'] as String? ?? '';"""
new_create2 = """    return StreamBuilder<FamilyProfile>(
      stream: familyRepo?.getProfile() ?? const Stream.empty(),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? const FamilyProfile(familyId: '', familyRole: '');
        final familyId = profile.familyId;
        final familyRole = profile.familyRole;"""

replace_in_file('app/lib/screens/create_task_screen.dart', old_create1, new_create1)
replace_in_file('app/lib/screens/create_task_screen.dart', old_create2, new_create2)

print("Done replacing.")
