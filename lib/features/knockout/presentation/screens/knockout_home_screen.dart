import 'package:flutter/material.dart';

import '../../../auth/domain/models/player_profile.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../league/domain/models/player_league_achievements.dart';
import '../../../league/domain/repositories/league_repository.dart';
import '../../domain/models/knockout_hall_of_fame_entry.dart';
import '../../domain/models/knockout_player_entry.dart';
import '../../domain/models/knockout_player_records.dart';
import '../../domain/models/knockout_player_status.dart';
import '../../domain/models/knockout_tournament.dart';
import '../../domain/models/knockout_tournament_history_entry.dart';
import '../../domain/repositories/knockout_repository.dart';
import '../../../../core/utils/date_time_formatter.dart';

class KnockoutHomeScreen extends StatefulWidget {
  const KnockoutHomeScreen({
    super.key,
    required this.playerProfile,
    required this.authRepository,
    required this.knockoutRepository,
    required this.onPlayerProfileUpdated,
    this.leagueRepository,
    this.onPlayTournamentRun,
  });

  final PlayerProfile playerProfile;
  final AuthRepository authRepository;
  final KnockoutRepository knockoutRepository;
  final ValueSetter<PlayerProfile> onPlayerProfileUpdated;
  final LeagueRepository? leagueRepository;
  final VoidCallback? onPlayTournamentRun;

  @override
  State<KnockoutHomeScreen> createState() => _KnockoutHomeScreenState();
}

class _KnockoutHomeScreenState extends State<KnockoutHomeScreen> {
  late PlayerProfile _playerProfile;
  KnockoutTournament? _tournament;
  KnockoutPlayerEntry? _playerEntry;
  KnockoutPlayerStatus? _playerStatus;
  KnockoutPlayerRecords? _playerRecords;
  PlayerLeagueAchievements? _leagueAchievements;
  List<KnockoutTournamentHistoryEntry> _playerHistory = const [];
  List<KnockoutHallOfFameEntry> _hallOfFame = const [];
  bool _isLoading = true;
  bool _isRegistering = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _playerProfile = widget.playerProfile;
    _loadTournamentState();
  }

  @override
  void didUpdateWidget(covariant KnockoutHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.playerProfile != widget.playerProfile) {
      _playerProfile = widget.playerProfile;
      _loadTournamentState();
    }
  }

  Future<void> _loadTournamentState({bool clearMessage = true}) async {
    setState(() {
      _isLoading = true;
      if (clearMessage) {
        _message = null;
      }
    });

    final tournament = await widget.knockoutRepository.fetchCurrentTournament();

    final playerEntryFuture = widget.knockoutRepository.currentEntry(
      tournamentId: tournament.id,
      playerId: _playerProfile.id,
    );
    final playerStatusFuture = widget.knockoutRepository.fetchPlayerStatus(
      tournamentId: tournament.id,
      playerId: _playerProfile.id,
    );
    final playerRecordsFuture = widget.knockoutRepository.fetchPlayerRecords(
      _playerProfile.id,
    );
    final playerHistoryFuture = widget.knockoutRepository.fetchPlayerHistory(
      _playerProfile.id,
    );
    final hallOfFameFuture = widget.knockoutRepository.fetchHallOfFame();
    final leagueAchievementsFuture =
        widget.leagueRepository?.fetchPlayerAchievements(_playerProfile.id) ??
        Future<PlayerLeagueAchievements>.value(
          PlayerLeagueAchievements.empty(_playerProfile.id),
        );

    final playerEntry = await playerEntryFuture;
    final playerStatus = await playerStatusFuture;
    final playerRecords = await playerRecordsFuture;
    final playerHistory = await playerHistoryFuture;
    final hallOfFame = await hallOfFameFuture;
    final leagueAchievements = await leagueAchievementsFuture;

    if (!mounted) {
      return;
    }

    setState(() {
      _tournament = tournament;
      _playerEntry = playerEntry;
      _playerStatus = playerStatus;
      _playerRecords = playerRecords;
      _leagueAchievements = leagueAchievements;
      _playerHistory = playerHistory;
      _hallOfFame = hallOfFame;
      _isLoading = false;
    });
  }

  Future<void> _register() async {
    final tournament = _tournament;
    if (tournament == null || _playerEntry != null) {
      return;
    }

    setState(() {
      _isRegistering = true;
      _message = null;
    });

    final result = await widget.knockoutRepository.registerPlayer(
      tournament: tournament,
      playerProfile: _playerProfile,
    );

    if (!mounted) {
      return;
    }

    if (!result.isSuccess || result.playerEntry == null) {
      setState(() {
        _message = result.message ?? 'Could not register for Knockout.';
        _isRegistering = false;
      });
      return;
    }

    final updatedProfile = _playerProfile.copyWith(
      gamePoints:
          _playerProfile.gamePoints - result.playerEntry!.entryCostGamePoints,
    );
    try {
      await widget.authRepository.updatePlayerProfile(updatedProfile);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _message = 'Could not update player profile.';
        _isRegistering = false;
      });

      return;
    }
    widget.onPlayerProfileUpdated(updatedProfile);

    if (!mounted) {
      return;
    }

    setState(() {
      _playerProfile = updatedProfile;
      _message = result.message;
      _isRegistering = false;
    });
    await _loadTournamentState(clearMessage: false);
  }

  String _usernameForPlayerId(String? playerId) {
    if (playerId == null) {
      return 'Waiting';
    }

    final tournament = _tournament;
    if (tournament == null) {
      return playerId;
    }

    for (final entry in tournament.entries) {
      if (entry.playerId == playerId) {
        return entry.username;
      }
    }

    return playerId;
  }

  @override
  Widget build(BuildContext context) {
    final tournament = _tournament;
    final playerEntry = _playerEntry;

    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      appBar: AppBar(
        title: const Text('Knockout'),
        backgroundColor: const Color(0xFF101418),
        foregroundColor: const Color(0xFFD6DEE8),
      ),
      body: SafeArea(
        child: _isLoading || tournament == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _KnockoutCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tournament.name, style: _KnockoutText.title),
                        const SizedBox(height: 10),
                        Text(
                          'Status: ${tournament.status.label}',
                          style: _KnockoutText.body,
                        ),
                        Text(
                          'Entry cost: ${tournament.entryCostGamePoints} GP',
                          style: _KnockoutText.body,
                        ),
                        Text(
                          'Registration closes: ${DateTimeFormatter.dateTime(tournament.registrationClosesAt)}',
                          style: _KnockoutText.body,
                        ),
                        Text(
                          'Tournament starts: ${DateTimeFormatter.dateTime(tournament.startsAt)}',
                          style: _KnockoutText.body,
                        ),
                        Text(
                          'Registered players: ${tournament.entries.length}',
                          style: _KnockoutText.body,
                        ),
                        Text(
                          'Your GP: ${_playerProfile.gamePoints}',
                          style: _KnockoutText.body,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _KnockoutCard(
                    child: _ActiveDuelSection(
                      playerStatus: _playerStatus,
                      opponentUsername: _usernameForPlayerId(
                        _playerStatus?.duelSnapshot?.opponentId,
                      ),
                      onPlayTournamentRun: widget.onPlayTournamentRun,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _KnockoutCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Registration', style: _KnockoutText.title),
                        const SizedBox(height: 10),
                        Text(
                          playerEntry == null
                              ? 'You are not registered.'
                              : 'You are registered for this monthly Knockout.',
                          style: _KnockoutText.body,
                        ),
                        if (playerEntry != null)
                          Text(
                            'Registered at: ${DateTimeFormatter.dateTime(playerEntry.registeredAt)}',
                            style: _KnockoutText.body,
                          ),
                        if (_message != null) ...[
                          const SizedBox(height: 10),
                          Text(_message!, style: _KnockoutText.message),
                        ],
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed:
                              _isRegistering ||
                                  playerEntry != null ||
                                  !tournament.isRegistrationOpen
                              ? null
                              : _register,
                          child: Text(
                            playerEntry == null
                                ? 'Register for Knockout'
                                : tournament.isCompleted
                                ? 'Tournament completed'
                                : 'Registered',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _KnockoutCard(
                    child: _KnockoutRecordsSection(records: _playerRecords),
                  ),
                  const SizedBox(height: 12),
                  _KnockoutCard(
                    child: _CompetitiveAchievementsSection(
                      leagueAchievements: _leagueAchievements,
                      knockoutRecords: _playerRecords,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _KnockoutCard(
                    child: _KnockoutHallOfFameSection(entries: _hallOfFame),
                  ),
                  const SizedBox(height: 12),
                  _KnockoutCard(
                    child: _KnockoutHistorySection(history: _playerHistory),
                  ),
                  const SizedBox(height: 12),
                  _KnockoutCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tournament Structure',
                          style: _KnockoutText.title,
                        ),
                        const SizedBox(height: 10),
                        if (tournament.rounds.isEmpty)
                          const Text(
                            'Matches will be generated after registration closes.',
                            style: _KnockoutText.body,
                          )
                        else
                          ...tournament.rounds.map(
                            (round) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                'Round ${round.roundNumber} • '
                                'Status: ${round.status.name} • '
                                '${round.matches.length} matches • '
                                '${round.byePlayerIds.length} byes',
                                style: _KnockoutText.body,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _KnockoutCard extends StatelessWidget {
  const _KnockoutCard({required this.child});

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

class _ActiveDuelSection extends StatelessWidget {
  const _ActiveDuelSection({
    required this.playerStatus,
    required this.opponentUsername,
    this.onPlayTournamentRun,
  });

  final KnockoutPlayerStatus? playerStatus;
  final String opponentUsername;
  final VoidCallback? onPlayTournamentRun;

  @override
  Widget build(BuildContext context) {
    final status =
        playerStatus ??
        const KnockoutPlayerStatus(
          state: KnockoutPlayerTournamentState.notRegistered,
        );
    final snapshot = status.duelSnapshot;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tournament Status', style: _KnockoutText.title),
        const SizedBox(height: 10),
        Text(status.title, style: _KnockoutText.status),
        const SizedBox(height: 6),
        Text(status.description, style: _KnockoutText.body),
        if (snapshot != null) ...[
          const SizedBox(height: 10),
          if (snapshot.hasBye) ...[
            Text(
              'Round ${snapshot.roundNumber}: bye advanced',
              style: _KnockoutText.body,
            ),
            Text(
              'Round settles: ${DateTimeFormatter.dateTime(snapshot.roundEndsAt)}',
              style: _KnockoutText.body,
            ),
          ] else ...[
            Text('Round ${snapshot.roundNumber}', style: _KnockoutText.body),
            Text('Opponent: $opponentUsername', style: _KnockoutText.body),
            Text(
              'Your score: ${snapshot.playerScore} (${snapshot.playerRunCount} runs)',
              style: _KnockoutText.body,
            ),
            Text(
              'Opponent score: ${snapshot.opponentScore} (${snapshot.opponentRunCount} runs)',
              style: _KnockoutText.body,
            ),
            Text(
              'Round settles: ${DateTimeFormatter.dateTime(snapshot.roundEndsAt)}',
              style: _KnockoutText.body,
            ),
          ],
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: status.canPlayTournamentRun ? onPlayTournamentRun : null,
          child: const Text('Play tournament run'),
        ),
      ],
    );
  }
}

class _KnockoutRecordsSection extends StatelessWidget {
  const _KnockoutRecordsSection({required this.records});

  final KnockoutPlayerRecords? records;

  @override
  Widget build(BuildContext context) {
    final playerRecords = records;
    if (playerRecords == null || playerRecords.tournamentsPlayed == 0) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Knockout Records', style: _KnockoutText.title),
          SizedBox(height: 10),
          Text('No completed Knockout records yet.', style: _KnockoutText.body),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Personal Knockout Records', style: _KnockoutText.title),
        const SizedBox(height: 10),
        Text(
          'Tournaments played: ${playerRecords.tournamentsPlayed}',
          style: _KnockoutText.body,
        ),
        Text(
          'Titles won: ${playerRecords.titlesWon}',
          style: _KnockoutText.body,
        ),
        Text(
          'Best tournament result: ${playerRecords.bestTournamentResultLabel}',
          style: _KnockoutText.body,
        ),
        Text(
          'Tournaments participated: ${playerRecords.tournamentsParticipated}',
          style: _KnockoutText.body,
        ),
        Text(
          'Total duels played: ${playerRecords.totalDuelsPlayed}',
          style: _KnockoutText.body,
        ),
        Text(
          'Total duels won: ${playerRecords.totalDuelsWon}',
          style: _KnockoutText.body,
        ),
        Text(
          'Duel win percentage: ${playerRecords.duelWinPercentageLabel}',
          style: _KnockoutText.body,
        ),
      ],
    );
  }
}

class _CompetitiveAchievementsSection extends StatelessWidget {
  const _CompetitiveAchievementsSection({
    required this.leagueAchievements,
    required this.knockoutRecords,
  });

  final PlayerLeagueAchievements? leagueAchievements;
  final KnockoutPlayerRecords? knockoutRecords;

  @override
  Widget build(BuildContext context) {
    final league =
        leagueAchievements ?? PlayerLeagueAchievements.empty('unknown-player');
    final knockout =
        knockoutRecords ?? KnockoutPlayerRecords.empty('unknown-player');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Competitive Achievements', style: _KnockoutText.title),
        const SizedBox(height: 10),
        Text('League', style: _KnockoutText.status),
        const SizedBox(height: 6),
        Text(
          league.bestDivisionReached == null
              ? 'Best division reached: No league result yet'
              : 'Best division reached: Division ${league.bestDivisionReached}',
          style: _KnockoutText.body,
        ),
        Text('Promotions: ${league.promotions}', style: _KnockoutText.body),
        Text('Relegations: ${league.relegations}', style: _KnockoutText.body),
        const SizedBox(height: 12),
        Text('Knockout', style: _KnockoutText.status),
        const SizedBox(height: 6),
        Text(
          knockout.highestRoundReached == 0
              ? 'Best round reached: No knockout result yet'
              : 'Best round reached: Round ${knockout.highestRoundReached}',
          style: _KnockoutText.body,
        ),
        Text(
          'Tournaments participated: ${knockout.tournamentsParticipated}',
          style: _KnockoutText.body,
        ),
        Text(
          'Duel win percentage: ${knockout.duelWinPercentageLabel}',
          style: _KnockoutText.body,
        ),
        Text(
          'Total duels played: ${knockout.totalDuelsPlayed}',
          style: _KnockoutText.body,
        ),
      ],
    );
  }
}

class _KnockoutHallOfFameSection extends StatelessWidget {
  const _KnockoutHallOfFameSection({required this.entries});

  final List<KnockoutHallOfFameEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Knockout Hall of Fame', style: _KnockoutText.title),
          SizedBox(height: 10),
          Text('No Knockout champions yet.', style: _KnockoutText.body),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Knockout Hall of Fame', style: _KnockoutText.title),
        const SizedBox(height: 10),
        ...entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${entry.displayName} • '
                  '${entry.titlesWon == 1 ? '1 title' : '${entry.titlesWon} titles'}',
                  style: _KnockoutText.body,
                ),
                Text(
                  'Won: ${DateTimeFormatter.monthYearList(entry.wonTournamentMonths)}',
                  style: _KnockoutText.message,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KnockoutHistorySection extends StatelessWidget {
  const _KnockoutHistorySection({required this.history});

  static const int _visibleHistoryLimit = 10;

  final List<KnockoutTournamentHistoryEntry> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tournament History', style: _KnockoutText.title),
          SizedBox(height: 10),
          Text('No completed Knockout history yet.', style: _KnockoutText.body),
        ],
      );
    }

    final visibleHistory = history.take(_visibleHistoryLimit).toList();
    final hiddenCount = history.length - visibleHistory.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Tournament History', style: _KnockoutText.title),
        const SizedBox(height: 10),
        ...visibleHistory.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${entry.tournamentName}: ${entry.outcome.label} • '
              'Round ${entry.finalRoundNumber}',
              style: _KnockoutText.body,
            ),
          ),
        ),
        if (hiddenCount > 0) ...[
          const SizedBox(height: 4),
          Text(
            '+$hiddenCount older tournament results hidden',
            style: _KnockoutText.message,
          ),
        ],
      ],
    );
  }
}

class _KnockoutText {
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

  static const status = TextStyle(
    color: Color(0xFF7CC7FF),
    fontSize: 16,
    fontWeight: FontWeight.w900,
    letterSpacing: 0,
  );

  static const message = TextStyle(
    color: Color(0xFF7CC7FF),
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
}
