import 'dart:math';

class LockChallenge {
  const LockChallenge({
    required this.prompt,
    required this.answer,
  });

  final String prompt;
  final int answer;
}

abstract class ParentalLockRepository {
  Future<LockChallenge> createChallenge();
  Future<bool> verifyAnswer({
    required LockChallenge challenge,
    required String answer,
  });
}

class InMemoryParentalLockRepository implements ParentalLockRepository {
  /// Seeded only by a test that needs a challenge it can predict. In the app
  /// the seed is left to the platform: a fixed one made `createChallenge`
  /// deterministic, so every install opened on the very same sum and the
  /// gate could be passed from memory without doing the arithmetic.
  InMemoryParentalLockRepository({int? seed}) : _random = Random(seed);

  final Random _random;

  @override
  Future<LockChallenge> createChallenge() async {
    final left = _random.nextInt(6) + 2;
    final right = _random.nextInt(5) + 1;
    return LockChallenge(
      prompt: '$left + $right = ?',
      answer: left + right,
    );
  }

  @override
  Future<bool> verifyAnswer({
    required LockChallenge challenge,
    required String answer,
  }) async {
    return int.tryParse(answer.trim()) == challenge.answer;
  }
}
