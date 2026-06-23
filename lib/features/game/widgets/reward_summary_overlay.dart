import 'package:flutter/material.dart';

import '../engine/precision_point_result.dart';

class RewardSummaryOverlay extends StatelessWidget {
  const RewardSummaryOverlay({
    super.key,
    required this.precisionPointResult,
    required this.totalPrecisionPoints,
    this.nextTierMaxPrecisionPoints,
    required this.onConfirm,
  });

  final PrecisionPointResult precisionPointResult;
  final int totalPrecisionPoints;
  final int? nextTierMaxPrecisionPoints;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
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
                _precisionPointBreakdown(precisionPointResult),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF7CC7FF),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total PP: ${_formatPoints(totalPrecisionPoints)}',
                style: const TextStyle(
                  color: Color(0xFFD6DEE8),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              if (nextTierMaxPrecisionPoints != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Target hit! Next level max PP: '
                  '${_formatPoints(nextTierMaxPrecisionPoints!)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFD166),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onConfirm,
                child: const Text('Next Level'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _precisionPointBreakdown(PrecisionPointResult result) {
    return 'PP earned: ${_formatPoints(result.awardedPP)} / '
        '${_formatPoints(result.tierMaxPrecisionPoints)}';
  }

  String _formatPoints(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => ',',
    );
  }
}
