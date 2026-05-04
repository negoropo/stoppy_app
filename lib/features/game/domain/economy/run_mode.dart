enum RunMode { warmup, league, tournament }

extension RunModeLabel on RunMode {
  String get label {
    return switch (this) {
      RunMode.warmup => 'Warmup',
      RunMode.league => 'League',
      RunMode.tournament => 'Tournament',
    };
  }
}
