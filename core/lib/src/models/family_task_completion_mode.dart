enum FamilyCompletionMode {
  anyone, // One person checks off for everybody (default)
  individual; // Everybody needs to check off individually

  static FamilyCompletionMode fromString(String? value) {
    if (value == null) return FamilyCompletionMode.anyone;
    final normalized = value.toLowerCase().trim();
    return FamilyCompletionMode.values.firstWhere(
      (e) => e.name.toLowerCase() == normalized,
      orElse: () => FamilyCompletionMode.anyone,
    );
  }
}
