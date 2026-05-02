import 'package:flutter/material.dart';

import '../domain/models/difficulty_state.dart';
import '../domain/models/reward_menu_action.dart';
import '../engine/precision_point_result.dart';
import '../engine/run_point_reward_result.dart';

class PostHitRewardOverlay extends StatelessWidget {
  const PostHitRewardOverlay({
    super.key,
    required this.difficultyState,
    required this.rpRewardResult,
    required this.precisionPointResult,
    required this.totalRunPoints,
    required this.onSelected,
    this.warningMessage,
  });

  final DifficultyState difficultyState;
  final RunPointRewardResult rpRewardResult;
  final PrecisionPointResult precisionPointResult;
  final int totalRunPoints;
  final ValueSetter<RewardMenuAction> onSelected;
  final String? warningMessage;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xEE101418),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD166)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Reward',
                style: TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              if (warningMessage != null) ...[
                Text(
                  warningMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFD166),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                'RP gained: ${rpRewardResult.rpAmount}',
                style: const TextStyle(
                  color: Color(0xFF39D98A),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '+${precisionPointResult.awardedPP} PP',
                style: const TextStyle(
                  color: Color(0xFF7CC7FF),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Precision Points',
                style: TextStyle(
                  color: Color(0xFFD6DEE8),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _precisionPointBreakdown(precisionPointResult),
                style: const TextStyle(
                  color: Color(0xFFB8C5D4),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'total RP: $totalRunPoints',
                style: const TextStyle(
                  color: Color(0xFFD6DEE8),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 16),
              RewardMenuButton(
                label: 'Next level',
                detail: 'Free - random difficulty increase',
                onPressed: () => onSelected(RewardMenuAction.nextLevel),
              ),
              const SizedBox(height: 8),
              RewardMenuButton(
                label: 'Do not increase difficulty',
                detail: 'Cost: 5 RP',
                onPressed:
                    totalRunPoints >= RewardMenuAction.skipDifficulty.rpCost
                    ? () => onSelected(RewardMenuAction.skipDifficulty)
                    : null,
              ),
              const SizedBox(height: 8),
              RewardMenuButton(
                label: 'Decrease random difficulty',
                detail: 'Cost: 10 RP',
                onPressed:
                    totalRunPoints >=
                            RewardMenuAction.decreaseRandomDifficulty.rpCost &&
                        !difficultyState.isAtMinimum
                    ? () =>
                          onSelected(RewardMenuAction.decreaseRandomDifficulty)
                    : null,
              ),
              const SizedBox(height: 8),
              RewardMenuButton(
                label: 'Buy life',
                detail: 'Cost: 20 RP',
                onPressed: totalRunPoints >= RewardMenuAction.buyLife.rpCost
                    ? () => onSelected(RewardMenuAction.buyLife)
                    : null,
              ),
              const SizedBox(height: 12),
              ...DifficultyVariable.values.map((variable) {
                final level = difficultyState.levelForVariable(variable);
                final action = RewardMenuAction.increaseVariable(variable);
                final canSelect =
                    totalRunPoints >= action.rpCost &&
                    level < DifficultyState.maxLevel;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RewardMenuButton(
                    label: '${variable.menuLabel} ($level)',
                    detail: 'Cost: ${action.rpCost} RP',
                    onPressed: canSelect ? () => onSelected(action) : null,
                  ),
                );
              }),
              const SizedBox(height: 8),
              const Text(
                'Decrease chosen difficulty (15 RP)',
                style: TextStyle(
                  color: Color(0xFFFFD166),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 8),
              ...DifficultyVariable.values.map((variable) {
                final level = difficultyState.levelForVariable(variable);
                final action = RewardMenuAction.decreaseVariable(variable);
                final canSelect =
                    totalRunPoints >= action.rpCost &&
                    level > DifficultyState.minLevel;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RewardMenuButton(
                    label: '${variable.shortMenuLabel} ($level)',
                    detail: 'Cost: ${action.rpCost} RP',
                    onPressed: canSelect ? () => onSelected(action) : null,
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _precisionPointBreakdown(PrecisionPointResult result) {
    return '${result.basePP} PP × Level Multiplier ${result.levelMultiplier.toStringAsFixed(2)} = ${result.awardedPP} PP';
  }
}

class RewardMenuButton extends StatelessWidget {
  const RewardMenuButton({
    super.key,
    required this.label,
    required this.detail,
    required this.onPressed,
  });

  final String label;
  final String detail;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: FilledButton(
        onPressed: onPressed,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            Text(
              detail,
              style: const TextStyle(fontSize: 11, letterSpacing: 0),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
