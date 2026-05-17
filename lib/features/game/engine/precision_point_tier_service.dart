import 'precision_point_tier.dart';

class PrecisionPointTierService {
  const PrecisionPointTierService();

  static const List<int> _tierMaxValues = [
    100,
    200,
    300,
    500,
    750,
    1000,
    1250,
    1500,
    1750,
    2000,
    2300,
    2600,
    2900,
    3200,
    3500,
    3800,
    4100,
    4400,
    4700,
    5000,
    5500,
    6000,
    6500,
    7000,
    7500,
    8000,
    8500,
    9000,
    9500,
    10000,
    11000,
    12000,
    13000,
    14000,
    15000,
    16000,
    17000,
    18000,
    19000,
    20000,
    23000,
    26000,
    29000,
    32000,
    35000,
    38000,
    41000,
    44000,
    47000,
    50000,
    55000,
    60000,
    65000,
    70000,
    75000,
    80000,
    85000,
    90000,
    95000,
    100000,
  ];

  int get firstTierLevel => 1;
  int get lastTierLevel => _tierMaxValues.length;

  PrecisionPointTier tierForLevel(int level) {
    final clampedLevel = level.clamp(firstTierLevel, lastTierLevel);

    return PrecisionPointTier(
      level: clampedLevel,
      maxPrecisionPoints: _tierMaxValues[clampedLevel - 1],
    );
  }

  int nextTierLevel(int currentLevel) {
    // Target hits grow the PP ceiling for the following level, but the ceiling
    // must stop at the authored final tier to keep run scoring deterministic.
    return (currentLevel + 1).clamp(firstTierLevel, lastTierLevel);
  }
}
