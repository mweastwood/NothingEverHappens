enum FamilyInviteStatus {
  pending,
  accepted,
  declined;

  String toJson() => name;

  static FamilyInviteStatus fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'accepted':
        return FamilyInviteStatus.accepted;
      case 'declined':
        return FamilyInviteStatus.declined;
      case 'pending':
      default:
        return FamilyInviteStatus.pending;
    }
  }
}
