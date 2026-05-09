class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.username,
    required this.createdAt,
    this.gamePoints = 5,
    this.lastDailyGpAwardedAt,
    this.adsRemoved = false,
    this.currentLeagueDivision,
    this.hasWeeklyLeagueEntry = false,
    this.reservedLeagueSlot = false,
  });

  final String id;
  final String username;
  final DateTime createdAt;
  final int gamePoints;
  final DateTime? lastDailyGpAwardedAt;
  final bool adsRemoved;
  final int? currentLeagueDivision;
  final bool hasWeeklyLeagueEntry;
  final bool reservedLeagueSlot;

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      gamePoints: json['gamePoints'] as int? ?? 5,
      lastDailyGpAwardedAt: json['lastDailyGpAwardedAt'] == null
          ? null
          : DateTime.parse(json['lastDailyGpAwardedAt'] as String),
      adsRemoved: json['adsRemoved'] as bool? ?? false,
      currentLeagueDivision: json['currentLeagueDivision'] as int?,
      hasWeeklyLeagueEntry: json['hasWeeklyLeagueEntry'] as bool? ?? false,
      reservedLeagueSlot: json['reservedLeagueSlot'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'createdAt': createdAt.toIso8601String(),
      'gamePoints': gamePoints,
      'lastDailyGpAwardedAt': lastDailyGpAwardedAt?.toIso8601String(),
      'adsRemoved': adsRemoved,
      'currentLeagueDivision': currentLeagueDivision,
      'hasWeeklyLeagueEntry': hasWeeklyLeagueEntry,
      'reservedLeagueSlot': reservedLeagueSlot,
    };
  }

  PlayerProfile copyWith({
    String? id,
    String? username,
    DateTime? createdAt,
    int? gamePoints,
    Object? lastDailyGpAwardedAt = _sentinel,
    bool? adsRemoved,
    Object? currentLeagueDivision = _sentinel,
    bool? hasWeeklyLeagueEntry,
    bool? reservedLeagueSlot,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
      gamePoints: (gamePoints ?? this.gamePoints).clamp(0, 999999),
      lastDailyGpAwardedAt: identical(lastDailyGpAwardedAt, _sentinel)
          ? this.lastDailyGpAwardedAt
          : lastDailyGpAwardedAt as DateTime?,
      adsRemoved: adsRemoved ?? this.adsRemoved,
      currentLeagueDivision: identical(currentLeagueDivision, _sentinel)
          ? this.currentLeagueDivision
          : currentLeagueDivision as int?,
      hasWeeklyLeagueEntry: hasWeeklyLeagueEntry ?? this.hasWeeklyLeagueEntry,
      reservedLeagueSlot: reservedLeagueSlot ?? this.reservedLeagueSlot,
    );
  }

  static const _sentinel = Object();
}
