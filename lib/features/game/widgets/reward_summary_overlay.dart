import 'package:flutter/material.dart';

import '../engine/combined_run_point_reward_result.dart';
import '../engine/precision_point_result.dart';

class RewardSummaryOverlay extends StatelessWidget {
  const RewardSummaryOverlay({
    super.key,
    required this.runPointRewardResult,
    required this.precisionPointResult,
    required this.onConfirm,
  });

  final CombinedRunPointRewardResult runPointRewardResult;
  final PrecisionPointResult precisionPointResult;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final targetMessage = runPointRewardResult.targetBonusResult.message;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xEE101418),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD166)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Reward Summary',
                style: TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Safe Zone RP earned: ${runPointRewardResult.safeZoneRewardResult.rpAmount}',
                style: _summaryTextStyle,
              ),
              const SizedBox(height: 6),
              Text(
                'Target RP bonus earned: ${runPointRewardResult.targetBonusResult.rpAmount}',
                style: _summaryTextStyle,
              ),
              const SizedBox(height: 6),
              Text(
                'Total RP earned: ${runPointRewardResult.totalRpAmount}',
                style: const TextStyle(
                  color: Color(0xFF39D98A),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _precisionPointBreakdown(precisionPointResult),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF7CC7FF),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              if (targetMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  targetMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFD166),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(onPressed: onConfirm, child: const Text('OK')),
            ],
          ),
        ),
      ),
    );
  }

  static const TextStyle _summaryTextStyle = TextStyle(
    color: Color(0xFFD6DEE8),
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  String _precisionPointBreakdown(PrecisionPointResult result) {
    return '${result.basePP} PP × Level Multiplier ${result.levelMultiplier.toStringAsFixed(2)} = ${result.awardedPP} PP';
  }
}
