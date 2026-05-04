class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.username,
    required this.createdAt,
    this.gamePoints = 5,
    this.lastDailyGpAwardedAt,
  });

  final String id;
  final String username;
  final DateTime createdAt;
  final int gamePoints;
  final DateTime? lastDailyGpAwardedAt;

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      gamePoints: json['gamePoints'] as int? ?? 5,
      lastDailyGpAwardedAt: json['lastDailyGpAwardedAt'] == null
          ? null
          : DateTime.parse(json['lastDailyGpAwardedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'createdAt': createdAt.toIso8601String(),
      'gamePoints': gamePoints,
      'lastDailyGpAwardedAt': lastDailyGpAwardedAt?.toIso8601String(),
    };
  }

  PlayerProfile copyWith({
    String? id,
    String? username,
    DateTime? createdAt,
    int? gamePoints,
    Object? lastDailyGpAwardedAt = _sentinel,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
      gamePoints: gamePoints ?? this.gamePoints,
      lastDailyGpAwardedAt: identical(lastDailyGpAwardedAt, _sentinel)
          ? this.lastDailyGpAwardedAt
          : lastDailyGpAwardedAt as DateTime?,
    );
  }

  static const _sentinel = Object();
}
