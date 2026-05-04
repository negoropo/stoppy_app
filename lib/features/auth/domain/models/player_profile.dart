class PlayerProfile {
  const PlayerProfile({
    required this.id,
    required this.username,
    required this.createdAt,
  });

  final String id;
  final String username;
  final DateTime createdAt;

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      id: json['id'] as String,
      username: json['username'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  PlayerProfile copyWith({
    String? id,
    String? username,
    DateTime? createdAt,
  }) {
    return PlayerProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}