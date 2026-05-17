class PrecisionPointTier {
  const PrecisionPointTier({
    required this.level,
    required this.maxPrecisionPoints,
  }) : assert(level >= 1),
       assert(maxPrecisionPoints > 0);

  final int level;
  final int maxPrecisionPoints;
}
