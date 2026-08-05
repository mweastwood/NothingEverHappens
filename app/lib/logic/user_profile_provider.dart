import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final userNameProvider = FutureProvider.family<String, String>((
  ref,
  userId,
) async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    return doc.data()?['displayName'] as String? ??
        doc.data()?['email'] as String? ??
        'User';
  } catch (e) {
    return 'User';
  }
});
