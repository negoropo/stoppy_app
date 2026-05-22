import '../models/knockout_player_entry.dart';

class KnockoutRepechageCandidate {
  const KnockoutRepechageCandidate({
    required this.entry,
    required this.eliminatedScore,
  }) : assert(eliminatedScore >= 0);

  final KnockoutPlayerEntry entry;
  final double eliminatedScore;
}

class KnockoutRepechageSelector {
  const KnockoutRepechageSelector();

  List<KnockoutPlayerEntry> selectReplacementAdvancements({
    required List<KnockoutRepechageCandidate> eliminatedCandidates,
    required int neededCount,
  }) {
    assert(neededCount >= 0);

    if (neededCount == 0 || eliminatedCandidates.isEmpty) {
      return const [];
    }

    final sortedCandidates = [...eliminatedCandidates]..sort(_compare);

    return sortedCandidates
        .take(neededCount)
        .map((candidate) => candidate.entry)
        .toList();
  }

  int _compare(KnockoutRepechageCandidate a, KnockoutRepechageCandidate b) {
    return _compareDescending(a.eliminatedScore, b.eliminatedScore)
        .ifEqual(
      _compareDescending(
        a.entry.lifetimeRunCount,
        b.entry.lifetimeRunCount,
      ),
    )
        .ifEqual(
      _compareDescending(
        a.entry.lifetimeAverageRunScore,
        b.entry.lifetimeAverageRunScore,
      ),
    )
        .ifEqual(a.entry.accountCreatedAt.compareTo(b.entry.accountCreatedAt));
  }

  int _compareDescending(num a, num b) {
    return b.compareTo(a);
  }
}

extension on int {
  int ifEqual(int fallback) {
    if (this != 0) {
      return this;
    }

    return fallback;
  }
}