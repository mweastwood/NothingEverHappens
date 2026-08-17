import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'family_repository.dart';
import 'task_repository.dart';

String extractFirstName(String rawName) {
  final trimmed = rawName.trim();
  if (trimmed.isEmpty) return 'User';
  if (trimmed.contains('@')) {
    final localPart = trimmed.split('@').first;
    final namePart = localPart
        .split(RegExp(r'[\s._-]'))
        .firstWhere((part) => part.isNotEmpty, orElse: () => localPart);
    return namePart.isNotEmpty ? namePart : 'User';
  }
  final parts = trimmed.split(RegExp(r'\s+'));
  return parts.first.isNotEmpty ? parts.first : 'User';
}

final userNameProvider = FutureProvider.family<String, String>((
  ref,
  userId,
) async {
  try {
    // 1. Family Member Resolution
    try {
      final familyProfile = await ref.watch(familyProfileStreamProvider.future);
      final familyId = familyProfile?.familyId;
      if (familyId != null && familyId.isNotEmpty) {
        final family = await ref.watch(familyStreamProvider(familyId).future);
        final member = family?.members[userId];
        if (member != null) {
          if (member.displayName.trim().isNotEmpty) {
            return extractFirstName(member.displayName);
          }
          if (member.email.trim().isNotEmpty) {
            return extractFirstName(member.email);
          }
        }
      }
    } catch (_) {
      // Continue to next resolution strategy
    }

    // 2. Current Authenticated User Resolution
    try {
      final authUser = await ref.watch(authStateProvider.future);
      if (authUser != null && authUser.uid == userId) {
        if (authUser.displayName != null &&
            authUser.displayName!.trim().isNotEmpty) {
          return extractFirstName(authUser.displayName!);
        }
        if (authUser.email != null && authUser.email!.trim().isNotEmpty) {
          return extractFirstName(authUser.email!);
        }
      }
    } catch (_) {
      // Continue to next resolution strategy
    }

    // 3. Firestore Fallback
    try {
      final firestore =
          ref.watch(firestoreProvider) ?? FirebaseFirestore.instance;
      final doc = await firestore.collection('users').doc(userId).get();
      final data = doc.data();
      final displayName = data?['displayName'] as String?;
      if (displayName != null && displayName.trim().isNotEmpty) {
        return extractFirstName(displayName);
      }
      final email = data?['email'] as String?;
      if (email != null && email.trim().isNotEmpty) {
        return extractFirstName(email);
      }
    } catch (_) {
      // Ignore firestore errors and fall back to 'User'
    }

    return 'User';
  } catch (e) {
    return 'User';
  }
});
