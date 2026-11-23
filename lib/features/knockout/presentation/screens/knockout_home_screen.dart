import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/backend/api_error.dart';
import '../../../../core/backend/domain_error_mapper.dart';
import '../../../../core/backend/idempotency_key.dart';
import '../../../auth/domain/models/player_profile.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../league/domain/models/player_league_achievements.dart';
import '../../../league/domain/repositories/league_repository.dart';
import '../../domain/models/knockout_hall_of_fame_entry.dart';
import '../../domain/models/knockout_player_entry.dart';
import '../../domain/models/knockout_player_records.dart';
import '../../domain/models/knockout_player_status.dart';
import '../../domain/models/knockout_registration_result.dart';
import '../../domain/models/knockout_tournament.dart';
import '../../domain/models/knockout_tournament_selection.dart';
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
  static int _registrationKeyCounter = 0;

  late PlayerProfile _playerProfile;
  KnockoutTournament? _tournament;
  KnockoutTournamentSelection? _selection;
  int _loadGeneration = 0;
  KnockoutPlayerEntry? _playerEntry;
  KnockoutPlayerStatus? _playerStatus;
  KnockoutPlayerRecords? _playerRecords;
  PlayerLeagueAchievements? _leagueAchievements;
  List<KnockoutTournamentHistoryEntry> _playerHistory = const [];
  List<KnockoutHallOfFameEntry> _hallOfFame = const [];
  bool _isLoading = true;
  bool _isRegistering = false;
  bool _hasPendingRegistration = false;
  bool _registrationStorageReady = false;
  String? _registrationStorageMessage;
  String? _loadError;
  IdempotencyKey? _pendingRegistrationIdempotencyKey;
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
      if (oldWidget.playerProfile.id != widget.playerProfile.id) {
        _hasPendingRegistration = false;
        _registrationStorageReady = false;
        _registrationStorageMessage = null;
        _isRegistering = false;
        _tournament = null;
        _selection = null;
        _playerEntry = null;
      }
      _playerProfile = widget.playerProfile;
      _loadTournamentState();
    }
  }

  Future<void> _loadTournamentState({
    bool clearMessage = true,
    KnockoutTournament? selectedTournament,
  }) async {
    final generation = ++_loadGeneration;
    setState(() {
      _isLoading = true;
      _loadError = null;
      if (clearMessage) {
        _message = null;
      }
    });

    final playerId = _playerProfile.id;
    await _refreshPendingRegistration(playerId);
    if (!_isCurrentLoad(generation, playerId)) return;
    try {
      final repository = _authoritativeReads;
      if (repository != null) {
        await _loadAuthoritativeTournament(
          repository,
          playerId,
          generation,
          selectedTournament,
        );
      } else {
        await _loadTournamentProjections(playerId, generation);
      }
    } catch (error) {
      if (!_isCurrentLoad(generation, playerId)) return;
      if ((_authoritativeReads == null && _registrationRecovery == null) ||
          !clearMessage) {
        rethrow;
      }
      setState(() {
        _isLoading = false;
        _loadError =
            error is RepositoryDomainException &&
                error.details['reason'] == 'ambiguousTournamentSelection'
            ? 'Multiple tournaments match the Knockout selection.'
            : 'Could not load Knockout tournament data.';
      });
    }
  }

  bool _isCurrentLoad(int generation, String playerId) =>
      mounted && generation == _loadGeneration && _playerProfile.id == playerId;

  AuthoritativeKnockoutReadRepository? get _authoritativeReads {
    final repository = widget.knockoutRepository;
    return repository is AuthoritativeKnockoutReadRepository
        ? repository as AuthoritativeKnockoutReadRepository
        : null;
  }

  Future<void> _loadAuthoritativeTournament(
    AuthoritativeKnockoutReadRepository reads,
    String playerId,
    int generation,
    KnockoutTournament? selectedTournament,
  ) async {
    // Choosing a displayed slot pins that exact target. Refresh is the
    // operation that reloads discovery and can change the available slots.
    final selection = selectedTournament == null
        ? await reads.discoverTournaments()
        : _selection!;
    if (!_isCurrentLoad(generation, playerId)) return;
    final competition = selection.competition;
    final tournament =
        selectedTournament ??
        (competition != null && competition.id == _tournament?.id
            ? competition
            : selection.registration ?? competition);
    KnockoutPlayerEntry? entry;
    KnockoutPlayerStatus? status;
    if (tournament != null) {
      final repository = widget.knockoutRepository;
      try {
        final (scopedEntry, scopedStatus) = await (
          repository.currentEntry(
            tournamentId: tournament.id,
            playerId: playerId,
          ),
          repository.fetchPlayerStatus(
            tournamentId: tournament.id,
            playerId: playerId,
          ),
        ).wait;
        // Separate GETs can straddle a write. Do not show an unregistered
        // state when the other response already contains a confirmed entry.
        if ((scopedEntry == null) ==
            (scopedStatus.state ==
                KnockoutPlayerTournamentState.notRegistered)) {
          entry = scopedEntry;
          status = scopedStatus;
        }
      } catch (_) {
        // Catalog data remains useful if the player-specific reads are unavailable.
      }
    }
    if (!_isCurrentLoad(generation, playerId)) return;
    setState(() {
      _selection = selection;
      _tournament = tournament?.copyWith(
        status: status?.tournamentStatus,
        registrationWindowOpen: status?.registrationWindowOpen,
      );
      _playerEntry = entry;
      _playerStatus = status;
      _isLoading = false;
    });
  }

  Future<void> _loadTournamentProjections(
    String playerId,
    int generation,
  ) async {
    final tournament = await widget.knockoutRepository.fetchCurrentTournament();

    final playerEntryFuture = widget.knockoutRepository.currentEntry(
      tournamentId: tournament.id,
      playerId: playerId,
    );
    final playerStatusFuture = widget.knockoutRepository.fetchPlayerStatus(
      tournamentId: tournament.id,
      playerId: playerId,
    );
    final playerRecordsFuture = widget.knockoutRepository.fetchPlayerRecords(
      playerId,
    );
    final playerHistoryFuture = widget.knockoutRepository.fetchPlayerHistory(
      playerId,
    );
    final hallOfFameFuture = widget.knockoutRepository.fetchHallOfFame();
    final leagueAchievementsFuture =
        widget.leagueRepository?.fetchPlayerAchievements(playerId) ??
        Future<PlayerLeagueAchievements>.value(
          PlayerLeagueAchievements.empty(playerId),
        );

    // Attach error handlers to all reads immediately so an unavailable
    // projection cannot leave the pending-registration action inaccessible.
    final (
      playerEntry,
      playerStatus,
      playerRecords,
      playerHistory,
      hallOfFame,
      leagueAchievements,
    ) = await (
      playerEntryFuture,
      playerStatusFuture,
      playerRecordsFuture,
      playerHistoryFuture,
      hallOfFameFuture,
      leagueAchievementsFuture,
    ).wait;

    if (!_isCurrentLoad(generation, playerId)) {
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

  KnockoutRegistrationRecoveryRepository? get _registrationRecovery {
    final repository = widget.knockoutRepository;
    return repository is KnockoutRegistrationRecoveryRepository
        ? repository as KnockoutRegistrationRecoveryRepository
        : null;
  }

  Future<void> _refreshPendingRegistration(String playerId) async {
    final recovery = _registrationRecovery;
    if (recovery == null) return;
    try {
      final pending = await recovery.hasPendingRegistration(playerId);
      if (!mounted || _playerProfile.id != playerId) return;
      setState(() {
        _hasPendingRegistration = pending;
        _registrationStorageReady = true;
        _registrationStorageMessage = null;
      });
    } catch (error) {
      if (!mounted || _playerProfile.id != playerId) return;
      setState(() {
        _registrationStorageReady = false;
        _registrationStorageMessage = _registrationErrorMessage(error);
      });
    }
  }

  Future<void> _register({bool retry = false}) async {
    final tournament = _tournament;
    final recovery = _registrationRecovery;
    final playerProfile = _playerProfile;
    if (retry) {
      if (_isRegistering || recovery == null || !_hasPendingRegistration) {
        return;
      }
    } else if (!_canStartRegistration) {
      return;
    }

    if (!_usesServerAuthoritativeRegistration &&
        playerProfile.gamePoints < tournament!.entryCostGamePoints) {
      setState(() {
        _message = 'You need ${tournament.entryCostGamePoints} GP to register.';
      });
      return;
    }

    setState(() {
      _isRegistering = true;
      _message = null;
    });

    KnockoutRegistrationResult? acceptedResult;
    PlayerProfile? acceptedProfile;

    try {
      final result = await Future<KnockoutRegistrationResult>.sync(
        () => retry
            ? recovery!.retryRegistration(playerProfile: playerProfile)
            : widget.knockoutRepository.registerPlayer(
                tournament: tournament!,
                playerProfile: playerProfile,
                idempotencyKey: recovery == null
                    ? _registrationIdempotencyKeyForCurrentAttempt()
                    : _newDurableRegistrationKey(),
              ),
      );

      if (!mounted || _playerProfile.id != playerProfile.id) {
        return;
      }

      if (!result.isSuccess || result.playerEntry == null) {
        _pendingRegistrationIdempotencyKey = null;
        setState(() {
          _message = result.message ?? 'Could not register for Knockout.';
        });
        return;
      }

      final updatedProfile = _profileProjectionForAcceptedRegistration(result);
      if (!_usesServerAuthoritativeRegistration) {
        await widget.authRepository.updatePlayerProfile(updatedProfile);
      }
      widget.onPlayerProfileUpdated(updatedProfile);
      _pendingRegistrationIdempotencyKey = null;
      acceptedResult = result;
      acceptedProfile = updatedProfile;

      setState(() {
        _playerProfile = updatedProfile;
        if (result.tournamentId == _tournament?.id) {
          _playerEntry = result.playerEntry;
        }
        if (recovery == null) {
          _tournament = result.tournament;
        }
        _message = result.message;
      });
    } catch (error) {
      if (!mounted || _playerProfile.id != playerProfile.id) {
        return;
      }

      setState(() {
        _message = _registrationErrorMessage(error);
      });
      _clearCompletedRejectedRegistrationAttempt(error);
    } finally {
      await _refreshPendingRegistration(playerProfile.id);
      if (mounted && _playerProfile.id == playerProfile.id) {
        setState(() {
          _isRegistering = false;
        });
      }
    }

    if (!mounted ||
        _playerProfile.id != playerProfile.id ||
        acceptedResult == null ||
        acceptedProfile == null) {
      return;
    }

    try {
      await _loadTournamentState(clearMessage: false);
    } catch (_) {
      if (!mounted || _playerProfile.id != playerProfile.id) {
        return;
      }

      setState(() {
        _playerProfile = acceptedProfile!;
        if (acceptedResult!.tournamentId == _tournament?.id) {
          _playerEntry = acceptedResult.playerEntry;
        }
        if (recovery == null) {
          _tournament = acceptedResult.tournament;
        }
        _isLoading = false;
        if (_tournament == null) {
          _loadError = 'Could not load Knockout tournament data.';
        }
        _message =
            'Knockout registration confirmed, but tournament data could not be refreshed.';
      });
    }
  }

  IdempotencyKey _registrationIdempotencyKeyForCurrentAttempt() {
    return _pendingRegistrationIdempotencyKey ??= IdempotencyKey(
      'knockout-registration-${DateTime.now().toUtc().microsecondsSinceEpoch}-${_registrationKeyCounter++}',
    );
  }

  IdempotencyKey _newDurableRegistrationKey() {
    final random = Random.secure();
    final encoded = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return IdempotencyKey('knockout-registration-$encoded');
  }

  bool get _usesServerAuthoritativeRegistration {
    return widget.knockoutRepository
        is ServerAuthoritativeKnockoutRegistrationRepository;
  }

  bool get _canStartRegistration =>
      _authoritativeReads == null &&
      !_isRegistering &&
      !_hasPendingRegistration &&
      (_registrationRecovery == null || _registrationStorageReady) &&
      _playerEntry == null &&
      _tournament?.isRegistrationOpen == true;

  PlayerProfile _profileProjectionForAcceptedRegistration(
    KnockoutRegistrationResult result,
  ) {
    final authoritativeProfile = result.playerProfile;
    if (authoritativeProfile != null) {
      return authoritativeProfile;
    }

    final entry = result.playerEntry!;
    if (_usesServerAuthoritativeRegistration) {
      throw const FormatException(
        'Accepted Knockout registration response is missing a current profile.',
      );
    }

    return _playerProfile.copyWith(
      gamePoints: (_playerProfile.gamePoints - entry.entryCostGamePoints)
          .clamp(0, 999999999)
          .toInt(),
    );
  }

  void _clearCompletedRejectedRegistrationAttempt(Object error) {
    if (!_isAmbiguousRegistrationFailure(error)) {
      _pendingRegistrationIdempotencyKey = null;
    }
  }

  bool _isAmbiguousRegistrationFailure(Object error) {
    return error is RepositoryDomainException &&
        (error.code == ApiErrorCode.networkUnavailable ||
            error.code == ApiErrorCode.requestTimeout ||
            error.code == ApiErrorCode.serverError ||
            error.code == ApiErrorCode.malformedPayload ||
            error.code == ApiErrorCode.unexpectedResponse);
  }

  String _registrationErrorMessage(Object error) {
    if (error is RepositoryDomainException) {
      return error.message;
    }

    return 'Could not register for Knockout. Please try again.';
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
    final authoritative = _authoritativeReads != null;
    final competition = _selection?.competition;
    final registration = _selection?.registration;

    return Scaffold(
      backgroundColor: const Color(0xFF101418),
      appBar: AppBar(
        title: const Text('Knockout'),
        backgroundColor: const Color(0xFF101418),
        foregroundColor: const Color(0xFFD6DEE8),
        actions: [
          if (authoritative)
            IconButton(
              tooltip: 'Refresh Knockout',
              onPressed: _isLoading || _isRegistering
                  ? null
                  : _loadTournamentState,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
      bottomNavigationBar:
          _hasPendingRegistration ||
              _registrationStorageMessage != null ||
              ((_loadError != null || tournament == null) && _message != null)
          ? SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_registrationStorageMessage case final message?)
                    Text(message, style: _KnockoutText.message),
                  if ((_loadError != null || tournament == null) &&
                      _message != null)
                    Text(_message!, style: _KnockoutText.message),
                  if (_hasPendingRegistration)
                    FilledButton(
                      onPressed: _isRegistering
                          ? null
                          : () => _register(retry: true),
                      child: const Text('Retry pending Knockout registration'),
                    ),
                ],
              ),
            )
          : null,
      body: SafeArea(
        child: _isLoading || tournament == null || _loadError != null
            ? Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        _loadError ??
                            'No relevant Knockout tournament is available.',
                        style: _KnockoutText.body,
                      ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (competition != null && registration != null)
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Registration'),
                          selected: tournament.id == registration.id,
                          onSelected: (selected) {
                            if (selected) {
                              _loadTournamentState(
                                selectedTournament: registration,
                              );
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Competition'),
                          selected: tournament.id == competition.id,
                          onSelected: (selected) {
                            if (selected) {
                              _loadTournamentState(
                                selectedTournament: competition,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  _KnockoutCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tournament.name, style: _KnockoutText.title),
                        const SizedBox(height: 10),
                        Text(
                          tournament.status ==
                                      KnockoutTournamentStatus
                                          .registrationOpen &&
                                  !tournament.isRegistrationOpen
                              ? 'Status: Registration window inactive'
                              : 'Status: ${tournament.status.label}',
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
                        if (!authoritative)
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
                  if (!authoritative)
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
                          authoritative
                              ? _playerStatus?.title ??
                                    'Registration status unavailable.'
                              : playerEntry == null
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
                        if (authoritative)
                          const Text(
                            'Paid registration is unavailable.',
                            style: _KnockoutText.body,
                          )
                        else
                          FilledButton(
                            onPressed: _canStartRegistration ? _register : null,
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
                  if (authoritative)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: _KnockoutCard(
                        child: Text(
                          'Duels, records, history, Hall of Fame and achievements are unavailable.',
                          style: _KnockoutText.body,
                        ),
                      ),
                    )
                  else ...[
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
