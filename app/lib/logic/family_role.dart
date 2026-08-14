enum FamilyRole {
  parent('parent'),
  nonParent('non-parent');

  final String value;
  const FamilyRole(this.value);

  String toJson() => value;

  static FamilyRole fromString(String? val) {
    if (val == 'parent') return FamilyRole.parent;
    return FamilyRole.nonParent;
  }
}
