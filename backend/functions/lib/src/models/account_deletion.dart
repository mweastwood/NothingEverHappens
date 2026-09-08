import 'package:meta/meta.dart';

/// User identity verified from Firebase Auth ID Token.
@immutable
class AuthenticatedUser {
  final String uid;
  final String? email;

  const AuthenticatedUser({
    required this.uid,
    this.email,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      if (email != null) 'email': email,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthenticatedUser &&
        other.uid == uid &&
        other.email == email;
  }

  @override
  int get hashCode => Object.hash(uid, email);
}

/// Authentication result for account deletion requests.
@immutable
class AccountDeletionAuthResult {
  final bool authenticated;
  final int? status;
  final String? error;
  final AuthenticatedUser? user;

  const AccountDeletionAuthResult({
    required this.authenticated,
    this.status,
    this.error,
    this.user,
  });
}

/// Final outcome of user account deletion cascading pipeline.
@immutable
class AccountDeletionResult {
  final bool success;
  final String message;
  final String userId;

  const AccountDeletionResult({
    required this.success,
    required this.message,
    required this.userId,
  });

  factory AccountDeletionResult.fromJson(Map<String, dynamic> json) {
    return AccountDeletionResult(
      success: json['success'] as bool? ?? false,
      message: (json['message'] as String?) ?? '',
      userId: (json['userId'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'userId': userId,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AccountDeletionResult &&
        other.success == success &&
        other.message == message &&
        other.userId == userId;
  }

  @override
  int get hashCode => Object.hash(success, message, userId);
}
