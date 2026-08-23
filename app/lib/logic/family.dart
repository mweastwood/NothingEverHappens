import 'family_invite_status.dart';
import 'family_role.dart';
export 'family_invite_status.dart';
export 'family_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyProfile {
  final String familyId;
  final String familyRole;

  const FamilyProfile({required this.familyId, required this.familyRole});

  factory FamilyProfile.fromJson(Map<String, dynamic> json) {
    return FamilyProfile(
      familyId: json['familyId'] as String? ?? '',
      familyRole: json['familyRole'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'familyId': familyId, 'familyRole': familyRole};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FamilyProfile &&
        other.familyId == familyId &&
        other.familyRole == familyRole;
  }

  @override
  int get hashCode => Object.hash(familyId, familyRole);
}

class FamilyMember {
  final String userId;
  final String displayName;
  final String email;
  final FamilyRole role;
  final String? appVersion;
  final String? platform;
  final DateTime? lastSeenAt;

  const FamilyMember({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.role,
    this.appVersion,
    this.platform,
    this.lastSeenAt,
  });

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    final lastSeenAtRaw = json['lastSeenAt'];
    DateTime? lastSeenAt;
    if (lastSeenAtRaw != null) {
      if (lastSeenAtRaw is Timestamp) {
        lastSeenAt = lastSeenAtRaw.toDate();
      } else if (lastSeenAtRaw is String) {
        lastSeenAt = DateTime.tryParse(lastSeenAtRaw);
      } else if (lastSeenAtRaw is int) {
        lastSeenAt = DateTime.fromMillisecondsSinceEpoch(lastSeenAtRaw);
      }
    }

    return FamilyMember(
      userId: json['userId'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: FamilyRole.fromString(json['role'] as String? ?? 'non-parent'),
      appVersion: json['appVersion'] as String?,
      platform: json['platform'] as String?,
      lastSeenAt: lastSeenAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'displayName': displayName,
      'email': email,
      'role': role.toJson(),
      if (appVersion != null) 'appVersion': appVersion,
      if (platform != null) 'platform': platform,
      if (lastSeenAt != null)
        'lastSeenAt': lastSeenAt!.toUtc().toIso8601String(),
    };
  }

  FamilyMember copyWith({
    String? userId,
    String? displayName,
    String? email,
    FamilyRole? role,
    String? appVersion,
    String? platform,
    DateTime? lastSeenAt,
  }) {
    return FamilyMember(
      userId: userId ?? this.userId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
      appVersion: appVersion ?? this.appVersion,
      platform: platform ?? this.platform,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
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
