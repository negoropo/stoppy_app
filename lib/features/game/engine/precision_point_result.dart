class PrecisionPointResult {
  const PrecisionPointResult({
    required this.awardedPP,
    required this.tierLevel,
    required this.tierMaxPrecisionPoints,
    required this.angularDistance,
    required this.normalizedPrecision,
  });

  /// Final PP that is shown to the player and added to the run total.
  final int awardedPP;

  final int tierLevel;
  final int tierMaxPrecisionPoints;

  final double angularDistance;
  final double normalizedPrecision;
}
