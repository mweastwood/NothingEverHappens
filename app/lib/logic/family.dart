import 'family_invite_status.dart';
import 'family_role.dart';
export 'family_invite_status.dart';
export 'family_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMember {
  final String userId;
  final String displayName;
  final String email;
  final FamilyRole role;

  const FamilyMember({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.role,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: FamilyRole.fromString(json['role'] as String? ?? 'non-parent'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'email': email,
      'role': role.toJson(),
    };
  }
}

class Family {
  final String id;
  final String name;
  final Map<String, FamilyMember> members;

  const Family({required this.id, required this.name, required this.members});

  factory Family.fromJson(Map<String, dynamic> json, String documentId) {
    final membersJson = json['members'] as Map<String, dynamic>? ?? {};
    final members = membersJson.map(
      (key, value) => MapEntry(
        key,
        FamilyMember.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );
    return Family(
      id: documentId,
      name: json['name'] as String? ?? '',
      members: members,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'members': members.map((key, value) => MapEntry(key, value.toJson())),
    };
  }
}

class FamilyInvite {
  final String id;
  final String familyId;
  final String familyName;
  final String fromEmail;
  final String fromName;
  final String toEmail;
  final FamilyRole role;
  final FamilyInviteStatus status;
  final DateTime createdAt;

  const FamilyInvite({
    required this.id,
    required this.familyId,
    required this.familyName,
    required this.fromEmail,
    required this.fromName,
    required this.toEmail,
    required this.role,
    required this.status,
    required this.createdAt,
  });

  factory FamilyInvite.fromJson(Map<String, dynamic> json, String documentId) {
    return FamilyInvite(
      id: documentId,
      familyId: json['familyId'] as String? ?? '',
      familyName: json['familyName'] as String? ?? '',
      fromEmail: json['fromEmail'] as String? ?? '',
      fromName: json['fromName'] as String? ?? '',
      toEmail: json['toEmail'] as String? ?? '',
      role: FamilyRole.fromString(json['role'] as String? ?? 'non-parent'),
      status: FamilyInviteStatus.fromString(
        json['status'] as String? ?? 'pending',
      ),
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'familyId': familyId,
      'familyName': familyName,
      'fromEmail': fromEmail,
      'fromName': fromName,
      'toEmail': toEmail,
      'role': role.toJson(),
      'status': status.toJson(),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
