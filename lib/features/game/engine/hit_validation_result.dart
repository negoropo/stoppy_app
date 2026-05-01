class HitValidationResult {
  const HitValidationResult({
    required this.ballAngle,
    required this.ballStartAngle,
    required this.ballEndAngle,
    required this.ballAngularRadius,
    required this.isInsideSafeZone,
    required this.isTargetHit,
    required this.targetAngularDistance,
    required this.relativePositionInSafeZone,
  });

  final double ballAngle;
  final double ballStartAngle;
  final double ballEndAngle;
  final double ballAngularRadius;
  final bool isInsideSafeZone;
  final bool isTargetHit;
  final double targetAngularDistance;
  final double? relativePositionInSafeZone;
}
