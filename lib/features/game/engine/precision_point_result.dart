class PrecisionPointResult {
  const PrecisionPointResult({
    required this.awardedPP,
    int? basePP,
    this.levelMultiplier = 1,
    required this.angularDistance,
    required this.normalizedPrecision,
  }) : basePP = basePP ?? awardedPP;

  /// Final PP that is shown to the player and added to the run total.
  final int awardedPP;

  /// Base PP produced by the circular precision formula before run-level
  /// scaling is applied.
  final int basePP;

  /// Multiplier applied by the current run level. A value of 1 keeps base PP
  /// unchanged, which is what the base precision calculator returns.
  final double levelMultiplier;

  final double angularDistance;
  final double normalizedPrecision;
}
