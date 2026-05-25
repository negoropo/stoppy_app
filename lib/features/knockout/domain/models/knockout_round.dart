import 'dart:collection';

import 'knockout_match.dart';

enum KnockoutRoundStatus { pending, active, completed }

class KnockoutRound {
  KnockoutRound({
    required this.roundNumber,
    required this.startsAt,
    required this.endsAt,
    this.status = KnockoutRoundStatus.pending,
    List<KnockoutMatch> matches = const [],
    List<String> byePlayerIds = const [],
  }) : assert(roundNumber > 0),
       assert(startsAt.isBefore(endsAt)),
       matches = UnmodifiableListView(matches),
       byePlayerIds = UnmodifiableListView(byePlayerIds);

  final int roundNumber;

  final DateTime startsAt;
  final DateTime endsAt;

  final KnockoutRoundStatus status;

  final List<KnockoutMatch> matches;

  /// Players automatically advanced without a duel.
  final List<String> byePlayerIds;

  bool get isPending {
    return status == KnockoutRoundStatus.pending;
  }

  bool get isActive {
    return status == KnockoutRoundStatus.active;
  }

  bool get isCompleted {
    return status == KnockoutRoundStatus.completed;
  }

  KnockoutRound copyWith({
    int? roundNumber,
    DateTime? startsAt,
    DateTime? endsAt,
    KnockoutRoundStatus? status,
    List<KnockoutMatch>? matches,
    List<String>? byePlayerIds,
  }) {
    return KnockoutRound(
      roundNumber: roundNumber ?? this.roundNumber,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      status: status ?? this.status,
      matches: matches ?? this.matches,
      byePlayerIds: byePlayerIds ?? this.byePlayerIds,
    );
  }
}

extension KnockoutRoundStatusLabel on KnockoutRoundStatus {
  String get label {
    return switch (this) {
      KnockoutRoundStatus.pending => 'Pending',
      KnockoutRoundStatus.active => 'Active',
      KnockoutRoundStatus.completed => 'Completed',
    };
  }
}
