import 'package:flutter/material.dart';

import '../../../auth/domain/models/player_profile.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/models/league_player_entry.dart';
import '../../domain/models/league_ranking_entry.dart';
import '../../domain/models/league_ranking_snapshot.dart';
import '../../domain/repositories/league_repository.dart';
import '../../domain/services/league_division_policy.dart';

class LeagueHomeScreen extends StatefulWidget {
  const LeagueHomeScreen({
    super.key,
    required this.playerProfile,
    required this.authRepository,
    required this.leagueRepository,
    required this.onPlayerProfileUpdated,
  });

  final PlayerProfile playerProfile;
  final AuthRepository authRepository;
  final LeagueRepository leagueRepository;
  final ValueSetter<PlayerProfile> onPlayerProfileUpdated;

  @override
  State<LeagueHomeScreen> createState() => _LeagueHomeScreenState();
}

class _LeagueHomeScreenState extends State<LeagueHomeScreen> {
  static const int _rankingPreviewCount = 5;

  late PlayerProfile _playerProfile;
  LeaguePlayerEntry? _currentEntry;
  List<LeagueRankingEntry> _rankingPreview = const [];
  LeagueRankingSnapshot? _snapshot;
  bool _isLoading = true;
  bool _isEntering = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _playerProfile = widget.playerProfile;
    _loadLeagueState();
  }

  Future<void> _loadLeagueState() async {
    setState(() {
      _isLoading = true;
      _message = null;
    });

    final entry = await widget.leagueRepository.currentEntry(_playerProfile.id);
    final divisionNumber =
        entry?.divisionNumber ?? _playerProfile.currentLeagueDivision ?? 2;
    final ranking = await widget.leagueRepository.fetchDivisionRanking(
      divisionNumber,
    );
    LeagueRankingSnapshot? snapshot;
    if (entry != null) {
      snapshot = await widget.leagueRepository.fetchPlayerSnapshot(
        playerId: _playerProfile.id,
        divisionNumber: entry.divisionNumber,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _currentEntry = entry;
      _rankingPreview = ranking.take(_rankingPreviewCount).toList();
      _snapshot = snapshot;
      _isLoading = false;
    });
  }

  Future<void> _enterWeeklyLeague() async {
    if (_currentEntry?.isActive ?? _playerProfile.hasWeeklyLeagueEntry) {
      setState(() {
        _message = 'Weekly league entry already active.';
      });
      return;
    }

    if (_playerProfile.gamePoints <
        LeagueDivisionPolicy.weeklyEntryCostGamePoints) {
      setState(() {
        _message = 'You need 10 GP to enter the weekly league.';
      });
      return;
    }

    setState(() {
      _isEntering = true;
      _message = null;
    });

    try {
      final entry = await widget.leagueRepository.enterWeeklyLeague(
        _playerProfile,
      );
      final updatedProfile = _playerProfile.copyWith(
        gamePoints:
            _playerProfile.gamePoints -
            LeagueDivisionPolicy.weeklyEntryCostGamePoints,
        currentLeagueDivision: entry.divisionNumber,
        hasWeeklyLeagueEntry: true,
        reservedLeagueSlot: entry.hasReservedSlot,
      );
      await widget.authRepository.updatePlayerProfile(updatedProfile);
      widget.onPlayerProfileUpdated(updatedProfile);

      if (!mounted) {
        return;
      }

      setState(() {
        _playerProfile = updatedProfile;
        _currentEntry = entry;
        _message = 'Weekly league entry confirmed.';
      });
      await _loadLeagueState();
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _message = 'Could not enter weekly league. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isEntering = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = _currentEntry;
    final divisionNumber =
        entry?.divisionNumber ?? _playerProfile.currentLeagueDivision ?? 2;
    final hasActiveEntry =
        entry?.isActive ?? _playerProfile.hasWeeklyLeagueEntry;

    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      appBar: AppBar(
        title: const Text('Weekly League'),
        backgroundColor: const Color(0xFF101418),
        foregroundColor: const Color(0xFFD6DEE8),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _LeagueSummaryCard(
                    divisionNumber: divisionNumber,
                    gamePoints: _playerProfile.gamePoints,
                    hasActiveEntry: hasActiveEntry,
                    message: _message,
                    isEntering: _isEntering,
                    onEnter: hasActiveEntry ? null : _enterWeeklyLeague,
                  ),
                  const SizedBox(height: 12),
                  _RankingPreviewCard(entries: _rankingPreview),
                  if (_snapshot != null) ...[
                    const SizedBox(height: 12),
                    _PlayerSnapshotCard(snapshot: _snapshot!),
                  ],
                ],
              ),
      ),
    );
  }
}

class _LeagueSummaryCard extends StatelessWidget {
  const _LeagueSummaryCard({
    required this.divisionNumber,
    required this.gamePoints,
    required this.hasActiveEntry,
    required this.message,
    required this.isEntering,
    required this.onEnter,
  });

  final int divisionNumber;
  final int gamePoints;
  final bool hasActiveEntry;
  final String? message;
  final bool isEntering;
  final VoidCallback? onEnter;

  @override
  Widget build(BuildContext context) {
    return _LeagueCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Division $divisionNumber', style: _LeagueTextStyles.title),
          const SizedBox(height: 8),
          Text('GP: $gamePoints', style: _LeagueTextStyles.body),
          const SizedBox(height: 4),
          Text(
            'Weekly entry cost: ${LeagueDivisionPolicy.weeklyEntryCostGamePoints} GP',
            style: _LeagueTextStyles.body,
          ),
          const SizedBox(height: 4),
          Text(
            hasActiveEntry ? 'Entry: active' : 'Entry: not paid',
            style: _LeagueTextStyles.body,
          ),
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(message!, style: _LeagueTextStyles.message),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: isEntering ? null : onEnter,
            child: Text(hasActiveEntry ? 'Entered' : 'Enter Weekly League'),
          ),
        ],
      ),
    );
  }
}

class _RankingPreviewCard extends StatelessWidget {
  const _RankingPreviewCard({required this.entries});

  final List<LeagueRankingEntry> entries;

  @override
  Widget build(BuildContext context) {
    return _LeagueCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ranking Preview', style: _LeagueTextStyles.title),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            const Text('No ranking entries yet.', style: _LeagueTextStyles.body)
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '#${entry.rank} ${entry.playerEntry.username} - ${entry.displayScore}',
                  style: _LeagueTextStyles.body,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlayerSnapshotCard extends StatelessWidget {
  const _PlayerSnapshotCard({required this.snapshot});

  final LeagueRankingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return _LeagueCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your Snapshot', style: _LeagueTextStyles.title),
          const SizedBox(height: 10),
          Text(
            'Rank: #${snapshot.currentPlayerRank}',
            style: _LeagueTextStyles.body,
          ),
          Text(
            'Score: ${snapshot.currentPlayerEntry.displayScore}',
            style: _LeagueTextStyles.body,
          ),
          Text(
            'Active days: ${snapshot.currentPlayerEntry.weeklyScore.activeDays}',
            style: _LeagueTextStyles.body,
          ),
          Text(
            'Multiplier: x${snapshot.currentPlayerEntry.weeklyScore.activityMultiplier.toStringAsFixed(1)}',
            style: _LeagueTextStyles.body,
          ),
          const SizedBox(height: 8),
          Text(
            'Promotion need: ${_scoreText(snapshot.scoreNeededForPromotionZone)}',
            style: _LeagueTextStyles.body,
          ),
          Text(
            'Stay need: ${_scoreText(snapshot.scoreNeededToStayInDivision)}',
            style: _LeagueTextStyles.body,
          ),
        ],
      ),
    );
  }

  String _scoreText(double? score) {
    if (score == null) {
      return 'N/A';
    }

    return score.ceil().toString();
  }
}

class _LeagueCard extends StatelessWidget {
  const _LeagueCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xEE1B222B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A424C)),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _LeagueTextStyles {
  static const title = TextStyle(
    color: Color(0xFFFFD166),
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );

  static const body = TextStyle(
    color: Color(0xFFD6DEE8),
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static const message = TextStyle(
    color: Color(0xFF7CC7FF),
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
}
