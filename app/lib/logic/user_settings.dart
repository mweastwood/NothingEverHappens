class UserSettings {
  final double hoursAvailable;

  const UserSettings({required this.hoursAvailable});

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      hoursAvailable: (json['hoursAvailable'] as num?)?.toDouble() ?? 8.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'hoursAvailable': hoursAvailable};
  }

  UserSettings copyWith({double? hoursAvailable}) {
    return UserSettings(hoursAvailable: hoursAvailable ?? this.hoursAvailable);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettings &&
          runtimeType == other.runtimeType &&
          hoursAvailable == other.hoursAvailable;

  @override
  int get hashCode => hoursAvailable.hashCode;
}
