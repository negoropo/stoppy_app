import 'package:flutter/material.dart';

import '../../../auth/domain/models/player_profile.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/models/knockout_duel_snapshot.dart';
import '../../domain/models/knockout_player_entry.dart';
import '../../domain/models/knockout_tournament.dart';
import '../../domain/repositories/knockout_repository.dart';

class KnockoutHomeScreen extends StatefulWidget {
  const KnockoutHomeScreen({
    super.key,
    required this.playerProfile,
    required this.authRepository,
    required this.knockoutRepository,
    required this.onPlayerProfileUpdated,
  });

  final PlayerProfile playerProfile;
  final AuthRepository authRepository;
  final KnockoutRepository knockoutRepository;
  final ValueSetter<PlayerProfile> onPlayerProfileUpdated;

  @override
  State<KnockoutHomeScreen> createState() => _KnockoutHomeScreenState();
}

class _KnockoutHomeScreenState extends State<KnockoutHomeScreen> {
  late PlayerProfile _playerProfile;
  KnockoutTournament? _tournament;
  KnockoutPlayerEntry? _playerEntry;
  KnockoutDuelSnapshot? _duelSnapshot;
  bool _isLoading = true;
  bool _isRegistering = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _playerProfile = widget.playerProfile;
    _loadTournamentState();
  }

  Future<void> _loadTournamentState({bool clearMessage = true}) async {
    setState(() {
      _isLoading = true;
      if (clearMessage) {
        _message = null;
      }
    });

    final tournament = await widget.knockoutRepository.fetchCurrentTournament();
    final playerEntry = await widget.knockoutRepository.currentEntry(
      tournamentId: tournament.id,
      playerId: _playerProfile.id,
    );
    final duelSnapshot = playerEntry == null
        ? null
        : await widget.knockoutRepository.fetchActiveDuel(
            tournamentId: tournament.id,
            playerId: _playerProfile.id,
          );

    if (!mounted) {
      return;
    }

    setState(() {
      _tournament = tournament;
      _playerEntry = playerEntry;
      _duelSnapshot = duelSnapshot;
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
                          'Registration closes: ${_dateText(tournament.registrationClosesAt)}',
                          style: _KnockoutText.body,
                        ),
                        Text(
                          'Tournament starts: ${_dateText(tournament.startsAt)}',
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
                      tournament: tournament,
                      playerId: _playerProfile.id,
                      duelSnapshot: _duelSnapshot,
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
                            'Registered at: ${_dateText(playerEntry.registeredAt)}',
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
                                : 'Registered',
                          ),
                        ),
                      ],
                    ),
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

  String _dateText(DateTime dateTime) {
    final local = dateTime.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
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
    required this.tournament,
    required this.playerId,
    required this.duelSnapshot,
  });

  final KnockoutTournament tournament;
  final String playerId;
  final KnockoutDuelSnapshot? duelSnapshot;

  @override
  Widget build(BuildContext context) {
    final snapshot = duelSnapshot;

    if (!tournament.hasStarted) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Active Duel', style: _KnockoutText.title),
          SizedBox(height: 10),
          Text(
            'Your duel will appear when the tournament starts.',
            style: _KnockoutText.body,
          ),
        ],
      );
    }

    if (snapshot == null) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Active Duel', style: _KnockoutText.title),
          SizedBox(height: 10),
          Text(
            'No active duel found for this round.',
            style: _KnockoutText.body,
          ),
        ],
      );
    }

    if (snapshot.hasBye) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Active Duel', style: _KnockoutText.title),
          const SizedBox(height: 10),
          Text(
            'Round ${snapshot.roundNumber}: bye advanced',
            style: _KnockoutText.body,
          ),
          Text(
            'Round settles: ${_dateText(snapshot.roundEndsAt)}',
            style: _KnockoutText.body,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Active Duel', style: _KnockoutText.title),
        const SizedBox(height: 10),
        Text('Round ${snapshot.roundNumber}', style: _KnockoutText.body),
        Text(
          'Opponent: ${_opponentLabel(tournament, snapshot.opponentId)}',
          style: _KnockoutText.body,
        ),
        Text(
          'Your score: ${snapshot.playerScore} (${snapshot.playerRunCount} runs)',
          style: _KnockoutText.body,
        ),
        Text(
          'Opponent score: ${snapshot.opponentScore} (${snapshot.opponentRunCount} runs)',
          style: _KnockoutText.body,
        ),
        Text(
          'Round settles: ${_dateText(snapshot.roundEndsAt)}',
          style: _KnockoutText.body,
        ),
      ],
    );
  }

  String _opponentLabel(KnockoutTournament tournament, String? opponentId) {
    if (opponentId == null) {
      return 'Waiting';
    }

    for (final entry in tournament.entries) {
      if (entry.playerId == opponentId) {
        return entry.username;
      }
    }

    return opponentId;
  }

  static String _dateText(DateTime dateTime) {
    final local = dateTime.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
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

  static const message = TextStyle(
    color: Color(0xFF7CC7FF),
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
}
