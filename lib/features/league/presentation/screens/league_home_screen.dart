import 'package:flutter/material.dart';

import '../../../auth/domain/models/player_profile.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/models/league_player_entry.dart';
import '../../domain/models/league_ranking_entry.dart';
import '../../domain/models/league_ranking_snapshot.dart';
import '../../domain/models/league_season_id.dart';
import '../../domain/models/player_league_records.dart';
import '../../domain/models/weekly_league_history_entry.dart';
import '../../domain/models/weekly_league_run.dart';
import '../../domain/repositories/league_repository.dart';
import '../../domain/services/league_division_policy.dart';
import '../../domain/services/weekly_league_settlement_schedule.dart';

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
  static const WeeklyLeagueSettlementSchedule _settlementSchedule =
      WeeklyLeagueSettlementSchedule();

  late PlayerProfile _playerProfile;
  LeaguePlayerEntry? _currentEntry;
  List<LeagueRankingEntry> _rankingPreview = const [];
  LeagueRankingSnapshot? _snapshot;
  PlayerLeagueRecords? _records;
  List<WeeklyLeagueHistoryEntry> _history = const [];
  List<WeeklyLeagueRun> _weeklyRuns = const [];
  bool _isLoading = true;
  bool _isEntering = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _playerProfile = widget.playerProfile;
    _loadLeagueState();
  }

  Future<void> _loadLeagueState({bool clearMessage = true}) async {
    setState(() {
      _isLoading = true;
      if (clearMessage) {
        _message = null;
      }
    });

    final entry = await widget.leagueRepository.currentEntry(_playerProfile.id);
    final divisionNumber =
        entry?.divisionNumber ?? _playerProfile.currentLeagueDivision ?? 2;

    final rankingFuture = widget.leagueRepository.fetchDivisionRanking(
      divisionNumber,
    );
    final recordsFuture = widget.leagueRepository.fetchPlayerRecords(
      _playerProfile.id,
    );
    final historyFuture = widget.leagueRepository.fetchPlayerHistory(
      _playerProfile.id,
    );
    final weeklyRunsFuture = widget.leagueRepository.fetchPlayerWeeklyRuns(
      playerId: _playerProfile.id,
      seasonId: LeagueSeasonId.fromDate(DateTime.now()),
    );
    final snapshotFuture = entry == null
        ? Future<LeagueRankingSnapshot?>.value()
        : widget.leagueRepository.fetchPlayerSnapshot(
            playerId: _playerProfile.id,
            divisionNumber: entry.divisionNumber,
          );

    final results = await Future.wait([
      rankingFuture,
      recordsFuture,
      historyFuture,
      weeklyRunsFuture,
      snapshotFuture,
    ]);

    final ranking = results[0] as List<LeagueRankingEntry>;
    final records = results[1] as PlayerLeagueRecords;
    final history = results[2] as List<WeeklyLeagueHistoryEntry>;
    final weeklyRuns = results[3] as List<WeeklyLeagueRun>;
    final snapshot = results[4] as LeagueRankingSnapshot?;

    if (!mounted) {
      return;
    }

    setState(() {
      _currentEntry = entry;
      _rankingPreview = ranking.take(_rankingPreviewCount).toList();
      _snapshot = snapshot;
      _records = records;
      _history = history;
      _weeklyRuns = weeklyRuns;
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
        gamePoints: (_playerProfile.gamePoints -
            LeagueDivisionPolicy.weeklyEntryCostGamePoints)
            .clamp(0, 999999999),
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
      await _loadLeagueState(clearMessage: false);
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
        entry?.divisionNumber ?? _playerProfile.currentLeagueDivision ?? 1;
    final hasActiveEntry = entry?.isActive ?? false;
    final hasReservedSlot = entry?.hasReservedSlot ?? false;
    final nextSettlementTime = _settlementSchedule.settlementTimeForSeason(
      LeagueSeasonId.fromDate(DateTime.now()),
    );

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
                    hasReservedSlot: hasReservedSlot,
                    message: _message,
                    isEntering: _isEntering,
                    onEnter: hasActiveEntry ? null : _enterWeeklyLeague,
                  ),
                  const SizedBox(height: 12),
                  _RankingPreviewCard(entries: _rankingPreview),
                  if (_records != null) ...[
                    const SizedBox(height: 12),
                    _PersonalRecordsCard(records: _records!),
                  ],
                  const SizedBox(height: 12),
                  _WeeklyRunsCard(runs: _weeklyRuns),
                  const SizedBox(height: 12),
                  _SettlementInfoCard(
                    latestHistoryEntry: _history.isEmpty
                        ? null
                        : _history.first,
                    nextSettlementTime: nextSettlementTime,
                  ),
                  if (_snapshot != null) ...[
                    const SizedBox(height: 12),
                    _WeeklyScoreBreakdownCard(
                      entry: _snapshot!.currentPlayerEntry,
                    ),
                    const SizedBox(height: 12),
                    _PlayerSnapshotCard(snapshot: _snapshot!),
                    const SizedBox(height: 12),
                    _NearbyRankingCard(snapshot: _snapshot!),
                  ],
                  const SizedBox(height: 12),
                  _LeagueHistoryCard(entries: _history),
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
    required this.hasReservedSlot,
    required this.message,
    required this.isEntering,
    required this.onEnter,
  });

  final int divisionNumber;
  final int gamePoints;
  final bool hasActiveEntry;
  final bool hasReservedSlot;
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
          Text(_statusText(), style: _LeagueTextStyles.body),
          if (!hasReservedSlot) ...[
            const SizedBox(height: 4),
            const Text(
              'You are outside the weekly league. Re-enter to reserve a slot again.',
              style: _LeagueTextStyles.body,
            ),
          ],
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(message!, style: _LeagueTextStyles.message),
          ],
          const SizedBox(height: 12),
          FilledButton(
            onPressed: isEntering ? null : onEnter,
            child: Text(_actionText()),
          ),
        ],
      ),
    );
  }

  String _statusText() {
    if (hasActiveEntry) {
      return 'Entry status: active';
    }

    if (hasReservedSlot) {
      return 'Entry status: reserved, entry not paid';
    }

    return 'League status: outside league';
  }

  String _actionText() {
    if (hasActiveEntry) {
      return 'Entered';
    }

    return hasReservedSlot ? 'Enter Weekly League' : 'Re-enter Weekly League';
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
            ...entries.map((entry) {
              final inactiveLabel = entry.isInactive ? ' (inactive)' : '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '#${entry.rank} ${entry.playerEntry.username}$inactiveLabel - ${entry.displayScore}',
                  style: _LeagueTextStyles.body,
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _PersonalRecordsCard extends StatelessWidget {
  const _PersonalRecordsCard({required this.records});

  final PlayerLeagueRecords records;

  @override
  Widget build(BuildContext context) {
    return _LeagueCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Personal Records', style: _LeagueTextStyles.title),
          const SizedBox(height: 10),
          Text(
            'All-time best final score: ${records.allTimeBestFinalScore}',
            style: _LeagueTextStyles.body,
          ),
          Text(
            'Current weekly best score: ${records.currentWeeklyBestScore}',
            style: _LeagueTextStyles.body,
          ),
        ],
      ),
    );
  }
}

class _WeeklyRunsCard extends StatelessWidget {
  const _WeeklyRunsCard({required this.runs});

  final List<WeeklyLeagueRun> runs;

  @override
  Widget build(BuildContext context) {
    return _LeagueCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Runs', style: _LeagueTextStyles.title),
          const SizedBox(height: 10),
          if (runs.isEmpty)
            const Text(
              'No weekly league runs yet.',
              style: _LeagueTextStyles.body,
            )
          else
            ...runs.asMap().entries.map((entry) {
              final index = entry.key;
              final run = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 34,
                      child: Text(
                        '${index + 1}º',
                        style: _LeagueTextStyles.highlight,
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: Text(
                        '${run.score}',
                        textAlign: TextAlign.right,
                        style: _LeagueTextStyles.body,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      _completedAtText(run.completedAt),
                      style: _LeagueTextStyles.body,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  String _completedAtText(DateTime completedAt) {
    final local = completedAt.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
  }
}

class _LeagueHistoryCard extends StatelessWidget {
  const _LeagueHistoryCard({required this.entries});

  final List<WeeklyLeagueHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return _LeagueCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('League History', style: _LeagueTextStyles.title),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            const Text(
              'No completed weekly seasons yet.',
              style: _LeagueTextStyles.body,
            )
          else
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${entry.seasonId.value} - Division ${entry.finalDivision} - '
                  '#${entry.finalRank} - ${_settlementResultLabel(entry.result)} - '
                  '${entry.finalWeeklyScore.round()}',
                  style: _LeagueTextStyles.body,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettlementInfoCard extends StatelessWidget {
  const _SettlementInfoCard({
    required this.latestHistoryEntry,
    required this.nextSettlementTime,
  });

  final WeeklyLeagueHistoryEntry? latestHistoryEntry;
  final DateTime nextSettlementTime;

  @override
  Widget build(BuildContext context) {
    final historyEntry = latestHistoryEntry;

    return _LeagueCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Settlement', style: _LeagueTextStyles.title),
          const SizedBox(height: 10),
          Text(
            'Next weekly settlement: ${_settlementTimeText(nextSettlementTime)} Europe/Lisbon time',
            style: _LeagueTextStyles.body,
          ),
          const SizedBox(height: 10),
          if (historyEntry == null)
            const Text(
              'Last settlement: none yet.',
              style: _LeagueTextStyles.body,
            )
          else ...[
            Text(
              'Last settlement: ${_historyDateText(historyEntry)}',
              style: _LeagueTextStyles.body,
            ),
            Text(
              'Result: ${_settlementResultLabel(historyEntry.result)}',
              style: _LeagueTextStyles.body,
            ),
            Text(
              'Final division: ${historyEntry.finalDivision}',
              style: _LeagueTextStyles.body,
            ),
            Text(
              'Final rank: #${historyEntry.finalRank}',
              style: _LeagueTextStyles.body,
            ),
            Text(
              'Final weekly score: ${historyEntry.finalWeeklyScore.round()}',
              style: _LeagueTextStyles.body,
            ),
          ],
        ],
      ),
    );
  }

  String _settlementTimeText(DateTime settlementTime) {
    final local = settlementTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '${_weekdayName(local.weekday)} $hour:$minute';
  }

  String _weekdayName(int weekday) {
    return switch (weekday) {
      DateTime.monday => 'Monday',
      DateTime.tuesday => 'Tuesday',
      DateTime.wednesday => 'Wednesday',
      DateTime.thursday => 'Thursday',
      DateTime.friday => 'Friday',
      DateTime.saturday => 'Saturday',
      DateTime.sunday => 'Sunday',
      _ => 'Sunday',
    };
  }

  String _historyDateText(WeeklyLeagueHistoryEntry entry) {
    final date = (entry.seasonEndedAt ?? entry.seasonId.weekStartDate)
        .toLocal();
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}

String _settlementResultLabel(WeeklyLeagueSeasonResult result) {
  return switch (result) {
    WeeklyLeagueSeasonResult.promoted => 'promoted',
    WeeklyLeagueSeasonResult.relegated => 'relegated',
    WeeklyLeagueSeasonResult.stayed => 'stayed',
    WeeklyLeagueSeasonResult.removedFromLeague => 'removed from league',
    WeeklyLeagueSeasonResult.lostReservedSlot => 'lost reserved slot',
  };
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
            'Promotion zone: ${_zoneText(snapshot.promotionZoneEndRank, isPromotion: true)}',
            style: _LeagueTextStyles.body,
          ),
          Text(
            'Relegation zone: ${_zoneText(snapshot.relegationZoneStartRank, isPromotion: false)}',
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

  String _zoneText(int? rank, {required bool isPromotion}) {
    if (rank == null) {
      return 'N/A';
    }

    return isPromotion ? '#1-#$rank' : '#$rank and below';
  }
}

class _WeeklyScoreBreakdownCard extends StatelessWidget {
  const _WeeklyScoreBreakdownCard({required this.entry});

  final LeagueRankingEntry entry;

  @override
  Widget build(BuildContext context) {
    final score = entry.weeklyScore;

    return _LeagueCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weekly Score', style: _LeagueTextStyles.title),
          const SizedBox(height: 10),
          Text('Weekly runs: ${score.runCount}', style: _LeagueTextStyles.body),
          Text(
            'Best runs used: ${score.bestRunsCount}',
            style: _LeagueTextStyles.body,
          ),
          Text(
            'Average of selected best runs: ${_scoreText(score.baseScore)}',
            style: _LeagueTextStyles.body,
          ),
          Text(
            'Active days this week: ${score.activeDays}',
            style: _LeagueTextStyles.body,
          ),
          Text(
            'Activity multiplier: x${score.activityMultiplier.toStringAsFixed(1)}',
            style: _LeagueTextStyles.body,
          ),
          Text(
            'Final weekly score: ${_scoreText(score.finalScore)}',
            style: _LeagueTextStyles.body,
          ),
        ],
      ),
    );
  }

  String _scoreText(double score) {
    if (score == score.roundToDouble()) {
      return score.round().toString();
    }

    return score.toStringAsFixed(1);
  }
}

class _NearbyRankingCard extends StatelessWidget {
  const _NearbyRankingCard({required this.snapshot});

  final LeagueRankingSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final visibleEntries = [
      ...snapshot.playersAbove.reversed,
      snapshot.currentPlayerEntry,
      ...snapshot.playersBelow,
    ];

    return _LeagueCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nearby Ranking', style: _LeagueTextStyles.title),
          const SizedBox(height: 10),
          ...visibleEntries.map(
            (entry) => _NearbyRankingRow(
              entry: entry,
              isCurrentPlayer:
                  entry.playerEntry.playerId ==
                  snapshot.currentPlayerEntry.playerEntry.playerId,
              promotionZoneEndRank: snapshot.promotionZoneEndRank,
              relegationZoneStartRank: snapshot.relegationZoneStartRank,
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyRankingRow extends StatelessWidget {
  const _NearbyRankingRow({
    required this.entry,
    required this.isCurrentPlayer,
    required this.promotionZoneEndRank,
    required this.relegationZoneStartRank,
  });

  final LeagueRankingEntry entry;
  final bool isCurrentPlayer;
  final int? promotionZoneEndRank;
  final int? relegationZoneStartRank;

  @override
  Widget build(BuildContext context) {
    final zoneLabel = _zoneLabel();

    return Container(
      key: isCurrentPlayer ? const Key('current-player-ranking-row') : null,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: isCurrentPlayer ? const Color(0x334FC3F7) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isCurrentPlayer ? const Color(0xFF4FC3F7) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '#${entry.rank} ${entry.playerEntry.username}'
              '${entry.isInactive ? ' (inactive)' : ''}'
              '${isCurrentPlayer ? ' (You)' : ''}',
              style: isCurrentPlayer
                  ? _LeagueTextStyles.highlight
                  : _LeagueTextStyles.body,
            ),
          ),
          if (zoneLabel != null) ...[
            Text(zoneLabel, style: _LeagueTextStyles.zone),
            const SizedBox(width: 10),
          ],
          Text(entry.displayScore, style: _LeagueTextStyles.body),
        ],
      ),
    );
  }

  String? _zoneLabel() {
    if (promotionZoneEndRank != null && entry.rank <= promotionZoneEndRank!) {
      return 'promotion';
    }

    if (relegationZoneStartRank != null &&
        entry.rank >= relegationZoneStartRank!) {
      return 'relegation';
    }

    return null;
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

  static const highlight = TextStyle(
    color: Color(0xFF7CC7FF),
    fontSize: 14,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );

  static const zone = TextStyle(
    color: Color(0xFFFFD166),
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
  );
}
