enum RunPointRewardTier { gold, silver, bronze, none }

extension RunPointRewardTierAmount on RunPointRewardTier {
  int get rpAmount {
    return switch (this) {
      RunPointRewardTier.gold => 3,
      RunPointRewardTier.silver => 2,
      RunPointRewardTier.bronze => 1,
      RunPointRewardTier.none => 0,
    };
  }
}
