import 'package:flutter_test/flutter_test.dart';
import 'package:stoppy_app/features/game/engine/precision_point_tier_service.dart';

void main() {
  group('PrecisionPointTierService', () {
    const service = PrecisionPointTierService();

    test('returns the authored PP ceilings for early and final tiers', () {
      expect(service.tierForLevel(1).maxPrecisionPoints, 100);
      expect(service.tierForLevel(2).maxPrecisionPoints, 200);
      expect(service.tierForLevel(6).maxPrecisionPoints, 1000);
      expect(service.tierForLevel(30).maxPrecisionPoints, 10000);
      expect(service.tierForLevel(60).maxPrecisionPoints, 100000);
    });

    test('advances target-hit tiers without exceeding tier 60', () {
      expect(service.nextTierLevel(1), 2);
      expect(service.nextTierLevel(59), 60);
      expect(service.nextTierLevel(60), 60);
    });
  });
}
